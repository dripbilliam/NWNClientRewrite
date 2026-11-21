import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptAssociateAccess,importModuleHenchmen,getMaxHenchmen,setMaxHenchmen} from '../src/henchman.js';
import {addHenchmanAssociate} from '../src/summon_associate.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffField,gffRecord} from '../src/gff_writer.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-henchmen-observations.json',import.meta.url)));

test('original associate-access wrappers preserve guard order, ownership, raw optional IDs and lower call sequence',async()=>{
 for(const row of capture.rows.filter(r=>r.case.mode==='script')){
  const c=row.case,calls=[],master={id:99},target={id:101,nativeField89c:c.pc??0,associateType:c.type??0,masterId:c.owner??99};
  const pops=c.failPop===1?1:2,failed=c.failPop===1||c.failPop===2;
  assert.deepEqual(row.calls.slice(0,c.argc===1?1:pops),Array(c.argc===1?1:pops).fill(['popObject']));
  if(failed){assert.equal(row.result,0xfffffd81);continue;}
  await scriptAssociateAccess(c.command,c.argc===1?[99]:[99,101],{
   creature:id=>{calls.push(['creature',id]);return id===99?(c.masterExists===false?null:master):id===101?(c.exists===false?null:target):null;},
   possessed:()=>{calls.push(['possessed',101]);return c.possessed??0;},dm:()=>{calls.push(['dm',101]);return c.dm??0;},
   add:(o,id)=>calls.push(['add',o.id,id,1]),remove:(o,id)=>calls.push(['remove',o.id,id]),activity:(o,bit,value)=>calls.push(['activity',o.id,bit,value]),
   removeInvisibility:o=>calls.push(['invisibility',o.id]),associate:(o,type,nth)=>{calls.push(['associate',o.id,type,nth]);return c.associate??101;}});
  assert.equal(row.result,0);assert.deepEqual(calls,row.calls.filter(r=>r[0]!=='popObject'),JSON.stringify(c));
 }
});

test('henchman addition matches original physical-list cap, movement, type/master and faction branches',async()=>{
 for(const row of capture.rows.filter(r=>r.case.mode==='add')){
  const c=row.case,calls=[],actor={id:99,factionId:7,associateIds:c.ids===null?null:[...c.ids]},target={id:101,associateType:0,masterId:99,nativeMovementRate:c.rate??0};
  const objects=new Map([[99,actor],[100,{associateType:c.oldType??1}],[101,target],[102,{associateType:1}]]);
  await addHenchmanAssociate(actor,c.id??101,{
   module:()=>{calls.push(['module']);return c.module===false?null:{nativeMaxHenchmen3fc:c.max??1};},
   creature:id=>{calls.push(['creature',id]);return id===101&&c.exists===false?null:objects.get(id);},
   feedback:(_o,code,data)=>calls.push(['feedback',code,data.integers[0]]),setMovementRate:(o,n)=>{calls.push(['rate',o.id,n]);o.nativeMovementRate=n;},
   listenPatterns:o=>calls.push(['patterns',o.id]),setType:(o,n)=>{calls.push(['type',o.id,n]);o.associateType=n;},setMaster:(o,id)=>{calls.push(['master',o.id,id]);o.masterId=id;},
   faction:id=>{calls.push(['faction',id]);return c.faction===false?null:{};},addFactionMember:(_f,id,n)=>calls.push(['addMember',id,n])});
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.deepEqual(actor.associateIds??[],row.ids,label);assert.equal(target.associateType,row.type,label);assert.equal(target.masterId,row.master,label);assert.equal(target.nativeMovementRate,row.rate,label);
 }
});

