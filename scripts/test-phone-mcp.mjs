/**
 * phone-mcp 的边界测试 · node scripts/test-phone-mcp.mjs
 * ─────────────────────────────────────────────────────────────
 * 用 stdio 真起一个 phone-mcp，adb 换成一个只记参数的假程序（不碰任何真设备）。
 * 检查：PHONE_TOOLS 只注册列出的工具、PHONE_SERIAL 固定设备、限流真的生效、
 * 拼进手机端 shell 的参数不能注入命令。
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SERVER = path.join(ROOT, 'packages', 'phone-mcp', 'src', 'phone-mcp.js');

let failures = 0;
let tests = 0;
async function test(name, run) {
  tests++;
  try { await run(); console.log('PASS', name); }
  catch (error) { failures++; console.error('FAIL', name, '—', error?.stack ?? error); }
}

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'phone-mcp-test-'));
const adbLog = path.join(tmp, 'adb.log');
const fakeAdb = path.join(tmp, 'adb');
fs.writeFileSync(fakeAdb, `#!${process.execPath}
const fs = require('fs');
const args = process.argv.slice(2);
fs.appendFileSync(${JSON.stringify(adbLog)}, JSON.stringify(args) + '\\n');
const rest = args[0] === '-s' ? args.slice(2) : args;
if (rest[0] === 'devices') { process.stdout.write('List of devices attached\\nemulator-5554\\tdevice\\nREALPHONE01\\tdevice\\n'); process.exit(0); }
if (rest[0] === 'shell' && /ime list/.test(rest.slice(1).join(' '))) { process.stdout.write('com.android.adbkeyboard/.AdbIME\\n'); process.exit(0); }
process.exit(0);
`, { mode: 0o755 });

const adbCalls = () => (fs.existsSync(adbLog) ? fs.readFileSync(adbLog, 'utf8').trim().split('\n').filter(Boolean).map((l) => JSON.parse(l)) : []);
const textOf = (r) => (r?.content ?? []).map((c) => c.text ?? '').join('\n');

async function withServer(env, run) {
  fs.rmSync(adbLog, { force: true });
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [SERVER],
    env: { PATH: process.env.PATH, HOME: tmp, PHONE_ADB: fakeAdb, PHONE_SHOT_DIR: path.join(tmp, 'shots'), PHONE_MACRO_FILE: path.join(tmp, 'macros.json'), ...env },
    stderr: 'ignore',
  });
  const client = new Client({ name: 'phone-mcp-test', version: '0.0.0' });
  await client.connect(transport);
  try { await run(client); } finally { await client.close(); }
}

await test('PHONE_TOOLS：只注册列出的工具', async () => {
  await withServer({ PHONE_TOOLS: 'phone_status,phone_tap' }, async (client) => {
    const names = (await client.listTools()).tools.map((t) => t.name).sort();
    assert.deepEqual(names, ['phone_status', 'phone_tap']);
  });
  await withServer({}, async (client) => {
    const names = (await client.listTools()).tools.map((t) => t.name);
    assert.ok(names.includes('phone_connect') && names.includes('qzone_post'), '不设时照旧全部注册');
  });
});

await test('PHONE_SERIAL：phone_devices 切不走', async () => {
  await withServer({ PHONE_SERIAL: 'emulator-5554' }, async (client) => {
    const r = await client.callTool({ name: 'phone_devices', arguments: { use: 'REALPHONE01' } });
    assert.equal(r.isError, true);
    assert.match(textOf(r), /固定/);
    await client.callTool({ name: 'phone_tap', arguments: { x: 1, y: 2 } });
    const tap = adbCalls().find((a) => a.includes('shell') && /input tap/.test(a.join(' ')));
    assert.deepEqual(tap.slice(0, 2), ['-s', 'emulator-5554'], '点按还是落在固定的设备上');
  });
});

await test('限流对 phone_* 工具生效（之前 Proxy 装晚了，一个都没限）', async () => {
  await withServer({ PHONE_SERIAL: 'emulator-5554', PHONE_WRITE_PER_MINUTE: '2' }, async (client) => {
    const results = [];
    for (let i = 0; i < 3; i++) results.push(await client.callTool({ name: 'phone_tap', arguments: { x: i, y: i } }));
    assert.equal(results[0].isError, undefined);
    assert.equal(results[2].isError, true);
    assert.match(textOf(results[2]), /限流/);
    const macro = await client.callTool({ name: 'phone_macro', arguments: { actions: [{ type: 'sleep', ms: 1 }], screenshot: false } });
    assert.match(textOf(macro), /限流/, 'phone_macro 也算写操作');
  });
});

await test('phone_open_app：包名不能夹带命令', async () => {
  await withServer({ PHONE_SERIAL: 'emulator-5554' }, async (client) => {
    const r = await client.callTool({ name: 'phone_open_app', arguments: { pkg: 'com.x; pm uninstall com.tencent.mm' } });
    assert.equal(r.isError, true);
    assert.ok(!adbCalls().some((a) => /uninstall/.test(a.join(' '))), '不能有任何一次 adb 调用带上注入的命令');
    await client.callTool({ name: 'phone_open_app', arguments: { pkg: 'com.tencent.mm' } });
    assert.ok(adbCalls().some((a) => /am start .* -p com\.tencent\.mm$/.test(a.join(' '))), '正常包名照常启动');
  });
});

await test('phone_macro 的 text：整段加引号交给手机端 shell', async () => {
  await withServer({ PHONE_SERIAL: 'emulator-5554' }, async (client) => {
    const r = await client.callTool({ name: 'phone_macro', arguments: { actions: [{ type: 'text', text: "a'; settings put global adb_enabled 0; echo '" }], screenshot: false } });
    const call = adbCalls().find((a) => a.join(' ').includes('ADB_INPUT_TEXT'));
    assert.equal(r.isError, undefined, textOf(r));
    assert.ok(call, '应该发出了输入广播');
    assert.equal(call.length, 4, 'shell 后面只有一个参数（整条命令）');
    assert.equal(call[3], `am broadcast -a ADB_INPUT_TEXT --es msg 'a'\\''; settings put global adb_enabled 0; echo '\\'''`);
  });
});

await test('phone_macro：存宏、放宏能用（之前 log 没定义）', async () => {
  await withServer({ PHONE_SERIAL: 'emulator-5554' }, async (client) => {
    const saved = await client.callTool({ name: 'phone_macro', arguments: { actions: [{ type: 'tap', x: 5, y: 6 }], saveAs: 'demo' } });
    assert.equal(saved.isError, undefined, textOf(saved));
    const played = await client.callTool({ name: 'phone_macro', arguments: { playName: 'demo', screenshot: false } });
    assert.equal(played.isError, undefined, textOf(played));
    assert.ok(adbCalls().some((a) => a.join(' ').endsWith('input tap 5 6')));
  });
});

await test('phone_macro：一次最多 2000 步', async () => {
  await withServer({ PHONE_SERIAL: 'emulator-5554' }, async (client) => {
    const actions = Array.from({ length: 200 }, () => ({ type: 'tap', x: 1, y: 1 }));
    const r = await client.callTool({ name: 'phone_macro', arguments: { actions, repeat: 20, screenshot: false } });
    assert.equal(r.isError, true);
    assert.match(textOf(r), /最多 2000 步/);
    assert.ok(!adbCalls().some((a) => /input tap/.test(a.join(' '))), '超了就一步都不做');
  });
});

fs.rmSync(tmp, { recursive: true, force: true });
console.log(`\n${failures ? 'FAILED' : 'ALL PASS'}  tests=${tests} failures=${failures}`);
if (failures) process.exit(1);
