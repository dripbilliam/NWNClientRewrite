import test from 'node:test';
import assert from 'node:assert/strict';
import {Scene,Group,Mesh,BoxGeometry,MeshLambertMaterial,PointLight,PerspectiveCamera,FrontSide,BackSide,VSMShadowMap,FogExp2,Texture} from 'three';
import {RendererModelPreparation} from '../src/renderer_model_preparation.js';
import {NetworkScene} from '../src/network_scene.js';
import {NetworkWorld} from '../src/network_world.js';

const template=()=>{const root=new Group(),mesh=new Mesh(new BoxGeometry(),new MeshLambertMaterial({alphaTest:.3})),light=new PointLight();mesh.castShadow=true;root.add(mesh,light);return root;};
const fakeRenderer=()=>({shadowMap:{type:1},target:null,getRenderTarget(){return this.target;},setRenderTarget(target){this.target=target;},compileAsync:async()=>{}});

test('shadow preparation matches empty-scene fog/environment keys and live light membership without changing the source scene',async()=>{
 const renderer=fakeRenderer(),scene=new Scene(),root=template(),fog=new FogExp2(0x8899aa,.01),environment=new Texture(),light=new PointLight(),owner=new RendererModelPreparation({renderer,scene,camera:new PerspectiveCamera()});scene.add(root,light);scene.fog=fog;scene.environment=environment;let shadows=0;
 renderer.compileAsync=async(source,camera,target)=>{assert.equal(scene.fog,fog);assert.equal(scene.environment,environment);if(renderer.target){shadows++;assert.equal(target,owner.shadowScene);assert.equal(target.fog,null);assert.equal(target.environment,null);const actual=[],expected=[];target.traverseVisible(object=>{if(object.isLight)actual.push(object);});scene.traverseVisible(object=>{if(object.isLight)expected.push(object);});assert.deepEqual(actual,expected);}else assert.equal(target,scene);};
 await owner.prepareArea(root);assert.equal(shadows,1);assert.equal(renderer.target,null);assert.equal(scene.fog,fog);assert.equal(scene.environment,environment);owner.dispose();
});

test('session reset during polling rejects stale cache adoption and permits a later area to retain only its own programs',async()=>{
 const renderer=fakeRenderer(),properties=new WeakMap(),jobs=[];renderer.info={programs:[]};renderer.properties={get:material=>properties.get(material)??{}};
 renderer.compileAsync=source=>{source.traverse(object=>{if(!object.material)return;const material=object.material;if(properties.has(material))return;const program={program:{},isReady:()=>true,cacheKey:material.uuid},programs=new Map([[material.uuid,program]]);renderer.info.programs.push(program);properties.set(material,{programs,uniforms:{owner:{value:source}}});material.addEventListener('dispose',function release(){material.removeEventListener('dispose',release);renderer.info.programs.splice(renderer.info.programs.indexOf(program),1);program.program=null;properties.delete(material);});});return new Promise(resolve=>jobs.push(resolve));};
 const owner=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),cachePrograms:true}),first=template(),work=owner.prepareArea(first);await Promise.resolve();const old=owner.programCache.epoch;owner.resetPrograms();assert.notEqual(owner.programCache.epoch,old);for(const done of jobs.splice(0))done();assert.equal(await work,true);owner.releaseArea(first);await Promise.resolve();await Promise.resolve();assert.equal(owner.snapshot().programCache.materials,0);assert.equal(renderer.info.programs.length,0);
 const next=template(),again=owner.prepareArea(next);await Promise.resolve();for(const done of jobs.splice(0))done();assert.equal(await again,true);owner.releaseArea(next);await Promise.resolve();await Promise.resolve();assert.ok(owner.snapshot().programCache.materials>0);owner.resetPrograms();assert.equal(owner.snapshot().programCache.materials,0);assert.equal(renderer.info.programs.length,0);owner.dispose();
});

