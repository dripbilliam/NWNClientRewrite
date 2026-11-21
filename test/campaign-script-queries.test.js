import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptStringLeft,scriptStringToInt} from '../src/script_string.js';
import {scriptAssociateType,scriptSittingCreature,scriptObjectFacing,authoredVectorOrientation,authoredBearingOrientation} from '../src/script_object_queries.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-campaign-query-observations.json',import.meta.url)));
for(const mode of ['left','atoi','associate','sitting','facing'])test(`${mode} campaign query matches original bounded owner executions`,()=>{
  for(const {case:c,result} of oracle.rows.filter(r=>r.case.mode===mode)){
    let actual;
    if(mode==='left')actual=scriptStringLeft(c.text,c.count);
    if(mode==='atoi')actual=scriptStringToInt(c.text);
    if(mode==='associate')actual=scriptAssociateType(c.exists?{objectType:5,masterId:c.master,associateType:c.associate}:null);
    if(mode==='sitting')actual=scriptSittingCreature(c.exists?{objectType:9,nativeOccupant36c:c.occupant}:null);
    if(mode==='facing')actual=scriptObjectFacing(c.exists?{objectType:c.objectType,orientation:[c.orientation[0],c.orientation[2],Math.fround(-c.orientation[1])]}:null);
    assert.equal(actual,result,JSON.stringify(c));
  }
});
for(const mode of ['creature-orientation','waypoint-orientation','bearing-orientation'])test(`${mode} import matches bounded original loading instructions`,()=>{
  const rows=oracle.rows.filter(r=>r.case.mode===mode);assert.ok(rows.length>0);
  for(const {case:c,result} of rows){
    const vector=mode==='bearing-orientation'?authoredBearingOrientation(c):authoredVectorOrientation(c,mode==='waypoint-orientation');
    const actual=[vector[0],Math.fround(-vector[2]),vector[1]];
    // JSON cannot retain the native sign bit on zero; compare its numeric
    // value here. Full facing captures separately cover signed zero inputs.
    actual.forEach((value,i)=>assert.equal(value===0?0:value,result[i]===0?0:result[i],JSON.stringify(c)));
  }
});
test('campaign queries use canonical mutable cells and type guards through the live script table',()=>{
  const s=new ModuleSession(null),creature=s.register('creature','c',{}),chair=s.register('placeable','p',{}),area=s.register('area','a',{});
  assert.equal(s.commands.GetSittingCreature([chair.id]),OBJECT_INVALID);chair.nativeOccupant36c=0x80000001;
  assert.equal(s.commands.GetSittingCreature([chair.id]),0x80000001);s.unregister(creature.id);
  assert.equal(s.commands.GetSittingCreature([chair.id]),0x80000001);
  assert.equal(s.commands.GetSittingCreature([area.id]),OBJECT_INVALID);assert.equal(s.commands.GetAssociateType([chair.id]),0);
  assert.equal(s.commands.GetFacing([area.id]),0);assert.equal(s.commands.GetFacing([OBJECT_INVALID]),0);
  assert.equal(s.commands.GetStringLeft(['héllo',2]),'hé');assert.equal(s.commands.StringToInt(['2147483648']),2147483647);
});
