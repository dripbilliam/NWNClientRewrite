import test from 'node:test';
import assert from 'node:assert/strict';
import {ClientCastVisualPresentation} from '../src/client_cast_visual_presentation.js';
import {ModelEventDispatcher} from '../src/model_events.js';
function fixture({deferred=false}={}){
 const canonical={animationState:15,nativeSpellId218:7},source={id:0x80000001,canonical,objectType:5,position:[1,2,3]},mirrors=new Map([[source.id,source]]),models=[],destroyed=[],plays=[],diagnostics=[];let time=0,resolve;
 const promise=deferred?new Promise(r=>resolve=r):null,model=()=>{const result={root:{removeFromParent:()=>{}},model:{animations:[{name:'conjure01'},{name:'fade'},{name:'cast01'}]},animator:{eventDispatcher:new ModelEventDispatcher({}),update:()=>{},playNative:(clip,options)=>{plays.push([clip,options]);return true;}}};models.push(result);return result;};
 const spells={conjure:['head','hand','ground'],conjureSoundMale:'male',conjureSoundFemale:'female',conjureSound:'generic'},p=new ClientCastVisualPresentation({objects:{mirrors,get:id=>mirrors.get(id)},spell:id=>id===7?spells:null,castFields:o=>[{type:'dword',value:o.nativeSpellId218},{type:'object',value:0x7f000000},{type:'bool',value:0}],now:()=>({time}),difference:(a,b)=>({time:a.time-b.time}),loadModel:async()=>{if(deferred)await promise;return model();},destroyModel:m=>destroyed.push(m),sourceModel:()=>({}),nodePose:(_m,_n,position)=>{position.splice(0,3,7,8,9);return 1;},attach:()=>true,forget:()=>{},report:(code,message)=>diagnostics.push({code,message}),oneShot:()=>{}});
 return{p,source,canonical,mirrors,models,destroyed,plays,diagnostics,setTime:t=>time=t,resolve:()=>resolve()};
}
const settle=()=>new Promise(resolve=>setImmediate(resolve));
test('conjure to projectile release fades each existing model and uses sequential native cleanup timers',async()=>{
 const f=fixture();f.p.update(0);await settle();assert.equal(f.models.length,3);assert.deepEqual(f.plays.map(p=>p[0]),['conjure01','conjure01','conjure01']);
 f.canonical.animationState=17;f.p.update(0);f.p.release(f.source,'cast-head','','cast-ground');await settle();assert.equal(f.models.length,5);assert.deepEqual(f.plays.slice(3).map(p=>p[0]),['fade','fade','fade','cast01','cast01']);
 f.canonical.animationState=1;f.setTime(5000);f.p.update(.1);assert.equal(f.p.models.size,2);assert.equal(f.destroyed.length,3);
 f.setTime(10000);f.p.update(.1);assert.equal(f.p.models.size,0);assert.equal(f.destroyed.length,5);f.p.dispose();assert.equal(f.destroyed.length,5);
});
test('authored donefade callback only marks matching conjure handle; next tick detaches and destroys it',async()=>{
 const f=fixture();f.p.update(0);await settle();const record=f.p.records.get(f.source.id),handle=record.visuals.conjure[1];handle.model.animator.eventDispatcher.dispatch('DONEFADE');assert.deepEqual(record.visuals.done,[0,1,0]);assert.equal(f.destroyed.length,0);f.p.update(0);assert.equal(record.visuals.conjure[1],null);assert.equal(f.destroyed.length,1);f.p.dispose();
});
test('late cast visual loads cannot resurrect disposed or replaced canonical source identities',async()=>{
 for(const action of ['dispose','replace']){
  const f=fixture({deferred:true});f.p.release(f.source,'cast-head','','');assert.equal(f.p.models.size,4);
  if(action==='dispose')f.p.dispose();else f.mirrors.set(f.source.id,{...f.source,canonical:{...f.canonical}});
  f.resolve();await settle();assert.equal(f.p.models.size,0);assert.equal(f.plays.length,0);assert.equal(f.destroyed.length,4);f.p.dispose();
 }
});
