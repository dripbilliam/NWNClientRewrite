import * as T from 'three';import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';import {installModelLightShaders} from '../src/model_light.js';import {installCompactLightLoops} from '../src/renderer_light_loops.js';
window.runShadowCacheFixture=async({shortCircuitVolatile=false}={})=>{
 installModelLightShaders();installCompactLightLoops();
 const renderer=new T.WebGLRenderer({preserveDrawingBuffer:true,antialias:false});renderer.setSize(1084,673);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
 const errors=[];renderer.debug.onShaderError=()=>errors.push('shader error');const scene=new T.Scene(),camera=new T.PerspectiveCamera(50,1084/673,.1,200);camera.position.set(10,28,48);camera.lookAt(0,0,0);scene.background=new T.Color('#17232a');scene.add(new T.AmbientLight(0x333333));
 const floor=new T.Mesh(new T.PlaneGeometry(90,50),new T.MeshLambertMaterial({color:0x889977}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor);
 const geometry=new T.BoxGeometry(1,2,1),material=new T.MeshLambertMaterial({color:0xccccaa});for(const x of [-24,0,24])for(let i=0;i<16;i++){const mesh=new T.Mesh(geometry,material);mesh.position.set(x+(i%4)*2-3,1,Math.floor(i/4)*2-3);mesh.castShadow=mesh.receiveShadow=true;scene.add(mesh);}
 const texture=new T.DataTexture(new Uint8Array(16).fill(255),2,2);texture.needsUpdate=true;const moving=new T.Mesh(new T.BoxGeometry(3,3,3),new T.MeshLambertMaterial({map:texture,alphaTest:.5}));moving.position.set(0,1.5,4);moving.castShadow=moving.receiveShadow=true;scene.add(moving);
 const lights=[];for(const x of [-24,0,24])for(const z of [-7,7]){const light=new T.PointLight(0xffeedd,5,14,1);light.position.set(x,8,z);light.castShadow=true;light.shadow.mapSize.set(64,64);scene.add(light);lights.push(light);}
 const adapter=new RendererShadowTraversal(renderer),maps={reference:lights.map(()=>null),optimized:lights.map(()=>null)},results=[];adapter.cache.shortCircuitVolatile=shortCircuitVolatile;
 const pixels=()=>{const gl=renderer.getContext(),p=new Uint8Array(1084*673*4);gl.readPixels(0,0,1084,673,gl.RGBA,gl.UNSIGNED_BYTE,p);return p;};
 const shadowPixels=()=>lights.map(light=>{const map=light.shadow.map,p=new Uint8Array(map.width*map.height*4);renderer.readRenderTargetPixels(map,0,0,map.width,map.height,p);return p;});
 function draw(mode){renderer.shadowMap.render=mode==='reference'?adapter.original:adapter.wrapper;lights.forEach((l,i)=>l.shadow.map=maps[mode][i]);renderer.render(scene,camera);maps[mode]=lights.map(l=>l.shadow.map);return{pixels:pixels(),shadows:shadowPixels(),stats:mode==='optimized'?adapter.snapshot():null};}
 function diff(a,b){let count=0,max=0;for(let i=0;i<a.length;i++){const d=Math.abs(a[i]-b[i]);if(d)count++;max=Math.max(max,d);}return{count,max};}
 function check(name){const a=draw('reference'),b=draw('optimized'),image=diff(a.pixels,b.pixels),shadows=a.shadows.map((p,i)=>diff(p,b.shadows[i]));if(image.count||shadows.some(s=>s.count))throw Error(name+' output mismatch '+JSON.stringify({image,shadows}));results.push({name,image,shadows,stats:b.stats});return b.stats;}
 check('initial');check('seed');if(check('unchanged').reusedLights!==6)throw Error('Static maps were not reused');
 moving.position.x=2;check('move');moving.visible=false;check('hide');moving.visible=true;check('show');
 texture.image.data[3]=0;texture.needsUpdate=true;check('texture alpha');moving.geometry.attributes.position.setX(0,4);moving.geometry.attributes.position.needsUpdate=true;moving.geometry.computeBoundingSphere();check('geometry');
 lights[2].position.x=2;check('light pose');lights[2].color.set(0x5566dd);if(check('light color').renderedLights!==0)throw Error('Color-only change redrew shadow maps');
 scene.remove(moving);check('remove');scene.add(moving);check('add');const parent=new T.Group();parent.position.x=24;scene.add(parent);parent.add(moving);check('reparent');
 maps.optimized[0].dispose();check('target disposal');
 moving.onBeforeShadow=()=>{};if(!check('volatile hook').renderedLights)throw Error('Volatile caster did not redraw');moving.position.z+=1;check('volatile move');texture.image.data[7]=0;texture.needsUpdate=true;check('volatile alpha');
 moving.onBeforeShadow=T.Object3D.prototype.onBeforeShadow;check('volatile removal baseline');if(check('volatile removal reuse').reusedLights!==6)throw Error('Cache did not recover after volatile removal');
 if(errors.length)throw Error(errors.join(','));const gl=renderer.getContext();if(gl.getError()!==gl.NO_ERROR)throw Error('WebGL error');
 const screenshot=renderer.domElement.toDataURL('image/png');adapter.dispose();for(const mode of Object.values(maps))for(const map of mode)map?.dispose();scene.traverse(node=>{node.geometry?.dispose();if(node.material)for(const m of Array.isArray(node.material)?node.material:[node.material])m.dispose();});texture.dispose();renderer.dispose();return{passed:true,shortCircuitVolatile,results,screenshot};
};
