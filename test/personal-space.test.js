import test from 'node:test';
import assert from 'node:assert/strict';
import { updatePersonalSpace } from '../src/personal_space.js';
import { PathInformation } from '../src/path_information.js';
import { parse2da } from '../src/area.js';

test('native personal space reads physical appearance row and recomputes grid tolerance from actual personal radius',()=>{
  const actor={nativePathInfo:new PathInformation(0x80000001),creatureData:{Appearance_Type:65537}},path=actor.nativePathInfo;
  path.raw.setFloat32(0x58,2,true);path.field28=0x80000002;
  updatePersonalSpace(actor,{appearance:parse2da('2DA V2.0\n\nPERSPACE CREPERSPACE HITDIST HEIGHT\n40 .6 .2 .5 1\n99 1.2 .8 .4 2.5\n')});
  assert.equal(path.field4,Math.fround(1.2));assert.equal(path.field8,Math.fround(.8));assert.equal(path.fieldC,2.5);
  assert.equal(path.raw.getFloat32(0x10,true),Math.fround(.4));assert.equal(path.raw.getInt32(0x5c,true),1);assert.equal(path.field28,0x80000002);
});
test('native missing-column/output defaults differ for creature radius versus personal/hit/height fallbacks',()=>{
  const actor={nativePathInfo:new PathInformation(1),authored:{Appearance_Type:0}},warnings=[];
  const appearance=parse2da('2DA V2.0\nDEFAULT: 0.25\n\nOTHER\n0 1\n');
  updatePersonalSpace(actor,{appearance},{warning:message=>warnings.push(message)});
  assert.equal(actor.nativePathInfo.field4,Math.fround(.6));assert.equal(actor.nativePathInfo.field8,.25);assert.equal(actor.nativePathInfo.fieldC,1);
  assert.equal(actor.nativePathInfo.raw.getFloat32(0x10,true),.5);assert.equal(warnings.length,4);
});
test('empty CREPERSPACE outputs zero even with nonzero table default; explicit numeric zero is successful',()=>{
  const actor={nativePathInfo:new PathInformation(1),authored:{Appearance_Type:0}},warnings=[];
  updatePersonalSpace(actor,{appearance:parse2da('2DA V2.0\nDEFAULT: .25\n\nPERSPACE CREPERSPACE HITDIST HEIGHT\n0 0 **** 0 0\n')},{warning:m=>warnings.push(m)});
  assert.equal(actor.nativePathInfo.field4,0);assert.equal(actor.nativePathInfo.field8,0);assert.equal(actor.nativePathInfo.fieldC,0);
  assert.equal(warnings.length,1);assert.equal(actor.nativePathInfo.raw.getFloat32(0x10,true),0);
});
