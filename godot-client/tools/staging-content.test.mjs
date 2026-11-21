import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {createContentStaging} from './staging-content.mjs';import {syncNetworkTriggerSurface} from '../../src/network_trigger_surface.js';
import tracker from './content-tracker.cjs';
test('late authoritative portal regions enter native updates, retain revisions, change and retire like models',()=>{
 const objects=new Map(),world={areaId:1,registry:{objects,get:id=>objects.get(id)}},p={objects:new Map(),area:{id:1},world,root:new T.Group(),remove(id){const old=this.objects.get(id);old?.disposeTrigger?.();old?.wrapper.removeFromParent();this.objects.delete(id);}},f={world,areaGeneration:1},staging=createContentStaging({scene:new T.Scene(),camera:new T.PerspectiveCamera(),frontend:f,presentation:()=>p}),content=new tracker.ContentTracker();
 content.reset(1,[]);assert.deepEqual(staging.snapshot().desired,[]);
 const object={id:7,objectType:7,areaId:1,replicated:{hasTransition:true,vertices:[[0,0,0],[2,0,0],[2,2,0],[0,2,0]]}};objects.set(7,object);syncNetworkTriggerSurface(p,object);
 const first=content.plan(staging.snapshot());assert.deepEqual(first.upserts.map(v=>v.id),[7]);content.commit(first);assert.deepEqual(content.plan(staging.snapshot()).upserts,[]);assert.deepEqual(content.plan(staging.snapshot()).remove,[]);
 object.replicated.vertices[1][0]=3;syncNetworkTriggerSurface(p,object);assert.equal(content.plan(staging.snapshot()).upserts.length,1);
 object.replicationRemoved=true;assert.deepEqual(content.plan(staging.snapshot()).remove,[7]);p.remove(7);
});
test('a late portal exports its real invisible polygon through the production delta path with zero model resources',async()=>{
 globalThis.FileReader??=class{readAsArrayBuffer(blob){blob.arrayBuffer().then(value=>{this.result=value;this.onloadend?.();});}};
 const scene=new T.Scene(),object={id:7,objectType:7,areaId:1,replicated:{hasTransition:true,name:{text:'Portal'},vertices:[[0,0,0],[2,0,0],[2,2,0],[0,2,0]]}},world={areaId:1,localObjectId:8,registry:{objects:new Map([[7,object]]),get:id=>id===7?object:null}},p={world,root:scene,area:{id:1},objects:new Map(),tables:{},remove(){}};
 syncNetworkTriggerSurface(p,object);const staging=createContentStaging({scene,camera:new T.PerspectiveCamera(),presentation:()=>p,frontend:{world,areaGeneration:4,resolveText:async v=>v.text}}),before=structuredClone(object),request=staging.snapshot().ready;
 const result=await staging.export(request,'late_');assert.equal(result.manifest.kind,'entity-content');assert.equal(result.manifest.entities[0].type,7);assert.equal(result.manifest.entities[0].eligible,true);assert.deepEqual(result.manifest.inventory,[{id:7,resources:[]}]);assert.equal(result.manifest.meshes[0].objectId,7);assert.equal(result.manifest.counts.meshes,1);assert.equal(result.manifest.counts.triangles,2);assert.deepEqual(object,before);assert.ok(result.glbBase64.length>100);p.objects.get(7).disposeTrigger();
});
