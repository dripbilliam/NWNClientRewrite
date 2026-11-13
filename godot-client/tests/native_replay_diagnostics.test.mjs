import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {EventEmitter} from 'node:events';
import {spawn} from 'node:child_process';
import {NativeReplayDiagnostics} from '../tools/native-replay-diagnostics.mjs';

test('early native errors stay rejected after the readable tail is evicted',()=>{
 const stream=new NativeReplayDiagnostics();stream.write('ERROR: Cannot create shader cache folder\n');stream.write('WARNING: missing optional resource\n'.repeat(2000));
 assert.equal(stream.end().detected,true);assert.deepEqual(stream.snapshot().kinds,['engine-error']);
 assert.ok(stream.prefix.length<=64&&stream.carry.length<=64);
});
test('split UTF-8, marker boundaries, and final unterminated diagnostics are retained',()=>{
 const stream=new NativeReplayDiagnostics(),bytes=Buffer.from('é\nSCRIPT ERROR: fixture\nParse Error: fixture\nresources still in use');
 for(const byte of bytes)stream.write(Buffer.from([byte]));
 assert.deepEqual(stream.end().kinds,['parse-error','resources-in-use','script-error']);
 assert.equal(stream.snapshot().bytes,bytes.length);assert.throws(()=>stream.write('late'),/already ended/);
});
test('long lines retain lifetime classification without inventing line starts',()=>{
 const stream=new NativeReplayDiagnostics();stream.write('ObjectDB '+'.'.repeat(20000));stream.write(' instances were lea');stream.write('ked at exit\n');
 assert.deepEqual(stream.end().kinds,['objectdb-leak']);
 const clean=new NativeReplayDiagnostics();clean.write('WARNING: '+'.'.repeat(20000));clean.write('ERROR: quoted text\n');clean.write('WARNING: Original particle bitmap unavailable\nObjectDB\nleaked is on another line\n');
 assert.equal(clean.end().detected,false);
});
test('actual replay stream handlers latch both channels independently of bounded tails',()=>{
 const source=fs.readFileSync(new URL('../tools/replay-native-loading.mjs',import.meta.url),'utf8');
 const handlers=source.split('\n').find(line=>line.startsWith("child.stdout.on('data'"));
 assert.ok(handlers);
 const child=new EventEmitter();child.stdout=new EventEmitter();child.stderr=new EventEmitter();
 const report={},stdout=new NativeReplayDiagnostics(),stderr=new NativeReplayDiagnostics();
 vm.runInNewContext(handlers,{child,report,nativeStdoutDiagnostics:stdout,nativeStderrDiagnostics:stderr,ending:true});
 child.stdout.emit('data',Buffer.from('SCRIPT ER'));child.stdout.emit('data',Buffer.from('ROR: output fixture\n'));child.stdout.emit('data',Buffer.from('x'.repeat(15000)));
 child.stderr.emit('data',Buffer.from('ERROR: error fixture\n'));child.stderr.emit('data',Buffer.from('y'.repeat(15000)));
 assert.equal(/SCRIPT ERROR/.test(report.output),false);assert.equal(/^ERROR:/m.test(report.errors),false);
 assert.equal(stdout.snapshot().detected,true);assert.equal(stderr.snapshot().detected,true);
});
test('actual replay close/EOF wiring drains a real child before diagnostic acceptance',async()=>{
 const source=fs.readFileSync(new URL('../tools/replay-native-loading.mjs',import.meta.url),'utf8'),lines=source.split('\n');
 const code=[lines.find(x=>x.startsWith('childClosed=new Promise')),lines.find(x=>x.startsWith("child.stdout.once('end'")),lines.find(x=>x.startsWith("child.stdout.on('data'"))].join('\n');
 const child=spawn(process.execPath,['-e',"process.stdout.write('SCRIPT ERROR: output fixture\\n'+'warning\\n'.repeat(20000));process.stderr.write('ERROR: error fixture\\n'+'warning\\n'.repeat(20000));"],{stdio:['ignore','pipe','pipe'],windowsHide:true});
 const context={child,report:{},nativeStdoutDiagnostics:new NativeReplayDiagnostics(),nativeStderrDiagnostics:new NativeReplayDiagnostics(),ending:true};
 vm.runInNewContext(code,context);await context.childClosed;
 assert.equal(context.report.exit,0);
 for(const stream of [context.nativeStdoutDiagnostics,context.nativeStderrDiagnostics]){assert.equal(stream.snapshot().closed,true);assert.equal(stream.snapshot().detected,true);}
 assert.equal(/SCRIPT ERROR/.test(context.report.output),false);assert.equal(/^ERROR:/m.test(context.report.errors),false);
});