test('shadow instancing prepares the exact projection hooks and instanced feature flag without allocating live proxies',async()=>{
 const renderer=fakeRenderer(),scene=new Scene(),root=template(),mesh=root.children[0],jobs=[];
 const owner=new RendererModelPreparation({renderer,scene,camera:new PerspectiveCamera(),shadowInstances:true});
 renderer.compileAsync=async source=>jobs.push(source);
 let disposedGeometry=0;mesh.geometry.addEventListener('dispose',()=>disposedGeometry++);
 await owner.prepareArea(root);const variants=owner.areas.get(root).shadows.children.filter(o=>o.isInstancedMesh);
 assert.equal(variants.length,2);assert.ok(variants.every(o=>o.geometry===mesh.geometry&&o.parent!==scene));
 assert.equal(renderer.target,null);assert.equal(jobs.length,3);assert.equal(scene.children.length,0);
 for(const variant of variants){
  assert.equal(variant.material.alphaTest,.3);assert.equal(variant.material.side,BackSide);
  const shader={vertexShader:'#include <project_vertex>\n#include <worldpos_vertex>'};variant.material.onBeforeCompile(shader);
  assert.match(shader.vertexShader,/attribute mat4 nwnShadowModelView/);assert.match(variant.material.customProgramCacheKey(),/^nwn-shadow-instance-projection-v2-/);
  if(variant.material.isMeshDistanceMaterial)assert.match(shader.vertexShader,/instanceMatrix \* vec4/);
 }
 let instanceDisposals=0,materialDisposals=0;for(const variant of variants){variant.addEventListener('dispose',()=>instanceDisposals++);variant.material.addEventListener('dispose',()=>materialDisposals++);}
 owner.releaseArea(root);await Promise.resolve();await Promise.resolve();assert.equal(instanceDisposals,2);assert.equal(materialDisposals,2);assert.equal(disposedGeometry,0);assert.equal(mesh.parent,root);owner.dispose();
});

test('pending instanced shadow programs retain private owners until every poll finishes after cancellation',async()=>{
 const renderer=fakeRenderer(),root=template(),jobs=[];renderer.compileAsync=()=>new Promise(resolve=>jobs.push(resolve));
 const owner=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),shadowInstances:true}),work=owner.prepareArea(root);await Promise.resolve();
 const variants=owner.areas.get(root).shadows.children.filter(o=>o.isInstancedMesh);let disposed=0;for(const variant of variants)variant.material.addEventListener('dispose',()=>disposed++);
 owner.dispose();assert.equal(disposed,0);jobs[0]();jobs[1]();await Promise.resolve();assert.equal(disposed,0);jobs[2]();assert.equal(await work,false);await Promise.resolve();await Promise.resolve();assert.equal(disposed,2);assert.equal(owner.snapshot().pending,0);assert.equal(owner.snapshot().activeAreas,0);
});

test('custom shadow producers do not acquire unsupported ordinary instance programs',()=>{
 const renderer=fakeRenderer(),root=template(),mesh=root.children[0],owner=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),shadowInstances:true});
 mesh.customDepthMaterial=mesh.material.clone();const shadows=owner.shadowRoot(root);assert.equal(shadows.children.filter(o=>o.isInstancedMesh).length,0);
 for(const object of shadows.children)object.material.dispose();mesh.customDepthMaterial.dispose();owner.dispose();
});

