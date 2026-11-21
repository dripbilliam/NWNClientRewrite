import test from 'node:test';
import assert from 'node:assert/strict';
import {talentSpell} from '../src/spell_metadata.js';
import {spellLikeTalent,classSpellTalent,spellSuitability,itemSpellTalent} from '../src/spell_talent.js';
const table=rows=>({rows:new Map(rows.map((r,i)=>[i,r])),orderedRows:rows});

test('spell talent metadata uses physical rows, INT ranking, BYTE innate, eight compacted children and master fallback',()=>{
  const rules={spells:table([{Category:'16',Innate:'257',SubRadSpell1:'2',SubRadSpell3:'-1',SubRadSpell8:'0x3'}, {Innate:'****',Master:'****'}])};
  assert.deepEqual(talentSpell(rules,0),{id:0,category:16,maxCR:513,innate:1,master:0,children:[2,-1,3]});
  assert.deepEqual(talentSpell(rules,1),{id:1,category:0,maxCR:-1,innate:255,master:1,children:[]});
  assert.equal(talentSpell(rules,-1),null);assert.equal(talentSpell(rules,2),null);
});

test('suitability checks ownership before PvP category swap and skips area filtering when area is absent',async()=>{
  const spell={id:3,category:11,innate:2},d={memorized:1,parentId:4},calls=[],p={slotMetamagic:()=>{calls.push('meta');return 16;},
    hasSpellTalent:(o,id)=>{calls.push(id);return id===4;},area:()=>({}),effectivePVP:()=>0,metamagicCost:()=>1};
  assert.deepEqual(await spellSuitability({},spell,1,5,d,p),{metamagic:16});assert.deepEqual(calls,['meta',3,4,'meta']);
  assert.equal(await spellSuitability({},spell,1,4,d,p),null);
  p.effectivePVP=()=>2;assert.equal(await spellSuitability({},spell,1,-1,d,p),null);
  p.area=()=>null;assert.deepEqual(await spellSuitability({},spell,99,-1,d,p),{metamagic:16});
  p.hasSpellTalent=()=>0;p.area=()=>assert.fail('Ownership must short-circuit');
  assert.equal(await spellSuitability({},spell,1,5,d,p),null);
});

test('class selection keeps ready slots and repeated subradials with their source metamagic',async()=>{
  const rules={spells:table([{Category:'16',Innate:'1',SubRadSpell1:'1',SubRadSpell2:'2'}, {Innate:'4'}, {Innate:'4'}])},seen=[];
  const p={random:()=>1,spellsPerDayLeft:()=>1,knownCount:(o,i,l)=>l===0?1:0,knownSlot:()=>0,
    memorizedCount:(o,i,l)=>l===0?3:0,memorizedSlot:(o,i,l,s)=>({id:0,ready:s===0?0:1}),
    suitable:(o,spell,c,m,d)=>{seen.push({...d,id:spell.id});return {metamagic:d.slot===1?16:32};}};
  const memo=await classSpellTalent({},16,20,2,true,rules,p);
  assert.equal(memo.type,0);assert.equal(memo.id,2);assert.equal(memo.metamagic,16);assert.equal(memo.classIndex,2);
  assert.deepEqual(seen.map(s=>[s.id,s.slot,s.parentId]),[[1,1,0],[2,1,0],[1,2,0],[2,2,0]]);
  seen.length=0;const known=await classSpellTalent({},16,-1,2,false,rules,p);assert.equal(known.id,2);assert.equal(known.metamagic,0);
  p.knownCount=()=>256;await assert.rejects(()=>classSpellTalent({},16,-1,0,false,rules,p),/wrap its BYTE/);
});

test('spell-like selection uses nonzero remaining and physical duplicates with the native254 class sentinel',async()=>{
  const rules={spells:table([{Innate:'1'}, {Innate:'5'}])},p={random:()=>1,suitable:()=>({metamagic:0}),
    spellLikeList:()=>[{id:0,remaining:1,casterLevel:3},{id:1,remaining:0,casterLevel:2},{id:1,remaining:2,casterLevel:8},{id:1,remaining:-1,casterLevel:9}]};
  const result=await spellLikeTalent({},16,20,rules,p);assert.equal(result.id,1);assert.equal(result.casterLevel,9);assert.equal(result.classIndex,254);
});

test('item selector distinguishes equipped suitability from carried potion aliases and retains canonical IDs/property indices',async()=>{
  const rules={spells:table([{Category:'4',Innate:'2'}, {Category:'5',Innate:'8'}, {Category:'16',Innate:'9'}]),iprp_spells:table([{SpellIndex:'0'},{SpellIndex:'1'},{SpellIndex:'2'}])};
  const a={id:0x80000001,base:49},b={id:0x80000002,base:49},c={id:3,base:22},items=new Map([[a.id,a],[b.id,b],[c.id,c]]);
  let draws=0;const p={random:()=>{draws++;return 0;},equipmentSlot:(o,slot)=>slot===16?c:null,
    repositoryIds:()=>[b.id,a.id],itemById:id=>items.get(id),baseItem:i=>i.base,equipableSlots:()=>0,charges:()=>0,
    canUseItem:()=>1,hasProperty:()=>1,activeProperties:i=>i===c?[{type:15,subtype:2,remaining:1}]:[{type:0,subtype:0,remaining:0},{type:15,subtype:i===a?0:1,remaining:1}],
    suitable:()=>null};
  const result=await itemSpellTalent({},17,0,rules,p);
  assert.equal(result.id,1);assert.equal(result.itemId,b.id);assert.equal(result.itemPropertyIndex,1);assert.equal(result.classIndex,255);
  assert.equal(draws,1);assert.equal(await itemSpellTalent({},4,-1,rules,p),null);
  p.suitable=()=>({metamagic:0});const equipped=await itemSpellTalent({},16,0,rules,p);assert.equal(equipped.itemId,c.id);assert.equal(equipped.id,2);
  // Charges permit an exhausted carried property, but never an equipped one.
  p.activeProperties=()=>[{type:15,subtype:2,remaining:0}];p.charges=()=>1;
  assert.equal((await itemSpellTalent({},16,-1,rules,p)).itemId,b.id);
});
