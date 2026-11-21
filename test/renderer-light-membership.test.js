import test from 'node:test';import assert from 'node:assert/strict';
import {Scene,Group,PerspectiveCamera,Mesh,BoxGeometry,MeshLambertMaterial,PointLight,DirectionalLight,SpotLight,HemisphereLight,Texture} from 'three';
import {RendererLightSlots,prepareRendererLights} from '../src/renderer_light_slots.js';
import {RendererLightSelection} from '../src/renderer_light_selection.js';
import {RendererShadowBudget} from '../src/renderer_shadow_budget.js';
function fixture(lightOnlyMembership){
 const scene=new Scene(),parent=new Group(),camera=new PerspectiveCamera(55,1,.1,200),renderer={capabilities:{maxFragmentUniforms:1024,maxTextures:16},shadowMap:{type:2}},material=new MeshLambertMaterial(),geometry=new BoxGeometry(),lights=[];
 camera.position.set(0,8,20);camera.lookAt(0,0,0);scene.add(parent);
 for(let i=0;i<400;i++){const mesh=new Mesh(geometry,material);mesh.position.x=i*.1;mesh.castShadow=true;parent.add(mesh);}
 for(let i=0;i<30;i++){const light=new PointLight();light.position.set(i%6*3-8,2,Math.floor(i/6)*3-5);light.castShadow=true;light.userData.mdlLight={radius:10,multiplier:1,color:[.4,.8,.9]};light.userData.mdlLightShadowRequested=true;lights.push(light);parent.add(light);}
 const custom=new PointLight();custom.isLight=false;parent.add(custom);lights.push(custom);parent.add(new DirectionalLight(),new SpotLight(),new HemisphereLight());
 const slots=new RendererLightSlots(renderer,()=>{}),budget=new RendererShadowBudget({renderer,nativeSelection:true,maximum:1}),selection=new RendererLightSelection();
 return{scene,parent,camera,material,lights,update:()=>prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,lightSelection:selection,focus:[0,0,0],delta:.05,lightOnlyMembership}),dispose(){slots.dispose();selection.dispose();budget.reset();geometry.dispose();material.dispose();}};
}
test('light-only inputs retain complete lighting/sampler/shadow state across live scene edits',()=>{
 const a=fixture(false),b=fixture(true);
 try{for(let frame=0;frame<35;frame++){
  for(const f of [a,b]){f.parent.visible=frame%9!==0;f.parent.position.x=Math.sin(frame)*3;f.parent.rotation.y=frame*.03;for(const [i,light]of f.lights.entries()){light.position.y=2+Math.sin(frame+i);light.castShadow=i%4===frame%4;if(light.userData.mdlLight)light.userData.mdlLight.multiplier=frame%7?.7:0;}if(frame===7)f.material.map=new Texture();if(frame===12)f.material.alphaMap=new Texture();if(frame===15)f.material.map=null;if(frame===18)f.lights[0].removeFromParent();if(frame===20)f.parent.add(f.lights[0]);}
  assert.deepEqual(b.update(),a.update(),'lighting frame '+frame);assert.deepEqual(b.lights.map(l=>[l.layers.mask,l.castShadow,l.shadow.intensity,l.color.toArray(),l.intensity]),a.lights.map(l=>[l.layers.mask,l.castShadow,l.shadow.intensity,l.color.toArray(),l.intensity]));
 }}finally{a.dispose();b.dispose();}
});
test('light-only slot and admission scans receive no ordinary material objects',()=>{
 const f=fixture(true);try{const slotsUpdate=RendererLightSlots.prototype.update;let seen=0;const owner=new RendererLightSlots({capabilities:{maxFragmentUniforms:1024}},()=>{});owner.update=function(scene,camera,options){seen++;assert.ok(options.objects.every(o=>o.isLight||o.isPointLight||o.isSpotLight||o.isDirectionalLight||o.isHemisphereLight||o.isRectAreaLight));return slotsUpdate.call(this,scene,camera,options);};prepareRendererLights(f.scene,f.camera,{lightOnlyMembership:true,shadowBudget:new RendererShadowBudget({renderer:{capabilities:{maxTextures:16}}}),lightSlots:owner});assert.equal(seen,1);owner.dispose();}finally{f.dispose();}
});
