import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {removeEffectsById,removeEffectTarget,updateEffectList} from '../src/effect_removal.js';
import {NativeIdList} from '../src/native_id_list.js';
import {ModuleSession} from '../src/module_session.js';
import {addWorldTimes} from '../src/world_timer.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-removal-observations.json',import.meta.url)));
const newEffect=()=>({id:'000000000000004d',type:62,subtype:8,durationType:2,duration:3.25,creatorId:98,spellId:11,casterLevel:7,showIcon:1,exposed:1,bypassImmunity:0,propertyId:'000000000000007b',customTag:'',integers:[1,0,0,0,0,0,0,0],strings:['fixture','','','','',''],floats:[0,0,0,0],objectIds:Array(4).fill(0x7f000000),vectors:[[0,0,0],[0,0,0]]});
function replay(row,asyncCallbacks){
 const c=structuredClone(row.case),object={id:99,objectType:c.objectType??5,effects:structuredClone(row.before)},source={id:98,nativeCreatedAreaEffects170:new NativeIdList()},calls=[];
 for(const value of c.targets??[1,99,2])source.nativeCreatedAreaEffects170.append(value);
 let count=0;
 const fresh=()=>c.mode==='update'?{...newEffect(),expiryDay:0,expiryTime:0}:newEffect();
 const p={object:id=>id===98&&c.sourceExists!==false?source:id===99&&c.targetExists!==false?object:null,
  asWorld:o=>o===source?c.sourceWorld!==false?o:null:c.targetWorld!==false?o:null,
  onRemove:(o,e)=>{calls.push(['callback',structuredClone(e)]);count++;
   if(count===1)switch(c.mutation){
    case 'remove':o.effects=o.effects.filter(v=>v!==e);break;
    case 'clear':o.effects=[];break;
    case 'integer':e.integers[0]=2;break;
    case 'creator':e.creatorId=97;break;
    case 'flags':e.subtype=8;e.durationType=1;break;
    case 'ignored':e.duration=0.5;e.showIcon=0;e.exposed=0;break;
    case 'replace':o.effects=o.effects.map(v=>v===e?structuredClone(e):v);break;
    case 'reverse':o.effects.reverse();break;
    case 'append':o.effects.push(fresh());break;
    case 'prepend':o.effects.unshift(fresh());break;
    case 'sourceGone':c.sourceExists=false;break;
    case 'targetGone':c.targetExists=false;break;
    case 'targetNotWorld':c.targetWorld=false;break;
    case 'defer':e.integers[1]=1;e.subtype=8;e.durationType=1;e.duration=0.5;e.expiryDay=c.day??0;e.expiryTime=(c.time??101)+500;break;
   }
   const status=c.statuses??[1],result=status[Math.min(count-1,status.length-1)];return asyncCallbacks?Promise.resolve(result):result;
  },afterRemove:(_o,e)=>{calls.push(['pointers'],['attributes',structuredClone(e),0]);return asyncCallbacks?Promise.resolve():undefined;},
  removeTarget:(o,id)=>{calls.push(['target',id]);removeEffectTarget(o,id,p);}};
 const finish=result=>{assert.equal(result??null,row.result,JSON.stringify(row.case));assert.deepEqual(calls,row.calls,JSON.stringify(row.case));assert.deepEqual(object.effects,row.effects,JSON.stringify(row.case));assert.deepEqual([...source.nativeCreatedAreaEffects170.view()],row.targets,JSON.stringify(row.case));};
 const result=c.mode==='update'?updateEffectList(object,{poll:(_o,e)=>{calls.push(['poll',structuredClone(e)]);return false;},expired:e=>(c.day??0)>e.expiryDay||((c.day??0)===e.expiryDay&&(c.time??101)>e.expiryTime),remove:(o,id)=>removeEffectsById(o,id,p)}):removeEffectsById(object,'4d',p);if(result?.then)return result.then(finish);finish(result);
}
test('shared removal matches original live traversal, full-value assignment/equality, retention and target cleanup',()=>{
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,936);
 for(const row of oracle.rows)replay(row,false);
});
test('awaited engine callbacks preserve the same original ordering and live cursor',async()=>{for(const row of oracle.rows)await replay(row,true);});
test('live expiry traversal and restart after removal agree with original UpdateEffectList instructions',async()=>{
 assert.equal(oracle.updates.length,324);
 for(const row of oracle.updates)await replay(row,true);
});
test('value replacement erases its matching slot while releasing the original, and callback rejection retains it',()=>{
 const original=newEffect(),o={id:99,objectType:6,effects:[original]},destroyed=[];
 const p={object:()=>null,onRemove:()=>{o.effects=[structuredClone(original)];return 1;},destroy:e=>destroyed.push(e)};
 assert.equal(removeEffectsById(o,'4d',p),1);assert.equal(o.effects.length,0);assert.equal(destroyed[0],original);
 o.effects.push(original);p.onRemove=()=>0;assert.equal(removeEffectsById(o,'4d',p),0);assert.equal(o.effects[0],original);
});
test('live runtime retains a deferred record, removes its siblings and completes reversal only after its new expiry',async()=>{
 const s=new ModuleSession(null),source=s.register('creature','source',{}),o=s.register('creature','target',{}),parent=s.effects.create(55,source.id),sibling=s.effects.create(56,source.id),calls=[];
 sibling.id=parent.id;parent.durationType=sibling.durationType=2;o.effects=[parent,sibling];source.nativeCreatedAreaEffects170.append(o.id);
 const original=s.effects.onRemove.bind(s.effects);
 s.effects.onRemove=(actor,e,context)=>{
  if(e!==parent)return original(actor,e,context);
  calls.push(s.scheduler.time);
  if(!e.integers[1]){e.integers[1]=1;e.durationType=1;e.duration=0.5;const expiry=addWorldTimes(s.worldTimer.time(),{day:0,time:500},s.worldTimer.dayLength);e.expiryDay=expiry.day;e.expiryTime=expiry.time;return 0;}
  return 1;
 };
 assert.equal(s.effects.remove(o.id,parent.id),1);assert.deepEqual(o.effects,[parent]);assert.deepEqual(calls,[0]);assert.equal(source.nativeCreatedAreaEffects170.indexOf(o.id),0);
 s.scheduler.time=500;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[parent]);assert.deepEqual(calls,[0]);
 s.scheduler.time=501;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[]);assert.deepEqual(calls,[0,501]);assert.equal(source.nativeCreatedAreaEffects170.count,0);assert.equal(s.registry.get(o.id),o);
 // Expiring a linked group inside the updater must not visit its stale sibling
 // from a copied array and immediately run the parent's second callback.
 parent.integers[1]=0;parent.durationType=sibling.durationType=1;parent.expiryDay=sibling.expiryDay=0;parent.expiryTime=sibling.expiryTime=0;o.effects=[parent,sibling];calls.length=0;source.nativeCreatedAreaEffects170.append(o.id);
 s.scheduler.time=1;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[parent]);assert.deepEqual(calls,[1]);
 s.scheduler.time=501;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[parent]);assert.deepEqual(calls,[1]);
 s.scheduler.time=502;s.worldTimer.snapshot();await s.effects.updateObject(o);assert.deepEqual(o.effects,[]);assert.deepEqual(calls,[1,502]);assert.equal(source.nativeCreatedAreaEffects170.count,0);
});
