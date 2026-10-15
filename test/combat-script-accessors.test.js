import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {getActionMode} from '../src/combat_mode.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {PlayerEnumeration} from '../src/player_enumeration.js';
import {FactionReputationTable} from '../src/reputation.js';

test('combat and encounter script queries read canonical runtime fields including raw nonboolean combat state',()=>{
  const s=new ModuleSession(null),o=s.register('creature','c',{}),door=s.register('door','d',{});
  assert.equal(s.commands.GetIsInCombat([o.id]),0);o.nativeField700=7;
  assert.equal(s.commands.GetIsInCombat([o.id]),7);
  assert.equal(s.commands.GetIsEncounterCreature([o.id]),0);
  o.nativeField948=0x80000001;assert.equal(s.commands.GetIsEncounterCreature([o.id]),1);
  o.nativeField948=OBJECT_INVALID;assert.equal(s.commands.GetIsEncounterCreature([o.id]),0);
  for(const id of [OBJECT_INVALID,door.id]){assert.equal(s.commands.GetIsInCombat([id]),0);assert.equal(s.commands.GetIsEncounterCreature([id]),0);}
});
test('night query consumes the native cached byte and absent module returns zero',()=>{
  const s=new ModuleSession(null);assert.equal(s.commands.GetIsNight(),0);
  s.module={nativeTimeOfDay3d4:2};assert.equal(s.commands.GetIsNight(),1);
  for(const value of [0,1,3,4]){s.module.nativeTimeOfDay3d4=value;assert.equal(s.commands.GetIsNight(),0);}
  s.module.nativeTimeOfDay3d4=258;assert.equal(s.commands.GetIsNight(),1);
});
test('action mode narrows only the native bytes and detect requires exactly one',async()=>{
  const o={nativeField6ed:1,combatMode:0};
  assert.equal(await getActionMode(o,257),1);o.nativeField6ed=2;assert.equal(await getActionMode(o,1),0);
  for(let mode=1;mode<=11;mode++){o.combatMode=mode;assert.equal(await getActionMode(o,mode+1),1);assert.equal(await getActionMode(o,mode===11?2:mode+2),0);}
  for(const value of [0,1,2])assert.equal(await getActionMode(o,0,()=>value),Number(value===1));
  assert.equal(await getActionMode({},255),0);
});
test('script detect mode includes Keen Senses and preserves idle implicit mode2',async()=>{
  const s=new ModuleSession(null),o=s.register('creature','c',{creatureData:{FeatList:[]},stats:{feats:[]}});
  assert.equal(await s.commands.GetActionMode([o.id,0]),0);
  o.nativeField6ec=1;assert.equal(await s.commands.GetActionMode([o.id,0]),1);
  o.nativeField6ec=0;o.creatureData.FeatList=[{Feat:240}];assert.equal(await s.commands.GetActionMode([o.id,0]),1);
  assert.equal(await s.commands.GetActionMode([OBJECT_INVALID,0]),0);
});
test('first/next PC use a shared live client-slot cursor, skip holes and invalid PCs',()=>{
  const e=new PlayerEnumeration(),slots=[null,{id:OBJECT_INVALID},{id:0x80000001},null,{id:3}],id=c=>c.id;
  assert.equal(e.next(slots,id),0x80000001);assert.equal(e.next(slots,id),3);assert.equal(e.next(slots,id),OBJECT_INVALID);
  assert.equal(e.next(slots,id,true),0x80000001);slots[4]={id:9};assert.equal(e.next(slots,id),9);
  assert.equal(e.next([],id,true),OBJECT_INVALID);
  const s=new ModuleSession(null),pc=s.register('creature','authored',{isPC:true});
  assert.equal(s.commands.GetFirstPC(),OBJECT_INVALID);s.player=pc;pc.stats={};
  assert.equal(s.commands.GetFirstPC(),pc.id);assert.equal(s.commands.GetNextPC(),OBJECT_INVALID);
});
test('listening is one canonical raw INT cell on generic objects, not a boolean',()=>{
  const s=new ModuleSession(null),door=s.register('door','d',{});
  assert.equal(s.commands.GetIsListening([door.id]),0);
  for(const value of [1,7,-1,0x80000000,0]){s.commands.SetListening([door.id,value]);assert.equal(s.commands.GetIsListening([door.id]),value|0);}
  s.commands.SetListening([OBJECT_INVALID,1]);assert.equal(s.commands.GetIsListening([OBJECT_INVALID]),0);
});
test('day query consumes the native cached byte and fails on absent initialized state',()=>{
  const s=new ModuleSession(null);assert.equal(s.commands.GetIsDay(),0);s.module={nativeTimeOfDay3d4:257};assert.equal(s.commands.GetIsDay(),1);
  s.module.nativeTimeOfDay3d4=2;assert.equal(s.commands.GetIsDay(),0);delete s.module.nativeTimeOfDay3d4;assert.throws(()=>s.commands.GetIsDay(),/unavailable/);
});
test('legacy emotions query target toward source, preserve10/11/89/90 boundaries and missing-source neutral',()=>{
  const s=new ModuleSession(null),a=s.register('creature','a',{factionId:1}),b=s.register('creature','b',{factionId:2});
  for(const reputation of [0,10,11,89,90,100]){
    s.factionTable=new FactionReputationTable(2,[{FactionID1:2,FactionID2:1,FactionRep:reputation},{FactionID1:1,FactionID2:2,FactionRep:100-reputation}]);
    assert.equal(s.commands.GetIsEnemy([b.id],{self:a.id}),Number(reputation<=10));
    assert.equal(s.commands.GetIsFriend([b.id,a.id]),Number(reputation>=90));
    assert.equal(s.commands.GetIsNeutral([b.id,a.id]),Number(reputation>=11&&reputation<=89));
  }
  assert.equal(s.commands.GetIsNeutral([b.id,OBJECT_INVALID]),1);assert.equal(s.commands.GetIsNeutral([OBJECT_INVALID,a.id]),0);
});
