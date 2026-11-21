import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {scriptTalent,selectionTalent,talentValid,hasTalent,featTalent,skillTalent,creatureTalent} from '../src/talent.js';
import {NativeRandom} from '../src/native_random.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
const table=rows=>({rows:new Map(rows.map((r,i)=>[i,r])),orderedRows:rows});

test('native talent constructor and selector invalid values keep different class/metamagic cells',()=>{
  assert.deepEqual(scriptTalent(),{type:-1,id:-1,classIndex:0,itemId:OBJECT_INVALID,itemPropertyIndex:-1,casterLevel:255,metamagic:255});
  assert.deepEqual(selectionTalent(),{...scriptTalent(),classIndex:255,metamagic:0});
  assert.equal(talentValid(scriptTalent(0,-1)),1);assert.equal(talentValid(scriptTalent(100,-1)),1);
  assert.equal(talentValid(scriptTalent(-1,20)),0);
});

test('NWScript talent reservation, copying and accessors retain engine structure values',async()=>{
  const s=new ModuleSession(null),vm=new NwScriptVm({api:[],command:name=>s.commands[name]}),f={stack:[]};
  await vm.step(f,{op:2,type:0x13});assert.deepEqual(f.stack[0].value,scriptTalent());
  assert.equal(s.commands.GetIsTalentValid([f.stack[0].value]),0);
  f.stack[0].value=s.commands.TalentSkill([-2147483648]);
  await vm.step(f,{op:3,type:1,offset:-4,size:4});f.stack[1].value.id=7;
  assert.equal(s.commands.GetIdFromTalent([f.stack[0].value]),-2147483648);assert.equal(s.commands.GetTypeFromTalent([f.stack[0].value]),2);
  for(const [name,type] of [['TalentSpell',0],['TalentFeat',1],['TalentSkill',2]]){
    const value=s.commands[name]([-1]);assert.equal(value.type,type);assert.equal(s.commands.GetIsTalentValid([value]),1);
  }
});

test('feat and skill selections match60 original machine-code observations and effective-rank call order',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-talent-selector-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  for(const c of oracle.observations){
    const rules={feat:table(c.feats.map(f=>({Feat:f.valid===0?'****':'1',Category:String(f.category),MaxCR:String(f.maxCR)}))),
      skills:table(c.skills.map(s=>({Category:String(s.category),MaxCR:String(s.maxCR),Untrained:String(s.untrained??0)})))};
    const o={objectType:5,nativeField8d4:c.word,authored:{FeatList:c.ownedFeats.map(Feat=>({Feat}))}},rng=new NativeRandom(c.seed),calls=[];
    const p={random:()=>rng.next(),hasFeat:(o,id)=>c.feats[id].owned??1,remainingFeatUses:(o,id)=>c.feats[id].uses??100,
      skillRank:async(o,id)=>{calls.push(id);return c.skills[id].rank??0;}};
    const selected=await(c.kind==='feat'?featTalent:skillTalent)(o,c.category,c.maxCR,rules,p);
    assert.deepEqual({found:Number(Boolean(selected)),type:selected?.type??-1,id:selected?.id??-1,draws:rng.draws,skillCalls:calls},c.result,JSON.stringify(c));
  }
});

test('talent dispatcher preserves repeated failed branch draws and physical class order',async()=>{
  const o={objectType:5,nativeField8d4:65535,authored:{FeatList:[],ClassList:[{Class:1},{Class:2}]}},rules={feat:table([]),skills:table([]),classes:table([{}, {MemorizesSpells:'0'}, {MemorizesSpells:'2'}])};
  const draws=[1,1,2,2,0],calls=[];
  const p={random:()=>draws.shift(),spellLikeTalent:()=>{calls.push('ability');return null;},
    knownSpellTalent:(o,c,m,i)=>{calls.push(`known${i}`);return null;},memorizedSpellTalent:(o,c,m,i)=>{calls.push(`memo${i}`);return null;},
    itemSpellTalent:()=>{calls.push('item');return null;}};
  assert.deepEqual(await creatureTalent(o,16,20,rules,p),selectionTalent());assert.deepEqual(draws,[]);
  assert.deepEqual(calls,['ability','known0','memo1','item']);
  calls.length=0;await creatureTalent(o,17,20,rules,p);assert.deepEqual(calls,['item']);
  assert.deepEqual(await creatureTalent({objectType:6},16,20,rules,p),scriptTalent());
  await assert.rejects(()=>creatureTalent(o,18,20,rules,{}),/itemSpellTalent is unavailable/);
});

test('talent ownership uses native state WORD, remaining-use BYTE and signed effective skill rank',async()=>{
  const o={nativeField8d4:65535},rules={skills:table([{Untrained:'0'}, {Untrained:'1'}])},p={hasFeat:()=>1,remainingFeatUses:()=>256,skillRank:async()=>257};
  assert.equal(await hasTalent(o,1,3,0,rules,p),0);p.remainingFeatUses=()=>255;
  assert.equal(await hasTalent(o,1,3,0,rules,p),1);assert.equal(await hasTalent(o,2,0,0,rules,p),1);
  p.skillRank=async()=>255;assert.equal(await hasTalent(o,2,0,0,rules,p),0);assert.equal(await hasTalent(o,2,1,0,rules,p),1);
  o.nativeField8d4=4;assert.equal(await hasTalent(o,1,3,0,rules,p),0);
  assert.equal(await hasTalent(o,2,1,0,rules,p),0);
  await assert.rejects(()=>hasTalent(o,0,3,0,rules,p),/hasSpellTalent is unavailable/);
  assert.equal(await hasTalent(o,-1,3,0,rules,p),0);
});
