// QA only: called from a Vite transform of the replacement application's module.
// All asset decoding, hierarchy/material building, preparation and light/shadow
// rendering use production callbacks. Placements/camera are synthetic.
import * as T from 'three';
import {parseTileset,parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {networkResourceResult} from '../src/network_resource_bridge.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {prepareRendererLights,renderPreparedScene} from '../src/renderer_light_slots.js';
import {createModelLight} from '../src/model_light.js';

export async function runCachedSingleModelFixture(api){
 const {renderer,scene,camera,loadAsset,buildObject,preparation,slots,selection,budget}=api;
 renderer.setAnimationLoop(null);scene.clear();renderer.setPixelRatio(1);renderer.setSize(960,720,false);camera.aspect=960/720;camera.updateProjectionMatrix();
 const resolver={getResource:async(name,type)=>networkResourceResult(await creationFixture.resource(name,type),name,type),getTextureResource:async name=>networkResourceResult(await creationFixture.texture(name),name,'texture')},sources=new ModelSourceCache(resolver),assets=[],roots=[],report={scope:'Offline actual production main-module network asset loading, material/hierarchy building and GL draw for cached chicken models with the repaired209x273 DDS',models:[]};
 try{
  for(const name of await creationFixture.models()){
   const asset=await loadAsset(name,resolver,null,[],sources),root=buildObject(asset.model,asset.textures,asset.override,{previews:false});assets.push(asset);roots.push(root);const selected=[...asset.textures.values()].some(t=>t.image.width===209&&t.image.height===273),animator=selected?api.animator(asset,root):null;if(selected){scene.add(root);animator?.update(.1);}report.models.push({name,selected,clip:animator?.clip?.name,textures:[...asset.textures].map(([name,t])=>({name,width:t.image.width,height:t.image.height,dataTexture:Boolean(t.isDataTexture),mips:t.mipmaps.length}))});
  }
  scene.add(api.sceneLighting);api.setAreaLighting({sunAmbientColor:[.7,.7,.7],sunDiffuseColor:[1,1,1],sunDiffuseDirection:[.3,.3,1],sunShadows:0},scene);scene.updateMatrixWorld(true);
  const bounds=new T.Box3().setFromObject(scene),center=bounds.getCenter(new T.Vector3()),size=bounds.getSize(new T.Vector3()),distance=Math.max(size.x,size.y,size.z)*2;camera.position.copy(center).add(new T.Vector3(distance,.6*distance,distance));camera.lookAt(center);camera.updateMatrixWorld(true);
  prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection,focus:center.toArray()});await preparation.prepareArea(scene);const prepared=prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection,focus:center.toArray()});renderPreparedScene(renderer,scene,camera,prepared);
  const gl=renderer.getContext(),pixels=new Uint8Array(960*720*4);gl.readPixels(0,0,960,720,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const background=[...pixels.slice(0,3)];let changedPixels=0;for(let i=0;i<pixels.length;i+=4)changedPixels+=Number(pixels[i]!==background[0]||pixels[i+1]!==background[1]||pixels[i+2]!==background[2]);
  report.glError=gl.getError();report.draw={...renderer.info.render};report.changedPixels=changedPixels;report.diagnostics=api.diagnostics();report.screenshot=renderer.domElement.toDataURL('image/png');
  if(!report.models.some(m=>m.textures.some(t=>t.width===209&&t.height===273&&t.dataTexture))||changedPixels<500||report.glError!==0)throw Error('Non-power-of-two model did not load and visibly draw');report.success=true;return report;
 }finally{preparation.releaseArea(scene);sources.dispose();for(const root of roots)api.destroyRoot(root);for(const a of assets)for(const t of a.textures.values())t.dispose();}
}

