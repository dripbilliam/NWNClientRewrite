import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {canUseItem} from '../src/item_use.js';
import {useMagicDevice,alignmentRestrictions,classRestrictions,raceRestrictions,itemProficient,scrollSchoolAllowed} from '../src/item_restrictions.js';
const table=rows=>({rows:new Map(rows.map((r,i)=>[i,r])),orderedRows:rows});

test('item eligibility and proficiency match669 executions of the complete native gate bodies',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-item-use-observations.json',import.meta.url)));
  assert.equal(oracle.observations.length,669);
  for(const c of oracle.observations){
    const calls=[],query=(name,value)=>()=>{calls.push(name);return value;};
    let result;
    if(c.kind==='use'){
      const o={associateType:c.associate,nativeField97c:c.polymorph,nativeField89c:c.pc,nativeSize718:c.size};
      result=await canUseItem(o,{},c.ignore,{
        isDM:query('isDM',c.dm),alignmentRestrictions:query('alignmentRestrictions',c.alignment),
        classRestrictions:query('classRestrictions',c.class),raceRestrictions:query('raceRestrictions',c.race),
        controlledByPlayer:query('controlledByPlayer',c.controlled),itemLevelRestrictions:query('itemLevelRestrictions',c.ilr),
        level:query('level',c.level),minimumEquipLevel:query('minimumEquipLevel',c.minimum),identified:()=>c.identified,
        baseItem:()=>c.base,scrollSchoolAllowed:()=>1,baseInfo:()=>({weaponWield:c.weaponWield,weaponType:c.weaponType,weaponSize:c.weaponSize,equipableSlots:c.slots}),
        proficient:query('proficient',c.proficient)});
    }else result=await itemProficient({}, {},c.slot,{
      baseInfo:()=>c.baseValid===0?null:{equipableSlots:c.slots,modelType:c.modelType,requiredFeats:c.requiredFeats},
      armorClass:query('armorClass',c.armor),hasFeat:(o,id)=>{calls.push(`hasFeat:${id}`);return Number(c.ownedFeats.includes(id));}});
    assert.equal(result,c.result,JSON.stringify(c));assert.deepEqual(calls,c.calls,JSON.stringify(c));
  }
});

test('UMD uses the first physical cost bracket, signed BYTE rank, typed requirement success and ordered queries',async()=>{
  const rules={usemagicdevice:table([{DeviceCostMax:'100',SkillReq_Class:'5',SkillReq_Race:'6',SkillReq_Align:'7'},
    {DeviceCostMax:'1000',SkillReq_Class:'1',SkillReq_Race:'2',SkillReq_Align:'3'}])},calls=[];
  const p={skillRank:(o,id)=>{calls.push(['rank',id]);return 263;},canUseSkill:(o,id)=>{calls.push(['can',id]);return 1;},
    itemCost:(item,...args)=>{calls.push(['cost',...args]);return 100;}};
  assert.equal(await useMagicDevice({}, {},2,rules,p),1);assert.deepEqual(calls,[['rank',19],['can',19],['cost',0,1,1,1]]);
  p.skillRank=()=>256+4;assert.equal(await useMagicDevice({}, {},0,rules,p),0);
  p.skillRank=()=>255;assert.equal(await useMagicDevice({}, {},0,rules,p),0);
  rules.usemagicdevice.orderedRows[0].SkillReq_Class='****';p.skillRank=()=>127;
  assert.equal(await useMagicDevice({}, {},0,rules,p),0);
  p.canUseSkill=()=>0;p.itemCost=()=>assert.fail('Unusable skill must not query cost');
  assert.equal(await useMagicDevice({}, {},0,{},p),0);
});

test('alignment restrictions union group and specific cells and respect native simple alignment enums',async()=>{
  let props=[],law=2,good=4,umd=0;
  const p={hasProperty:(i,type)=>Number(props.some(p=>p.type===type)),passiveProperties:()=>props,
    skillRank:()=>10,canUseSkill:()=>umd,itemCost:()=>0,lawChaos:()=>law,goodEvil:()=>good};
  const rules={usemagicdevice:table([{DeviceCostMax:'100',SkillReq_Align:'10'}])};
  assert.equal(await alignmentRestrictions({}, {},rules,p),1);
  for(let group=1;group<=5;group++){
    props=[{type:62,subtype:group}];
    for(const [l,lawEnum] of [2,1,3].entries())for(const [g,goodEnum] of [4,1,5].entries()){
      law=lawEnum;good=goodEnum;
      const allowed={1:[1,3,4,5,7],2:[0,1,2],3:[6,7,8],4:[0,3,6],5:[2,5,8]}[group];
      assert.equal(await alignmentRestrictions({}, {},rules,p),Number(allowed.includes(l*3+g)));
    }
  }
  props=[{type:62,subtype:2},{type:65,subtype:8}];law=3;good=5;
  assert.equal(await alignmentRestrictions({}, {},rules,p),1);
  law=1;good=1;assert.equal(await alignmentRestrictions({}, {},rules,p),0);
  umd=1;assert.equal(await alignmentRestrictions({}, {},rules,p),1);
  umd=0;props=[{type:65,subtype:9}];await assert.rejects(()=>alignmentRestrictions({}, {},rules,p),/nine-cell/);
});

test('class and race restrictions use physical passive records and distinct storage widths',async()=>{
  let props=[{type:63,subtype:14},{type:64,subtype:0x101}],classes=[270],race=0x101,umd=0;
  const p={hasProperty:(i,type)=>Number(props.some(p=>p.type===type)),passiveProperties:()=>props,classIds:()=>classes,race:()=>race,
    skillRank:()=>5,canUseSkill:()=>umd,itemCost:()=>1};
  const rules={usemagicdevice:table([{DeviceCostMax:'100',SkillReq_Class:'5',SkillReq_Race:'6'}])};
  assert.equal(await classRestrictions({}, {},rules,p),1);assert.equal(await raceRestrictions({}, {},rules,p),1);
  classes=[13];race=1;assert.equal(await classRestrictions({}, {},rules,p),0);assert.equal(await raceRestrictions({}, {},rules,p),0);
  umd=1;assert.equal(await classRestrictions({}, {},rules,p),1);assert.equal(await raceRestrictions({}, {},rules,p),0);
  props=[];assert.equal(await classRestrictions({}, {},{},p),1);assert.equal(await raceRestrictions({}, {},{},p),1);
});

test('scroll opposition examines the first active property for each specialist class and retains a prior rejection',async()=>{
  const rules={classes:table([{PickSchool:'0'},{PickSchool:'1'},{PickSchool:'2'}]),
    iprp_spells:table([{SpellIndex:'0'},{SpellIndex:'1'}]),spells:table([{School:'A'},{School:'N'}]),
    spellschools:table([{}, {Opposition:'1'},{Opposition:'7'}])};
  const calls=[],p={classIds:()=>[0,1,2],classSchool:(o,i)=>{calls.push(['school',i]);return i;},
    firstActiveProperty:()=>{calls.push('property');return{type:80,subtype:0,remaining:0};}};
  assert.equal(await scrollSchoolAllowed({}, {},rules,p),0);assert.deepEqual(calls,[['school',1],'property',['school',2],'property']);
  p.classSchool=()=>0;p.firstActiveProperty=()=>assert.fail('Generalist skips property query');
  assert.equal(await scrollSchoolAllowed({}, {},rules,p),1);
  p.classSchool=()=>1;p.firstActiveProperty=()=>null;assert.equal(await scrollSchoolAllowed({}, {},rules,p),1);
});
