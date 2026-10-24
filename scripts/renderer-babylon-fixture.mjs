import * as T from 'three';
import {BabylonRoomAdapter} from './performance-candidates/babylon-room-adapter.mjs';
import {compareRoomPixels} from './performance-candidates/babylon-room-audit.mjs';
import {installModelLightShaders} from '../src/model_light.js';
import {createModelEmitter} from '../src/model_particles.js';

window.runBabylonFixture=async()=>{
 installModelLightShaders();const canvas=document.createElement('canvas');canvas.width=128;canvas.height=128;
 const renderer=new T.WebGLRenderer({canvas,antialias:false,alpha:false});renderer.outputColorSpace=T.LinearSRGBColorSpace;
 const scene=new T.Scene();scene.background=new T.Color(0);const camera=new T.PerspectiveCamera(60,1,.1,20);camera.position.z=3;camera.updateMatrixWorld(true);
 const geometry=new T.PlaneGeometry(2,2),texture=new T.DataTexture(Uint8Array.of(255,0,0,255,0,255,0,255,0,0,255,255,255,255,255,255),2,2);texture.colorSpace=T.SRGBColorSpace;texture.needsUpdate=true;texture.flipY=false;texture.minFilter=texture.magFilter=T.LinearFilter;
 const material=new T.MeshBasicMaterial({map:texture});let object=new T.Mesh(geometry,material);scene.add(object);
 const point=new T.PointLight(0xffffff,Math.PI,5,-.18);point.position.set(1,2,3);const ambient=new T.AmbientLight(0xffffff,.2);scene.add(point,ambient);scene.updateMatrixWorld(true);
 const lightState={point:[{position:point.position.clone().applyMatrix4(camera.matrixWorldInverse),color:point.color.clone().multiplyScalar(point.intensity),decay:point.decay,distance:point.distance}],ambient:[.2,.2,.2]};
 const testCanvas=document.createElement('canvas');testCanvas.width=128;testCanvas.height=128;
 let adapter;const cases=[];window.babylonFixtureProgress=cases;
 async function read(label){renderer.render(scene,camera);const gl=renderer.getContext(),reference=new Uint8Array(128*128*4);gl.readPixels(0,0,128,128,gl.RGBA,gl.UNSIGNED_BYTE,reference);adapter.update(camera,lightState);adapter.render();const actual=new Uint8Array(await adapter.engine.readPixels(0,0,128,128,true,true));const comparison=compareRoomPixels(reference,actual,128,128);let populated=0;for(let i=0;i<actual.length;i+=4)if(actual[i]||actual[i+1]||actual[i+2])populated++;const samples=Array.from([[40,40],[88,40],[40,88],[88,88]],([x,y])=>({xy:[x,y],reference:Array.from(reference.subarray(((127-y)*128+x)*4,((127-y)*128+x)*4+4)),actual:Array.from(actual.subarray((y*128+x)*4,(y*128+x)*4+4))}));cases.push({label,...comparison,populated,samples,determinant:adapter.rows[0].mesh._getWorldMatrixDeterminant()});if(populated<100)throw Error(label+': Babylon drew no geometry');return actual;}
 try{
  adapter=await BabylonRoomAdapter.create({canvas:testCanvas,items:[{object,geometry,material,group:null}],lightState});adapter.update(camera);await adapter.ready();await read('textured-front-face');
  object.position.x=.4;object.rotation.z=.35;object.updateMatrixWorld(true);await read('mutable-world-transform');
  object.scale.x=-1;object.updateMatrixWorld(true);await read('negative-facing');
  object.scale.x=1;object.position.x=0;object.rotation.z=0;object.updateMatrixWorld(true);geometry.attributes.position.setX(0,-.5);geometry.attributes.position.needsUpdate=true;await read('mutable-vertex-buffer');
  geometry.setDrawRange(0,3);await read('cached-draw-range-shrink');geometry.setDrawRange(0,6);await read('cached-draw-range-restore');
  texture.offset.set(.2,.15);texture.rotation=.3;await read('mutable-texture-transform');texture.offset.set(0,0);texture.rotation=0;
  adapter.dispose();object.material.polygonOffset=true;object.material.polygonOffsetFactor=-1;object.material.polygonOffsetUnits=-1;adapter=await BabylonRoomAdapter.create({canvas:testCanvas,items:[{object,geometry,material:object.material,group:null}],lightState});adapter.update(camera);await adapter.ready();await read('nwn-polygon-offset');
  adapter.dispose();object.material=new T.MeshLambertMaterial({map:texture});adapter=await BabylonRoomAdapter.create({canvas:testCanvas,items:[{object,geometry,material:object.material,group:null}],lightState});adapter.update(camera);await adapter.ready();await read('native-point-ambient-lambert');
  point.distance=-5;lightState.point[0].distance=-5;await read('native-ambient-only-point');
  point.position.set(-2,-1,2);scene.updateMatrixWorld(true);lightState.point[0].position.copy(point.position).applyMatrix4(camera.matrixWorldInverse);point.color.setRGB(.3,.7,.2);lightState.point[0].color.copy(point.color).multiplyScalar(point.intensity);await read('mutable-point-uniforms');
  adapter.dispose();texture.flipY=true;texture.needsUpdate=true;adapter=await BabylonRoomAdapter.create({canvas:testCanvas,items:[{object,geometry,material:object.material,group:null}],lightState});adapter.update(camera);await adapter.ready();await read('flipped-texture-upload');
  adapter.dispose();scene.remove(object);object.material.dispose();object=createModelEmitter({name:'authored-particle',properties:{texture:'authored'}},new Map([['authored',texture]]),'fixture');object.geometry=geometry;object.visible=true;object.position.set(7,5,2);object.updateMatrixWorld(true);scene.add(object);
  geometry.setAttribute('particleColor',new T.Float32BufferAttribute([1,.5,.2,.3,.2,1,.5,.6,.5,.2,1,.7,1,.5,1,.4],4));
  texture.offset.set(.4,.2);texture.rotation=.25;object.material.opacity=.12;
  for(const [label,dst]of [['particle-alpha',T.OneMinusSrcAlphaFactor],['particle-additive',T.OneFactor]]){object.material.blending=T.CustomBlending;object.material.blendSrc=T.SrcAlphaFactor;object.material.blendDst=dst;object.material.blendEquation=T.AddEquation;object.material.depthWrite=dst===T.OneFactor;adapter=await BabylonRoomAdapter.create({canvas:testCanvas,items:[{object,geometry,material:object.material,group:null}],lightState});adapter.update(camera);await adapter.ready();await read(label);adapter.dispose();}
  // Reopen one last frame for the report screenshot and resource snapshot.
  adapter=await BabylonRoomAdapter.create({canvas:testCanvas,items:[{object,geometry,material:object.material,group:null}],lightState});adapter.update(camera);await adapter.ready();const actual=await read('particle-world-space-transform');
  const preview=document.createElement('canvas');preview.width=128;preview.height=128;const context=preview.getContext('2d'),image=context.createImageData(128,128);image.data.set(actual);context.putImageData(image,0,0);
  return{executed:true,passed:cases.every(c=>c.exact),fullGameParity:false,engine:adapter.snapshot(),cases,screenshot:preview.toDataURL('image/png')};
 }finally{adapter?.dispose();renderer.dispose();geometry.dispose();material.dispose();texture.dispose();object.material.dispose();}
};