export async function runCachedDenseFixture(api,{frames=120,durationMs=0,syntheticShadows=false,particles=false,activeEffects=false}={}){
 const {renderer,scene,camera,loadAsset,buildObject,preparation,slots,selection,budget,traversal}=api;
 const check=(v,message)=>{if(!v)throw Error(message);};
 const report={scope:'Offline active cached resource context, production renderer callbacks, synthetic dense placements and orbit; no server connection or whole-game acceptance',syntheticShadows,particles,activeEffects,models:[],samples:[],notes:[]},effectAnimators=[];
 renderer.setAnimationLoop(null);scene.clear();renderer.setPixelRatio(1);renderer.setSize(3100,1121,false);scene.background=new T.Color(0x19211e);
 camera.aspect=3100/1121;camera.far=1000;camera.updateProjectionMatrix();
 const resolver={getResource:async(name,type)=>networkResourceResult(await creationFixture.resource(name,type),name,type),getTextureResource:async name=>networkResourceResult(await creationFixture.texture(name),name,'texture')},sources=new ModelSourceCache(resolver),assets=new Map(),roots=[];
 const start=performance.now(),set=parseTileset(decodeResourceText(await resolver.getResource('ttr01',2013))),tileNames=[...new Set(Object.values(set.tiles).map(t=>t.model).filter(Boolean))].slice(0,16),placeables=parse2da(decodeResourceText(await resolver.getResource('placeables',2017)));
 // Data-driven named rows include the active collection's overrides. They are
 // not a recreation of any previously visited live server area.
 const placeableNames=[...new Set(placeables.orderedRows.map(r=>r.ModelName).filter(n=>n&&n!=='****'))].slice(0,12),names=[...new Set([...tileNames,...placeableNames])];
 report.tileNames=tileNames;report.placeableNames=placeableNames;
 try{
  let cursor=0;await Promise.all(Array.from({length:4},async()=>{while(cursor<names.length){const name=names[cursor++],at=performance.now(),asset=await loadAsset(name,resolver,null,[],sources);assets.set(name,asset);report.models.push({name,ms:performance.now()-at,nodes:asset.model.nodes.length,textures:asset.textures.size,cloudUsage:asset.model.nodes.filter(n=>[n.bitmap,n.properties?.texture].some(v=>String(v).toLowerCase()==='fxpa_cloud02')).map(n=>({name:n.name,type:n.type,render:n.render,birthrate:n.properties?.birthrate}))});}}));
  report.resourcesMs=performance.now()-start;const assemble=performance.now();
  for(let i=0;i<64;i++){const name=tileNames[i%tileNames.length],a=assets.get(name),root=buildObject(a.model,a.textures,a.override,{previews:false});root.position.set((i%8)*10+5,0,-(Math.floor(i/8)*10+5));scene.add(root);roots.push(root);}
  for(let i=0;i<24;i++){const name=placeableNames[i%placeableNames.length],a=assets.get(name),root=buildObject(a.model,a.textures,a.override,{previews:false});root.position.set((i%8)*10+5,.1,-(Math.floor(i/8)*20+10));scene.add(root);roots.push(root);}
  if(activeEffects){
   // A real authored effect, already proven by the installed particle smoke.
   // Placement/count/looping are QA stress inputs, not gameplay effect logic.
   const name='vce_positive',asset=await loadAsset(name,resolver,null,[],sources);assets.set(name,asset);report.activeEffectModel=name;report.activeEffectCount=16;
   for(let i=0;i<report.activeEffectCount;i++){const root=buildObject(asset.model,asset.textures,asset.override,{previews:false});root.position.set((i%4)*15+15,0,-(Math.floor(i/4)*15+15));scene.add(root);roots.push(root);const animator=api.animator(asset,root);check(animator?.play('cessation',{loop:true}),'Authored active effect clip unavailable');animator.update(.4);effectAnimators.push(animator);}
   api.particleRuntime.update(scene,1/60);
  }
  if(syntheticShadows)for(let i=0;i<15;i++){const light=createModelLight({name:'QA-shadow-'+i,properties:{color:[.3,.25,.2],radius:24,multiplier:.35,shadow:1}},l=>l.shadow.mapSize.set(512,512));light.position.set((i%5)*15+10,6,-(Math.floor(i/5)*25+12));scene.add(light);}
  scene.add(api.sceneLighting);api.setAreaLighting({sunAmbientColor:[.7,.7,.7],sunDiffuseColor:[1,1,1],sunDiffuseDirection:[.3,.3,1],sunShadows:0},scene);
  report.assemblyMs=performance.now()-assemble;scene.updateMatrixWorld(true);
  const focus=[40,0,-40],pose=step=>{const angle=step/frames*Math.PI*2;camera.position.set(40+Math.sin(angle)*50,65,-40+Math.cos(angle)*50);camera.lookAt(...focus);camera.updateMatrixWorld(true);};
  const gl=renderer.getContext(),draw=()=>{const prepared=prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection,focus});renderPreparedScene(renderer,scene,camera,prepared);return prepared;};
  pose(0);const lighting=prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection,focus});report.initialLighting=lighting;
  const began=performance.now();await preparation.prepareArea(scene);report.preparationMs=performance.now()-began;
  draw();gl.finish();report.preparedPrograms=renderer.info.programs.length;
  const measuredAt=performance.now();report.initialHeap=performance.memory?.usedJSHeapSize;
  check(Number.isInteger(durationMs)&&durationMs>=0&&durationMs<=120000,'Invalid duration');
  for(let i=0;durationMs?performance.now()-measuredAt<durationMs:i<frames;i++){
   await new Promise(requestAnimationFrame);pose(i%frames);if(syntheticShadows)roots.at(-1).rotation.y=i*.01;
   const at=performance.now();for(const animator of effectAnimators)animator.update(1/60);if(particles)api.particleRuntime.update(scene,1/60);const particleMs=performance.now()-at,lighting=draw();gl.finish();
   const completedMs=performance.now()-at,effects=activeEffects?api.particleRuntime.snapshot().filter(e=>e.model===report.activeEffectModel):[],effectParticles=effects.reduce((sum,e)=>sum+e.active,0),effectVertices=effects.reduce((sum,e)=>sum+e.vertices,0);check(!effects.some(e=>e.failed),'Authored active effect runtime failed');
   report.samples.push({frame:i,at:performance.now()-measuredAt,completedMs,particleMs,effectParticles,effectVertices,programs:renderer.info.programs.length,draws:renderer.info.render.calls,triangles:renderer.info.render.triangles,memory:{...renderer.info.memory},lighting,shadows:traversal.snapshot()});
  }
  report.measuredMs=performance.now()-measuredAt;
  report.finalPrograms=renderer.info.programs.length;report.sourceStats={...sources.stats};report.glError=gl.getError();report.heap=performance.memory?.usedJSHeapSize;report.renderSize={width:renderer.domElement.width,height:renderer.domElement.height};
  report.diagnostics=api.diagnostics();report.particleState=particles?api.particleRuntime.snapshot():null;check(report.glError===gl.NO_ERROR,'GPU error');check(report.samples.every(s=>Number.isFinite(s.completedMs)&&s.draws>0),'Empty/non-finite measured frames');if(activeEffects)check(report.samples.some(s=>s.effectParticles>0&&s.effectVertices>0),'No authored particles were drawn');
  report.screenshot=renderer.domElement.toDataURL('image/png');report.success=true;return report;
 }finally{preparation.releaseArea(scene);if(particles)api.particleRuntime.dispose();sources.dispose();for(const root of roots)api.destroyRoot(root);for(const a of assets.values())for(const t of a.textures.values())t.dispose();}
}
