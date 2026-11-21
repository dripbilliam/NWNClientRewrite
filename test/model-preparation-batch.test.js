import test from 'node:test';
import assert from 'node:assert/strict';
import {Scene,Group,Mesh,BoxGeometry,MeshLambertMaterial,PointLight,PerspectiveCamera} from 'three';
import {RendererModelPreparation} from '../src/renderer_model_preparation.js';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';
const tick=async predicate=>{for(let i=0;i<40&&!predicate();i++)await Promise.resolve();assert.ok(predicate());};
function fixture({deferred=false}={}){
 const calls=[],roots=new Map(),destroyed=[],events=[],renderer={shadowMap:{type:1},target:null,getRenderTarget(){return this.target;},setRenderTarget(value){this.target=value;},compileAsync(root,camera,target){const materials=[];root.traverse(o=>{if(o.material)materials.push(o.material);if(o.isLight)assert.equal(o.visible,false);});const call={root,camera,target,renderTarget:this.target,materials};calls.push(call);return deferred?new Promise((resolve,reject)=>Object.assign(call,{resolve,reject})):Promise.resolve();}};
 let profile='first';const owner=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),profile:()=>profile,createRoot:(asset,name)=>{const root=new Group(),mesh=new Mesh(new BoxGeometry(),new MeshLambertMaterial({alphaTest:.3}));mesh.name=name;mesh.castShadow=true;root.add(mesh,new PointLight());roots.set(asset,root);return root;},destroyRoot:root=>destroyed.push(root),report:(...args)=>events.push(args)});
 return{owner,renderer,calls,roots,destroyed,events,profile:value=>profile=value};
}
test('multipart batch scans one live profile and submits three combined shader jobs, retaining the same asset templates',async()=>{
 const f=fixture(),entries=Array.from({length:19},(_,i)=>({asset:{i},name:`part${i}`})),canonical=structuredClone(entries);
 assert.equal(await f.owner.prepareBatch([...entries,entries[0]]),true);assert.deepEqual(entries,canonical);assert.equal(f.owner.stats.templates,19);assert.equal(f.owner.stats.compilations,19);assert.equal(f.owner.stats.profileScans,1);assert.equal(f.owner.stats.compileCalls,3);assert.equal(f.calls.length,3);
 assert.deepEqual(f.calls.map(c=>c.materials.length),[19,19,38]);assert.equal(f.calls[0].renderTarget,null);assert.ok(f.calls[2].renderTarget);assert.equal(f.renderer.target,null);assert.equal(f.owner.scene.children.length,0);
 for(const root of f.roots.values()){assert.equal(root.parent,null);assert.equal(root.children[1].visible,true);}
 for(const entry of entries){const record=f.owner.records.get(entry.asset);assert.equal(record.root,f.roots.get(entry.asset));assert.equal(record.root.children[0].material.transparent,false);assert.equal(record.fades.children[0].material.transparent,true);assert.equal(record.root.children[0].geometry,record.fades.children[0].geometry);}
 assert.equal(await f.owner.prepareBatch(entries),true);assert.equal(f.owner.stats.profileScans,2);assert.equal(f.calls.length,3);
 f.profile('changed');assert.equal(await f.owner.prepareBatch(entries),true);assert.equal(f.calls.length,6);assert.equal(f.owner.stats.templates,19);assert.equal(f.owner.stats.compilations,38);f.owner.dispose();await tick(()=>f.destroyed.length===19);
});
test('overlapping batches and single requests serialize each material owner without deadlock or stealing polled roots',async()=>{
 const f=fixture({deferred:true}),a={asset:{},name:'a'},b={asset:{},name:'b'},c={asset:{},name:'c'},first=f.owner.prepareBatch([a,b]);await tick(()=>f.calls.length===3);
 const parentA=f.roots.get(a.asset).parent,parentB=f.roots.get(b.asset).parent;const second=f.owner.prepareBatch([b,c]),single=f.owner.prepare(a.asset,'a');await Promise.resolve();assert.equal(f.calls.length,3);assert.equal(f.roots.get(a.asset).parent,parentA);assert.equal(f.roots.get(b.asset).parent,parentB);assert.equal(f.roots.has(c.asset),false);
 for(const call of f.calls.slice(0,3))call.resolve();assert.equal(await first,true);await tick(()=>f.calls.length===6);assert.equal(await single,true);assert.equal(f.calls[3].materials.length,1);for(const call of f.calls.slice(3))call.resolve();assert.equal(await second,true);assert.equal(f.owner.stats.pending,0);assert.equal(f.owner.stats.compilations,3);f.owner.dispose();await tick(()=>f.destroyed.length===3);
});
test('release during failed batch polling retains every material until all jobs settle and restores lights/target',async()=>{
 const f=fixture({deferred:true}),entries=[{asset:{},name:'a'},{asset:{},name:'b'}],work=f.owner.prepareBatch(entries),rejected=assert.rejects(work,/batch fade failed/);await tick(()=>f.calls.length===3);
 let disposed=0;for(const call of f.calls)for(const material of call.materials)material.addEventListener('dispose',()=>disposed++);
 f.calls[1].reject(Error('batch fade failed'));for(const e of entries)f.owner.release(e.asset);await Promise.resolve();assert.equal(f.destroyed.length,0);assert.equal(disposed,0);assert.equal(f.owner.stats.pending,2);
 f.calls[0].resolve();await Promise.resolve();assert.equal(disposed,0);f.calls[2].resolve();await rejected;await tick(()=>f.destroyed.length===2);assert.equal(f.owner.stats.pending,0);assert.equal(f.owner.stats.compilations,0);assert.equal(f.owner.stats.failed,2);assert.equal(f.renderer.target,null);assert.ok([...f.roots.values()].every(root=>root.parent===null&&root.children[1].visible));f.owner.dispose();
});
test('retiring queued batches allocates nothing; retiring one running member cannot publish it ready',async()=>{
 const closed=fixture(),entries=[{asset:{},name:'a'}],queued=closed.owner.prepareBatch(entries);closed.owner.dispose();assert.equal(await queued,false);assert.equal(closed.roots.size,0);
 const f=fixture({deferred:true}),a={asset:{},name:'a'},b={asset:{},name:'b'},work=f.owner.prepareBatch([a,b]);await tick(()=>f.calls.length===3);f.owner.release(a.asset);for(const call of f.calls)call.resolve();assert.equal(await work,false);await tick(()=>f.destroyed.length===1);assert.equal(f.owner.stats.compilations,1);assert.equal(f.owner.records.has(a.asset),false);assert.equal(f.owner.records.has(b.asset),true);f.owner.dispose();await tick(()=>f.destroyed.length===2);
});
function networkFixture({failBatch=false,failSingle=null}={}){
 const loads=[],prepared=[],batches=[],instances=[],world=new NetworkWorld(),scene=new NetworkScene({world,resolver:{},loadAsset:async name=>{loads.push(name);if(name==='missing')throw Error('missing source');return{model:{name},textures:new Map()};},prepareAsset:async(asset,name)=>{prepared.push(name);if(name===failSingle)throw Error('bad shader');},prepareAssets:async entries=>{batches.push(entries);if(failBatch)throw Error('batch failed');},instantiate:(asset,name)=>{const instance={root:new Group(),asset,name,dispose(){}};instances.push(instance);return instance;},releaseAsset:()=>{},report:()=>{}});
 return{scene,loads,prepared,batches,instances};
}
test('ordered multipart assembly reuses exactly the prepared source/fallback assets with no second preparation',async()=>{
 const f=networkFixture(),requests=[{model:'primary',paletteColors:[1,2]},{model:'missing',fallbackModel:'fallback'},{model:'last'}],results=await f.scene.prepareModels(requests);
 assert.equal(f.batches.length,1);assert.deepEqual(f.batches[0].map(e=>e.name),['primary','fallback','last']);assert.equal(f.instances.length,0);
 for(let i=0;i<requests.length;i++)await f.scene.preparedModel(results[i],requests[i]);assert.deepEqual(f.instances.map(i=>i.resourceName),['primary','fallback','last']);assert.deepEqual(f.prepared,[]);assert.equal(f.loads.length,4);assert.ok(f.instances.every((instance,i)=>instance.asset===results[i].value.asset));await f.scene.dispose();
});
test('failed combined compilation isolates primary shader failure through the original per-resource fallback',async()=>{
 const f=networkFixture({failBatch:true,failSingle:'bad'}),requests=[{model:'good'},{model:'bad',fallbackModel:'fallback'},{model:'last'}],results=await f.scene.prepareModels(requests);for(let i=0;i<requests.length;i++)await f.scene.preparedModel(results[i],requests[i]);
 assert.deepEqual(f.instances.map(i=>i.resourceName),['good','fallback','last']);assert.deepEqual(f.prepared,['good','bad','last','fallback']);assert.deepEqual(f.loads.sort(),['bad','fallback','good','last']);await f.scene.dispose();
});
test('prepared assets cannot instantiate after their area closes; unresolved failures still follow ordered error handling',async()=>{
 const f=networkFixture(),request={model:'part'},results=await f.scene.prepareModels([request]);await f.scene.dispose();await assert.rejects(f.scene.preparedModel(results[0],request),/Network scene is closed/);assert.equal(f.instances.length,0);
 const g=networkFixture(),missing={model:'missing'},errors=await g.scene.prepareModels([missing]);assert.equal(errors[0].status,'rejected');await assert.rejects(g.scene.preparedModel(errors[0],missing),/missing source/);assert.equal(g.instances.length,0);await g.scene.dispose();
});
