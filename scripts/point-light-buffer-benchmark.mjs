import * as T from 'three';
import {RendererPointLightBuffer} from '../src/renderer_point_light_buffer.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
import {CameraKeyholePresentation} from '../src/camera_keyhole_shader.js';
import {TargetPreviewShader} from '../src/target_preview_shader.js';
import {RendererNumericLightCache} from '../src/renderer_numeric_light_cache.js';
const check=(value,message)=>{if(!value)throw Error(message);};
const percentile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.ceil(values.length*p)-1];
window.runPointLightBufferBenchmark=async({targetShader,keyholeShader,compact=true,numericCache=false}={})=>{
 const results=[];
 for(const enabled of [false,true]){
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(3440,1369,false);renderer.setPixelRatio(1);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(46,3440/1369,.1,250),owner=numericCache?new RendererNumericLightCache(renderer,{enabled}):new RendererPointLightBuffer(renderer,{enabled,compact}),shadows=new RendererShadowTraversal(renderer,{instances:true}),keyhole=new CameraKeyholePresentation({renderer,camera}),target=new TargetPreviewShader();keyhole.shader=keyholeShader;target.shader=targetShader;scene.userData.nativeStaticTile=true;
  const geometry=new T.BoxGeometry(.9,1.6,.9),floor=new T.Mesh(new T.PlaneGeometry(90,70),new T.MeshLambertMaterial({color:0x889988})),materials=[floor.material],lights=[];floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor,new T.AmbientLight(0xaabbcc,.5));
  for(let i=0;i<1500;i++){const material=new T.MeshLambertMaterial({color:new T.Color().setHSL(i*.137%1,.4,.45),flatShading:true}),mesh=new T.Mesh(geometry,material);mesh.position.set(i%50*1.4-34,.8,Math.floor(i/50)*1.4-20);mesh.castShadow=mesh.receiveShadow=true;mesh.userData.nativeModelMesh=true;scene.add(mesh);materials.push(material);}
  for(let i=0;i<128;i++){const light=new T.PointLight(i<32?new T.Color().setHSL(i*.173%1,.35,.7):0x000000,i<32?6:0,12,2);light.position.set(i%8*9-31,5,Math.floor(i/8)*11-18);light.castShadow=i<15;light.shadow.mapSize.set(64,64);scene.add(light);lights.push(light);}
  const sun=new T.DirectionalLight(0xffeecc,.6);sun.position.set(10,20,12);scene.add(sun);camera.position.set(40,58,70);camera.lookAt(0,0,0);keyhole.bind(scene);target.bind(scene);keyhole.update(scene,new T.Vector3(),{pitch:.7,distance:70},true);
  const gl=renderer.getContext(),extension=gl.getExtension('EXT_disjoint_timer_query_webgl2'),queries=[],times=[],counts=[],snapshots=[];let errors=0;renderer.debug.onShaderError=()=>errors++;
  const query=()=>{if(!extension)return null;const q=gl.createQuery();gl.beginQuery(extension.TIME_ELAPSED_EXT,q);return q;};
  try{
   for(let frame=0;frame<100;frame++){
    window.fixtureProgress={enabled,frame,benchmark:true};await new Promise(resolve=>setTimeout(resolve,0));
    const measured=frame>=40,q=measured?query():null,started=performance.now();owner.render(scene,camera);const duration=performance.now()-started;
    if(q){gl.endQuery(extension.TIME_ELAPSED_EXT);queries.push(q);}if(measured){times.push(duration);counts.push({...renderer.info.render});snapshots.push(owner.snapshot());}
   }
   gl.finish();const gpu=[];for(const q of queries){if(!gl.getParameter(extension.GPU_DISJOINT_EXT)&&gl.getQueryParameter(q,gl.QUERY_RESULT_AVAILABLE))gpu.push(gl.getQueryParameter(q,gl.QUERY_RESULT)/1e6);gl.deleteQuery(q);}check(gl.getError()===0,'WebGL benchmark error');check(errors===0,'Shader compilation error');
   const pixels=new Uint8Array(3440*1369*4);gl.readPixels(0,0,3440,1369,gl.RGBA,gl.UNSIGNED_BYTE,pixels);const pixelsHash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',pixels))].map(n=>n.toString(16).padStart(2,'0')).join('');
   results.push({enabled,frames:times.length,drawSubmissionMs:{median:percentile(times,.5),p95:percentile(times,.95),max:Math.max(...times)},gpuMs:gpu.length?{samples:gpu.length,median:percentile(gpu,.5),p95:percentile(gpu,.95)}:null,lastDraw:counts.at(-1),pointLighting:snapshots.at(-1),pixelsHash});
  }finally{owner.dispose();keyhole.dispose();target.dispose();shadows.dispose();geometry.dispose();floor.geometry.dispose();for(const material of materials)material.dispose();for(const light of lights)light.shadow.dispose();renderer.dispose();renderer.forceContextLoss();}
 }
 return{success:results[0].pixelsHash===results[1].pixelsHash,results,scope:'Authored static 1500-object/128-point-slot/15-shadow stress, 3440x1369, native keyhole/target includes, 40 warm frames and 60 measured unpaced draws; CPU submission and optional GPU timer queries only, NOT whole-client FPS or multiplayer acceptance'};
};
