import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root=fileURLToPath(new URL('../../',import.meta.url));
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p)));
const report=read('godot-client/reports/native-overhead-mode-change-original-v4.json');
const fixture=read('godot-client/tests/fixtures/native-overhead-mode-change-v1.json');
const fbits=n=>{const b=Buffer.alloc(4);b.writeFloatLE(n);return b.readUInt32LE();};
const currentText=row=>Buffer.concat(row.lines.filter(x=>x!==null).map(x=>{const b=Buffer.from(x,'hex'),end=b.indexOf(0);return end<0?b:b.subarray(0,end);}));

test('pinned original owner execution and explicit captured-lower limits',()=>{
 assert.equal(report.success,true);assert.equal(report.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 assert.equal(report.cases.length,80);assert.equal(report.fontCases.length,12);
 assert.ok(report.originalInstructions>30000);assert.equal(report.enginesRun,0);assert.equal(report.networkConnections,0);assert.equal(report.productionChanged,false);assert.equal(report.liveProcessAccess,false);
 assert.equal(report.lowerCallbacksCaptured,true);
 assert.match(report.scope,/No native font wrapping/);
 assert.deepEqual(Object.keys(report.executedRanges),['mode','setter','concat','init','font','bubbleFont']);
});
test('current caption bytes, ordering, exact setter arguments and timer reset',()=>{
 for(const r of report.cases){
  const setters=r.trace.filter(e=>e.event==='setter');
  if(r.oldMode===r.newMode){assert.deepEqual(r.trace,[]);assert.deepEqual(r.before,r.after);continue;}
  assert.equal(setters.length,r.rows.length,r.name);
  for(let i=0;i<r.rows.length;i++){
   const text=currentText(r.rows[i]),s=setters[i];assert.equal(s.index,i);assert.equal(s.bytes,text.toString('hex'));assert.equal(s.length,text.length);
   assert.deepEqual([s.minimum,s.maximum,s.scale,s.forced],[4,12,1,0]);
   assert.equal(r.after[i].durationBits,fbits(Math.max(4,Math.min(12,Math.fround(Math.fround(text.length)*Math.fround(.15))))));
   assert.equal(r.after[i].elapsedBits,0);assert.equal(r.after[i].timed,r.before[i].timed);assert.equal(r.after[i].minimumLines,2);
  }
 }
});
test('no inserted newline, space, parsing or CP1252-to-UTF8 conversion',()=>{
 const chosen=name=>report.cases.find(r=>r.name===name&&r.oldMode===0&&r.newMode===1).trace.find(e=>e.event==='setter').bytes;
 assert.equal(chosen('no-inserted-separator'),'46697273745365636f6e64');
 assert.equal(chosen('returned-newline'),'46697273740a5365636f6e64');
 assert.equal(chosen('cp1252'),'4a6f73e92096676f');
 assert.equal(chosen('literal-native-markup'),'3c63ff01023e48693c2f633e');
 assert.equal(chosen('embedded-nul'),'416c70686142657461');
 assert.equal(chosen('null-empty'),'');
 assert.equal(fixture.fixtures.length,11);
});
test('Off, text-only and full affect inactive and hover/cache entries in original registry order',()=>{
 for(const r of report.cases){
  assert.equal(r.registryUnchanged,true);
  if(r.oldMode===r.newMode)continue;
  for(let i=0;i<r.rows.length;i++){
   assert.equal(r.after[i].full,Number(r.newMode===2));assert.equal(r.after[i].off,Number(r.newMode===0));
   assert.equal(r.after[i].sizeChoice,0xffffffff);
   assert.equal(r.after[i].indentBits,fbits(r.newMode===2&&r.rows[i].portrait?23:0));
   const operations=r.trace.filter(e=>e.index===i&&['deactivate','activate','scene-first'].includes(e.event)).map(e=>e.event);
   assert.deepEqual(operations,r.rows[i].active?['deactivate',...(r.newMode===0?[]:['activate','scene-first'])]:[]);
  }
 }
 const mixed=report.cases.filter(r=>r.name==='mixed-registry');assert.equal(mixed.length,3);
 for(const r of mixed)assert.deepEqual(r.trace.filter(e=>e.event==='setter').map(e=>e.index),[0,1,2]);
});
test('font refresh and bubble SetFont do not run timer setter or reset source popup fields',()=>{
 for(const r of report.fontCases){
  assert.deepEqual(r.before,r.after);assert.equal(r.registryUnchanged,true);
  assert.equal(r.trace.some(e=>e.event==='setter'),false);
  assert.deepEqual(r.trace.filter(e=>e.event==='caption-font').map(e=>e.index),r.guiInitialized?[0,1,2]:[]);
  assert.equal(r.trace.filter(e=>e.event==='font-remap').length,r.guiInitialized?3:0);
  assert.ok(Buffer.from(r.requestedFont,'hex').length>0);assert.ok(Buffer.from(r.remappedFont,'hex').length>0);
  for(const e of r.trace.filter(e=>e.event==='font-remap'))assert.equal(e.requested,r.requestedFont);
  for(const e of r.trace.filter(e=>e.event==='caption-font'))assert.equal(e.font,r.remappedFont);
 }
});
test('recorded harness, fixtures and retained source reports are unchanged',()=>{
 for(const [p,sha]of Object.entries(report.inputHashes))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex'),sha,p);
});
test('earlier fail-closed harness range rejections are preserved',()=>{
 const v1=read('godot-client/reports/native-overhead-mode-change-original-v1.json'),v2=read('godot-client/reports/native-overhead-mode-change-original-v2.json');
 assert.equal(v1.success,false);assert.match(v1.error,/0x14003d987/);assert.equal(v1.cases.length,0);
 assert.equal(v2.success,false);assert.match(v2.error,/0x1406fa12f/);assert.equal(v2.cases.length,80);
});
