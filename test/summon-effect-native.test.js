import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {constructSummonEffect,applySummonEffect,removeSummonEffect,receiveSummonEvent} from '../src/summon_effect.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {addSummonedAssociate,unsummonCreature} from '../src/summon_associate.js';

test('summon constructor matches original argument grouping, PC rejection and stored fields',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-summon-constructor-observations.json',import.meta.url)));
 for(const row of fixture.rows){
  const c=row.case;if(c.failPop)continue;
  const calls=[],effect=constructSummonEffect([c.name,c.visual??-1,c.delay,c.appear??0,c.unsummon??99,c.target??100].slice(0,c.argc),99,{
   create:(type,creatorId,_ints,subtype)=>({type,subtype,creatorId,spellId:-1,casterLevel:-1,integers:Array(8).fill(0),objectIds:Array(4).fill(OBJECT_INVALID),floats:Array(4).fill(0)}),
   setCreator:(e,id)=>Object.assign(e,{creatorId:id,spellId:17,casterLevel:3}),
   creature:id=>{calls.push(['creature',id]);return c.exists===false?null:{nativeStatsIsPCb0:c.pc??0};}});
  const {strings,...expected}=row.output,actual={...effect};delete actual.strings;
  assert.deepEqual(actual,expected,JSON.stringify(c));assert.deepEqual(Object.fromEntries((effect.strings??[]).slice(0,1).map((v,i)=>[String(i),v])),strings,JSON.stringify(c));if(effect.strings)assert.deepEqual(effect.strings.slice(1),['','','','','']);assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});