test('VSM fallback does not prepare unused instanced shadow programs',()=>{
 const renderer=fakeRenderer();renderer.shadowMap.type=VSMShadowMap;
 const owner=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),shadowInstances:true}),shadows=owner.shadowRoot(template());
 assert.equal(shadows.children.filter(object=>object.isInstancedMesh).length,0);assert.equal(shadows.children.length,2);
 for(const object of shadows.children)object.material.dispose();owner.dispose();
});
test('GPU templates are unbound, preserve resource data, retain program owners and prepare shadow output separately',async()=>{
 const renderer=fakeRenderer(),scene=new Scene(),camera=new PerspectiveCamera(),asset=Object.freeze({resource:'arbitrary_resource'}),calls=[];let created=0,destroyed=0,root;
 renderer.compileAsync=async(r,c,target)=>{assert.equal(c,camera);assert.equal(target,renderer.target?p.shadowScene:scene);assert.equal(r.parent,null);calls.push({root:r,target:renderer.target});if(r===root)assert.equal(r.children.find(o=>o.isLight).visible,false);};
 const p=new RendererModelPreparation({renderer,scene,camera,createRoot:()=>{created++;return root=template();},destroyRoot:()=>destroyed++});
 const [a,b]=await Promise.all([p.prepare(asset,'arbitrary'),p.prepare(asset,'arbitrary')]);
 assert.equal(a,true);assert.equal(b,true);assert.equal(created,1);assert.equal(calls.length,3);assert.equal(calls[0].target,null);assert.equal(calls[1].target,null);assert.notEqual(calls[2].target,null);assert.equal(renderer.target,null);
 assert.equal(scene.children.length,0);assert.equal(root.children.find(o=>o.isLight).visible,true);assert.equal(destroyed,0);assert.equal(p.snapshot().activeTemplates,1);
 const depth=calls[2].root.children.find(o=>o.material.isMeshDepthMaterial),distance=calls[2].root.children.find(o=>o.material.isMeshDistanceMaterial);
 assert.equal(depth.material.alphaTest,.3);assert.equal(distance.material.alphaTest,.3);assert.equal(depth.material.side,BackSide);assert.equal(root.children.find(o=>o.isMesh).material.side,FrontSide);
 assert.deepEqual(asset,{resource:'arbitrary_resource'});p.release(asset);await Promise.resolve();await Promise.resolve();assert.equal(destroyed,1);p.dispose();
});
test('area teardown during async compilation cannot destroy polled handles early or publish a ready template',async()=>{
 const renderer=fakeRenderer(),asset={},scene=new Scene(),complete=[];let destroyed=0;
 renderer.compileAsync=()=>new Promise(resolve=>{complete.push(resolve);});
 const p=new RendererModelPreparation({renderer,scene,camera:new PerspectiveCamera(),createRoot:template,destroyRoot:()=>destroyed++});
 const work=p.prepare(asset,'late');await Promise.resolve();assert.equal(p.snapshot().pending,1);p.release(asset);assert.equal(destroyed,0);assert.equal(scene.children.length,0);
 assert.equal(complete.length,3);complete[0]();await Promise.resolve();assert.equal(destroyed,0);complete[1]();complete[2]();assert.equal(await work,false);await Promise.resolve();await Promise.resolve();assert.equal(destroyed,1);assert.equal(p.snapshot().compilations,0);assert.equal(p.snapshot().pending,0);p.dispose();
});
test('failed preparation restores light state and render target, reports failure, and releases resources once',async()=>{
 const renderer=fakeRenderer(),asset={},events=[];let root,destroyed=0,count=0;
 renderer.compileAsync=async()=>{if(++count===3)throw Error('link failure');};
 const p=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),createRoot:()=>root=template(),destroyRoot:()=>destroyed++,report:(...event)=>events.push(event)});
 await assert.rejects(p.prepare(asset,'failed'),/link failure/);assert.equal(renderer.target,null);assert.equal(root.children.find(o=>o.isLight).visible,true);assert.equal(p.snapshot().failed,1);assert.equal(events[0][0],'renderer.asset-preparation-failed');
 p.release(asset);await Promise.resolve();await Promise.resolve();assert.equal(destroyed,1);p.dispose();
});
test('stale owners allocate nothing; new lighting profiles reuse one retained GPU template',async()=>{
 const renderer=fakeRenderer(),asset={};let created=0,profile='first',alive=false,calls=0;
 renderer.compileAsync=async()=>calls++;
 const p=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),profile:()=>profile,createRoot:()=>{created++;return template();},destroyRoot:()=>{}});
 assert.equal(await p.prepare(asset,'resource',{current:()=>alive}),false);assert.equal(created,0);
 alive=true;await p.prepare(asset,'resource',{current:()=>alive});profile='next';await p.prepare(asset,'resource',{current:()=>alive});assert.equal(created,1);assert.equal(calls,6);assert.equal(p.snapshot().compilations,2);p.dispose();
});
test('scene asset preparation precedes logical instantiation and late scene disposal cannot construct a model',async()=>{
 const renderer=fakeRenderer(),asset={},world=new NetworkWorld(),complete=[];let instantiated=0,destroyed=0,loads=0;
 renderer.compileAsync=()=>new Promise(resolve=>{complete.push(resolve);});
 const p=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),createRoot:template,destroyRoot:()=>destroyed++});
 const scene=new NetworkScene({world,resolver:{},report:()=>{},loadAsset:async()=>{loads++;return asset;},instantiate:()=>{instantiated++;return{};},prepareAsset:(asset,name)=>p.prepare(asset,name,{current:()=>!scene.closed}),releaseAsset:asset=>p.release(asset)});
 const model=scene.model('any_resource');const rejected=assert.rejects(model,/Network scene is closed/);
 for(let n=0;n<10&&!complete.length;n++)await Promise.resolve();assert.equal(loads,1);assert.equal(instantiated,0);assert.equal(p.snapshot().pending,1);
 await scene.dispose();assert.equal(instantiated,0);assert.equal(destroyed,0);for(const done of complete)done();await rejected;await Promise.resolve();await Promise.resolve();assert.equal(instantiated,0);assert.equal(destroyed,1);p.dispose();
});