test('module cap matches native signed typed import, constructor/default and script-only clamp',()=>{
 for(const row of capture.rows.filter(r=>['get','set','load','ctor'].includes(r.case.mode))){
  const c=row.case,module=c.module===false?null:{nativeMaxHenchmen3fc:c.max??1};
  if(c.mode==='get'){assert.equal(getMaxHenchmen(module)>>>0,row.output);assert.equal(row.result,c.push===0?0xfffffd82:0);}
  else if(c.mode==='set'){if(c.pop===0){assert.equal(row.result,0xfffffd81);continue;}setMaxHenchmen(module,c.value);assert.equal(module?.nativeMaxHenchmen3fc??c.max,row.max);}
  else if(c.mode==='load'){
   const value=c.fieldType===0?c.value&255:c.fieldType===4?c.value>>>0:c.value,data=parseGff(writeGff('IFO ',gffRecord(c.present?{Mod_MaxHenchmen:gffField(c.fieldType,value)}:{}))).root;
   importModuleHenchmen(module,data);assert.equal(module.nativeMaxHenchmen3fc,row.max,JSON.stringify(c));
  }else{importModuleHenchmen(module,{});assert.equal(module.nativeMaxHenchmen3fc,row.max);assert.equal(row.adjacent,0);}
 }
 assert.equal(capture.rows.length,3258);assert.throws(()=>getMaxHenchmen({}),/unavailable/);
});

test('session henchman removal refuses foreign owners and retains malformed effect failures',async()=>{
 const s=new ModuleSession(null),master=s.register('creature','owner',{authored:{}}),other=s.register('creature','other',{authored:{}}),target=s.register('creature','henchman',{authored:{}}),cursor=s.registry.nextObjectId[0];
 master.associateIds=[target.id];target.associateType=1;target.masterId=master.id;target.originalFactionId=0;
 await s.commands.RemoveHenchman([other.id,target.id]);assert.equal(target.associateType,1);assert.deepEqual(master.associateIds,[target.id]);
 // Capture lower ownership/faction/GUI calls independently in the existing
 // RemoveAssociate oracle; this session check exercises real guard dispatch.
 let removed=0;s.lifecycle.removeAssociate=async(o,id)=>{assert.equal(o,master);assert.equal(id,target.id);removed++;};
 await s.commands.RemoveHenchman([master.id]);assert.equal(removed,0);
 await s.commands.RemoveHenchman([master.id,target.id]);assert.equal(removed,1);
 target.effects=[{id:'1',type:47,integers:[1]}];await assert.rejects(s.commands.RemoveHenchman([master.id,target.id]),/fixed payload storage/);assert.equal(removed,1);assert.equal(target.effects.length,1);
 target.associateType=4;target.effects=[];await s.commands.RemoveHenchman([master.id,target.id]);assert.equal(removed,1);
 await s.commands.RemoveSummonedAssociate([master.id,target.id]);assert.equal(removed,2);
 assert.equal(s.registry.nextObjectId[0],cursor);assert.notEqual(target.id,OBJECT_INVALID);
});

test('local henchman admission uses actual client possession/DM context and module constructor state',async()=>{
 const s=new ModuleSession(null),master=s.register('creature','master',{authored:{}}),target=s.register('player','local',{authored:{},stats:{},isDM:true});s.player=target;
 s.module=s.register('module','module',{});assert.equal(s.commands.GetMaxHenchmen([]),1);target.nativeField89c=0;
 let attached=0;s.lifecycle.associateProviders=()=>({module:()=>s.module,creature:id=>s.registry.get(id),setMovementRate:()=>{},listenPatterns:()=>attached++,setType:(o,n)=>{o.associateType=n;},setMaster:(o,id)=>{o.masterId=id;},faction:()=>null});
 await s.commands.AddHenchman([master.id,target.id]);assert.equal(attached,0);
 target.isDM=false;target.associateType=3;await s.commands.AddHenchman([master.id,target.id]);assert.equal(attached,0);
 target.associateType=0;await s.commands.AddHenchman([master.id,target.id]);assert.equal(attached,1);assert.equal(target.masterId,master.id);
 target.isDM=true;master.associateIds=[];await s.commands.AddHenchman([master.id,target.id]);assert.equal(attached,2); // native stats DM guard returns0 for nonzero associate type.
});