test('unsummon matches original effect selection, client cleanup and deferred destruction',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-unsummon-observations.json',import.meta.url)));
 for(const row of fixture.rows){
  const c=row.case,calls=[],actor={id:99,masterId:100,nativeField540:c.open??0},master={id:100,effects:(c.effects??[]).map(e=>({type:e.type??6,objectIds:[OBJECT_INVALID,e.id??99],integers:[0,0,e.enabled??1,e.visual??99]}))};
  await unsummonCreature(actor,{message:()=>{calls.push(['message']);return c.message===false?null:{};},clearActions:o=>calls.push(['clear',o.id]),
   area:o=>{calls.push(['area',o.id]);return c.noArea?null:{};},creature:id=>{calls.push(['creature',id]);return c.master===false?null:master;},
   visual:(_a,id,pos,ori)=>calls.push(['visual',id,pos,ori]),position:()=>[1,2,3],orientation:()=>[4,5,6],
   client:id=>{calls.push(['client',id]);return c.client===false?null:{id};},sheet:()=>c.sheet===false?null:{},setDisplayed:(_s,id)=>calls.push(['displayed',id]),
   notPermitted:(_m,client,id)=>calls.push(['notPermitted',client.id,id]),feedback:(_o,code,data)=>calls.push(['feedback',code,data.objects[0]]),
   enqueue:(day,time,caller,recipient,id,data)=>calls.push(['event',day,time,caller,recipient,id,data??0])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});

test('summon association matches original replacement, list and faction ordering',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-summon-associate-observations.json',import.meta.url)));
 for(const row of fixture.rows){
  const c=row.case,calls=[],actor={id:99,factionId:7,associateIds:c.ids===null?null:[...c.ids]},
   target={id:101,associateType:c.targetType??0,nativeMovementRate:c.rate??0,masterId:OBJECT_INVALID},old={id:100,associateType:c.oldType??4},other={id:102,associateType:4},objects=new Map([[99,actor],[100,old],[101,target],[102,other]]);
  await addSummonedAssociate(actor,c.id??101,{module:()=>calls.push(['module']),
   creature:id=>{calls.push(['creature',id]);return c.missing&&id===101?null:objects.get(id)??null;},unsummon:o=>calls.push(['unsummon',o.id]),
   setMovementRate:(o,rate)=>{calls.push(['rate',o.id,rate]);o.nativeMovementRate=rate;},listenPatterns:o=>calls.push(['patterns',o.id]),
   setType:(o,type)=>{calls.push(['type',o.id,type]);o.associateType=type;},setMaster:(o,id)=>{calls.push(['master',o.id,id]);o.masterId=id;},
   faction:id=>{calls.push(['faction',id]);return c.faction===false?null:{};},addFactionMember:(_f,id,n)=>calls.push(['addMember',id,n])});
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.deepEqual(actor.associateIds??[],row.ids,label);assert.equal(target.nativeMovementRate,row.rate,label);assert.equal(target.associateType,row.type,label);assert.equal(target.masterId,row.master,label);
 }
});

test('delayed summon event matches original spawn script, association and appear effect ordering',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-summon-event-observations.json',import.meta.url)));
 for(const row of fixture.rows){
  const c=row.case,calls=[],actor={id:99},target={id:100,nativeSpawnState548:7};let areas=0;
  await receiveSummonEvent(actor,{floats:c.point??[1,2,3],objectIds:[c.id??100],integers:[c.appear??0]}, {
   creature:id=>{calls.push(['creature',id]);return c.exists===false?null:target;},
   area:o=>{calls.push(['area',o.id]);return c.noArea||c.vanishArea&&++areas===2?null:{id:88};},
   addToArea:(o,a,x,y,z,flag,last)=>calls.push(['addToArea',o.id,a?.id??null,[x,y,z],flag,last]),
   runEventScript:(o,index,name)=>calls.push(['script',o.id,index,name??0,o.nativeSpawnState548]),
   addAssociate:(_o,id,type)=>calls.push(['associate',id,type]),createEffect:(type,creatorId,integers)=>({type,creatorId,integers}),
   applyEffect:(o,e,a,b)=>calls.push(['effect',o.id,e.type,e.creatorId,e.integers[0],a,b])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(target.nativeSpawnState548,row.field548,JSON.stringify(c));
 }
});

test('summon apply/remove coordinator matches original ordering, failed loads and delayed event ownership',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-summon-lifecycle-observations.json',import.meta.url)));
 for(const [kind,rows]of [['apply',fixture.rows],['remove',fixture.removes]])for(const row of rows){
  const c=row.case,calls=[],actor={id:99,areaId:88,position:[1,2,3],orientation:[4,5,6]},target={id:100,masterId:c.master??OBJECT_INVALID,position:[7,8,9]},created={id:101},area={id:88},
   effect={strings:[c.name??'wolf'],integers:[c.visual??100,c.appear??0],objectIds:[c.areaId??OBJECT_INVALID,c.removeId??101,100,OBJECT_INVALID],floats:[21,22,23,c.delay??.5]},
   p={asCreature:o=>c.creature===false?null:o,creature:id=>{calls.push(['creature',id]);return c.exists!==false&&[100,101].includes(id)?{...target,id}:null;},
    area:o=>{calls.push(['area',o.id]);return c.targetNoArea?null:area;},position:o=>[...o.position],orientation:o=>[...o.orientation],
    visual:(_a,id,pos,ori)=>calls.push(['visual',id,pos,ori,0]),addAssociate:(_o,id,type)=>calls.push(['associate',id,type]),
    construct:()=>{calls.push(['construct']);return created;},destroy:o=>calls.push(['destroy',o.id]),
    areaById:id=>{calls.push(['areaById',id]);return c.noArea?null:area;},load:(_o,name,flag)=>{calls.push(['load',name,flag]);return c.load??1;},
    warning:()=>calls.push(['warning']),safeLocation:(_a,point,range,_path,flag,out)=>{calls.push(['safe',point,range,flag]);out.splice(0,3,11,12,13);return c.safe??1;},
    height:(_a,point)=>{calls.push(['height',[...point]]);return 17;},day:delay=>{calls.push(['day',delay]);return 2;},time:delay=>{calls.push(['time',delay]);return 1234;},
    enqueue:(day,time,caller,recipient,id,data)=>calls.push(['event',day,time,caller,recipient,id,Object.fromEntries(Object.entries(data).map(([key,values])=>[key,Object.fromEntries(values.map((v,i)=>[String(i),key==='integers'?v>>>0:v]))]))]),
    feedback:(_o,code,data)=>calls.push(['feedback',code,data.objects[0]]),unsummon:o=>calls.push(['unsummon',o.id])};
  const result=kind==='apply'?await applySummonEffect(actor,c.nullEffect?null:effect,c.loading??0,p):await removeSummonEffect(actor,effect,p),label=JSON.stringify({kind,...c});
  assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);assert.deepEqual(effect.objectIds,row.objects,label);assert.deepEqual(effect.floats,row.floats,label);
 }
});
