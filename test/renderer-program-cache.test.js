import test from 'node:test';
import assert from 'node:assert/strict';
import {MeshLambertMaterial,DataTexture,Vector3} from 'three';
import {RendererProgramCache} from '../src/renderer_program_cache.js';
function fixture(options={}){
 const properties=new WeakMap(),events=new EventTarget(),renderer={domElement:events,properties:{get:m=>properties.get(m)??{}},info:{programs:[]}},cache=new RendererProgramCache(renderer,options);
 const program=key=>{const p={cacheKey:key,program:{},isReady:()=>true,usedTimes:0};renderer.info.programs.push(p);return p;};
 const material=(programs,{texture=null}={})=>{const m=new MeshLambertMaterial({map:texture}),values=new Map(programs.map(p=>[p.cacheKey,p]));for(const p of programs)p.usedTimes++;properties.set(m,{programs:values,uniforms:{map:{value:texture}},environment:{area:'retired'}});m.addEventListener('dispose',function retire(){m.removeEventListener('dispose',retire);for(const p of values.values())if(--p.usedTimes===0){renderer.info.programs.splice(renderer.info.programs.indexOf(p),1);p.program=null;}properties.delete(m);});return m;};
 return{renderer,properties,events,cache,program,material};
}

test('program leases drop private material scene data without mutating shared textures or uniforms',()=>{
 const {cache,program,material,properties}=fixture(),p=program('a'),texture=new DataTexture(new Uint8Array([1,2,3,255]),1,1),m=material([p],{texture}),state={value:new Vector3(1,2,3)};let textureDisposals=0;texture.addEventListener('dispose',()=>textureDisposals++);
 m.userData.owner={texture};m.onBeforeCompile=()=>state;m.customProgramCacheKey=()=>texture.uuid;const sourceUniforms=properties.get(m).uniforms;sourceUniforms.tint=state;
 assert.equal(cache.adopt(m),true);assert.equal(m.map,null);assert.deepEqual(m.userData,{});assert.deepEqual(Object.keys(properties.get(m)),['programs']);assert.equal(sourceUniforms.map.value,texture);assert.equal(sourceUniforms.tint,state);assert.deepEqual(state.value.toArray(),[1,2,3]);assert.equal(p.usedTimes,1);assert.equal(textureDisposals,0);
 cache.dispose();assert.equal(p.program,null);assert.equal(textureDisposals,0);assert.equal(cache.snapshot().materials,0);assert.equal(cache.snapshot().references,0);assert.equal(cache.snapshot().bytes,0);texture.dispose();
});

test('duplicate programs reuse a lease, preserve normal refcounts and refresh eviction order',()=>{
 const f=fixture({maxPrograms:2}),a=f.program('a'),b=f.program('b'),c=f.program('c'),ma=f.material([a]),mb=f.material([b]);assert.equal(f.cache.adopt(ma),true);assert.equal(f.cache.adopt(mb),true);
 const duplicate=f.material([a]);assert.equal(f.cache.adopt(duplicate),false);duplicate.dispose();assert.equal(a.usedTimes,1);assert.equal(f.cache.snapshot().hits,1);
 assert.equal(f.cache.adopt(f.material([c])),true);assert.equal(b.program,null);assert.ok(a.program);assert.ok(c.program);assert.equal(f.cache.snapshot().references,2);f.cache.dispose();assert.equal(f.renderer.info.programs.length,0);
});

test('byte/reference limits reject oversized owners and evict whole materials with overlapping programs safely',()=>{
 const f=fixture({maxPrograms:2,maxBytes:10}),a=f.program('a'),b=f.program('b'),c=f.program('c');const ma=f.material([a]);assert.equal(f.cache.adopt(ma),true);const mab=f.material([a,b]);assert.equal(f.cache.adopt(mab),true);assert.ok(a.program);assert.ok(b.program);assert.equal(f.cache.snapshot().references,2);assert.equal(a.usedTimes,1);
 const oversized=f.material([f.program('too-long-key')]);assert.equal(f.cache.adopt(oversized),false);oversized.dispose();const mc=f.material([c]);assert.equal(f.cache.adopt(mc),true);assert.equal(a.program,null);assert.equal(b.program,null);assert.ok(c.program);f.cache.dispose();assert.equal(f.renderer.info.programs.length,0);
});

test('context loss and reset invalidate pending epochs, free leases and detach listeners on disposal',()=>{
 const f=fixture(),a=f.program('a'),old=f.cache.epoch;assert.equal(f.cache.adopt(f.material([a])),true);f.events.dispatchEvent(new Event('webglcontextlost'));assert.equal(a.program,null);assert.equal(f.cache.snapshot().materials,0);assert.notEqual(f.cache.epoch,old);
 const late=f.material([f.program('late')]);assert.equal(f.cache.adopt(late,old),false);late.dispose();assert.equal(f.cache.snapshot().materials,0);f.cache.dispose();const epoch=f.cache.epoch;f.events.dispatchEvent(new Event('webglcontextlost'));assert.equal(f.cache.epoch,epoch);
});

test('unready, stale, uncompiled or externally observed owners remain on normal disposal path',()=>{
 const f=fixture(),p=f.program('a'),m=f.material([p]);m.addEventListener('dispose',()=>{});assert.equal(f.cache.adopt(m),false);m.dispose();
 const unready=f.program('unready');unready.isReady=()=>false;const pending=f.material([unready]);assert.equal(f.cache.adopt(pending),false);pending.dispose();assert.equal(f.cache.adopt(new MeshLambertMaterial()),false);
 assert.equal(f.cache.snapshot().materials,0);f.cache.dispose();
});
