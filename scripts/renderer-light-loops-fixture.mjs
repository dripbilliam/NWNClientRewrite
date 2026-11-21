import * as T from 'three';import {compactPointLightLoops} from '../src/renderer_light_loops.js';import {installModelLightShaders} from '../src/model_light.js';
window.runLightLoopFixture=async({stress=false}={})=>{
 const width=stress?3100:1084,height=stress?1121:673;
 installModelLightShaders();const cases=[];for(const [pointCount,shadowCount]of (stress?[[128,15]]:[[0,0],[1,0],[6,2],[128,0],[128,15]])){
 const original=T.ShaderChunk.lights_fragment_begin,results=[],pictures=[];
 for(const compact of [false,true]){
  T.ShaderChunk.lights_fragment_begin=compact?compactPointLightLoops(original):original;
  const renderer=new T.WebGLRenderer({preserveDrawingBuffer:true,antialias:false});renderer.setSize(width,height);renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(42,width/height,.1,100);camera.position.set(5,6,8);camera.lookAt(0,0,0);
  const texture=new T.DataTexture(new Uint8Array([160,180,120,255]),1,1);texture.needsUpdate=true;
  const floor=new T.Mesh(new T.PlaneGeometry(20,20),new T.MeshLambertMaterial({map:texture}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;scene.add(floor,new T.AmbientLight(0x222222));
  const box=new T.Mesh(new T.BoxGeometry(2,3,2),new T.MeshLambertMaterial({map:texture,alphaTest:.035}));box.position.y=1.5;box.castShadow=box.receiveShadow=true;scene.add(box);
  for(let i=0;i<pointCount;i++){const light=new T.PointLight(i<25?0x778899:0,.4,30,1);light.position.set(Math.sin(i*.3)*8,6,Math.cos(i*.3)*8);light.castShadow=i<shadowCount;if(i>=shadowCount&&i%2){light.decay=-.02;light.distance=-30;}light.shadow.mapSize.set(32,32);scene.add(light);}
  const started=performance.now();await renderer.compileAsync(scene,camera);const compileMs=performance.now()-started;
  const drawStart=performance.now();renderer.render(scene,camera);const firstDrawMs=performance.now()-drawStart,gl=renderer.getContext(),pixels=new Uint8Array(width*height*4);gl.readPixels(0,0,width,height,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pictures.push(pixels);
  const frames=[];if(stress){renderer.shadowMap.autoUpdate=false;for(let frame=0;frame<12;frame++){await new Promise(requestAnimationFrame);const start=performance.now();renderer.render(scene,camera);gl.finish();frames.push(performance.now()-start);}}
  const debug=gl.getExtension('WEBGL_debug_renderer_info');
  results.push({compact,compileMs,firstDrawMs,finishedFramesMs:frames,gpu:debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),programs:renderer.info.programs.length,error:gl.getError()});renderer.dispose();
 }
 T.ShaderChunk.lights_fragment_begin=original;let changed=0,max=0;for(let i=0;i<pictures[0].length;i++){const d=Math.abs(pictures[0][i]-pictures[1][i]);if(d)changed++;max=Math.max(max,d);}if(max>1||changed>pictures[0].length*.00001||results.some(r=>r.error))throw Error('Compact lighting changed image '+JSON.stringify({changed,max,results}));cases.push({pointCount,shadowCount,results,changed,max});}return{cases};
};