test('color, fade and shadow jobs start together; rejection waits for the other polled materials before cleanup',async()=>{
 const renderer=fakeRenderer(),jobs=[],asset={};let original,destroyed=0;
 renderer.compileAsync=root=>new Promise((resolve,reject)=>jobs.push({root,resolve,reject}));
 const owner=new RendererModelPreparation({renderer,scene:new Scene(),camera:new PerspectiveCamera(),createRoot:()=>original=template(),destroyRoot:()=>destroyed++});
 const work=owner.prepare(asset,'parallel'),rejected=assert.rejects(work,/fade link failed/);await Promise.resolve();assert.equal(jobs.length,3);
 const source=original.children[0].material,fade=jobs[1].root.children[0].material;assert.notEqual(source,fade);assert.equal(source.transparent,false);assert.equal(fade.transparent,true);assert.equal(jobs[1].root.children[0].geometry,original.children[0].geometry);
 jobs[1].reject(Error('fade link failed'));owner.release(asset);await Promise.resolve();assert.equal(destroyed,0);assert.equal(owner.stats.pending,1);jobs[0].resolve();await Promise.resolve();assert.equal(destroyed,0);jobs[2].resolve();await rejected;await Promise.resolve();await Promise.resolve();assert.equal(destroyed,1);assert.equal(owner.stats.pending,0);owner.dispose();
});
test('whole-area variants retain only cloned materials, avoid counting attached lights twice and await every poll before retirement',async()=>{
 const renderer=fakeRenderer(),scene=new Scene(),root=template(),jobs=[];scene.add(root);let geometryDisposed=0,sourceDisposed=0;const mesh=root.children.find(n=>n.isMesh);mesh.geometry.addEventListener('dispose',()=>geometryDisposed++);mesh.material.addEventListener('dispose',()=>sourceDisposed++);
 renderer.compileAsync=(source,camera,target)=>new Promise(resolve=>jobs.push({source,target,resolve}));
 const owner=new RendererModelPreparation({renderer,scene,camera:new PerspectiveCamera(),createRoot:()=>{throw Error('Must not duplicate area geometry');},destroyRoot:()=>{throw Error('Must not destroy live area root');}}),work=owner.prepareArea(root);await Promise.resolve();assert.equal(jobs.length,3);assert.notEqual(jobs[0].source,scene);assert.notEqual(jobs[0].source.children[0].material,mesh.material);assert.equal(jobs[0].target,scene);assert.equal(jobs[1].target,scene);assert.ok(jobs.every(job=>!job.source.children.some(n=>n.isLight)));
 const clones=[...owner.areas.get(root).colors.children,...owner.areas.get(root).fades.children,...owner.areas.get(root).shadows.children].flatMap(n=>Array.isArray(n.material)?n.material:[n.material]);let disposed=0;for(const material of new Set(clones))material.addEventListener('dispose',()=>disposed++);
 owner.releaseArea(root);jobs[0].resolve();await Promise.resolve();assert.equal(disposed,0);jobs[1].resolve();jobs[2].resolve();assert.equal(await work,false);await Promise.resolve();await Promise.resolve();assert.equal(disposed,new Set(clones).size);assert.equal(geometryDisposed,0);assert.equal(sourceDisposed,0);assert.equal(root.parent,scene);assert.equal(renderer.target,null);owner.dispose();
});

test('live material replacement/disposal during area shader polling cannot invalidate retained color programs',async()=>{
 const renderer=fakeRenderer(),scene=new Scene(),root=template(),jobs=[],programs=new Map();scene.add(root);const mesh=root.children.find(o=>o.isMesh),original=mesh.material;
 renderer.compileAsync=source=>{const materials=new Set();source.traverse(o=>{for(const material of Array.isArray(o.material)?o.material:o.material?[o.material]:[]){materials.add(material);programs.set(material,{isReady:()=>true});material.addEventListener('dispose',()=>programs.delete(material));}});return new Promise((resolve,reject)=>jobs.push(()=>{try{for(const material of materials)assert.equal(programs.get(material).isReady(),true);resolve();}catch(error){reject(error);}}));};
 const owner=new RendererModelPreparation({renderer,scene,camera:new PerspectiveCamera(),destroyRoot:()=>{throw Error('Live root must remain owned by the scene');}}),work=owner.prepareArea(root);await Promise.resolve();assert.equal(jobs.length,3);
 // Production particle instances and keyhole material owners can do this
 // while the area is still waiting for async shader readiness.
 mesh.material=original.clone();original.dispose();for(const done of jobs)done();assert.equal(await work,true);assert.equal(owner.stats.failed,0);assert.equal(root.parent,scene);owner.releaseArea(root);await Promise.resolve();await Promise.resolve();owner.dispose();
});
