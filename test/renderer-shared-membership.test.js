import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {RendererFlatScene} from '../src/renderer_flat_scene.js';
import {RendererShadowTraversal} from '../src/renderer_shadow_traversal.js';
import {prepareRendererLights} from '../src/renderer_light_slots.js';
const mesh=()=>{const m=new T.Mesh(new T.BoxGeometry(),new T.MeshBasicMaterial());m.castShadow=true;return m;};
function membership(scene){const objects=[];let hasLOD=false;scene.traverseVisible(o=>{hasLOD ||= Boolean(o.isLOD);if(o.isLight||o.material)objects.push(o);});return{objects,hasLOD};}
function projected(scene,camera){const result=[];function visit(o,order){if(!o.visible)return;const layer=o.layers.test(camera.layers);if(o.isGroup&&layer)order=o.renderOrder;if(layer&&(o.isMesh||o.isLine||o.isPoints||o.isSprite||o.isLight))result.push([o,order]);for(const c of o.children)visit(c,order);}visit(scene,0);return result;}
test('same-pass projection preserves inherited group order, parent visibility, layers and retained subtrees',()=>{
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),a=new T.Group(),b=new T.Group(),one=mesh(),two=mesh(),branch=mesh(),leaf=mesh(),renderer={shadowMap:{render(){}},renderBufferDirect(){},xr:{enabled:false}},owner=new RendererFlatScene(renderer);scene.matrixWorldAutoUpdate=false;scene.add(a);a.add(one,b,branch);b.add(two);branch.add(leaf);a.renderOrder=4;b.renderOrder=9;
 try{for(let i=0;i<40;i++){a.visible=i%7!==0;b.layers.set(i%5?0:2);b.renderOrder=i%3;one.layers.set(i%4?0:1);if(i===10)b.add(one);if(i===20)a.add(one);const before=projected(scene,camera),parents=[one.parent,two.parent,branch.parent,leaf.parent],children=scene.children,m=membership(scene);owner.prepareMembership(m.objects,{scene,camera,hasLOD:m.hasLOD});owner.render(scene,camera,()=>assert.deepEqual(projected(scene,camera),before));assert.equal(scene.children,children);assert.deepEqual([one.parent,two.parent,branch.parent,leaf.parent],parents);assert.equal(owner.snapshot().shared,true);assert.equal(owner.preparedMembership,null);}
 }finally{owner.dispose();}
});
test('LOD, unknown callbacks and mismatched passes retain ordinary projection',()=>{
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),renderer={shadowMap:{render(){}},renderBufferDirect(){},xr:{enabled:false}},owner=new RendererFlatScene(renderer),a=mesh();scene.matrixWorldAutoUpdate=false;scene.add(a);const original=scene.children;
 for(const reason of ['lod','callback']){a.onBeforeRender=reason==='callback'?()=>{}:T.Object3D.prototype.onBeforeRender;owner.prepareMembership([a],{scene,camera,hasLOD:reason==='lod'});owner.render(scene,camera,()=>assert.equal(scene.children,original));assert.ok(owner.snapshot().fallback);}
 a.onBeforeRender=T.Object3D.prototype.onBeforeRender;owner.prepareMembership([a],{scene,camera:new T.PerspectiveCamera()});owner.render(scene,camera,()=>{});assert.notEqual(owner.snapshot().shared,true);owner.dispose();
});
test('prepared shadow entries match ordinary collection through edits and are consumed only once',()=>{
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),light=new T.PointLight(0xffffff,1,20),group=new T.Group(),near=mesh(),far=mesh(),branch=mesh(),child=mesh(),calls=[],map={enabled:true,autoUpdate:true,needsUpdate:false,type:T.PCFSoftShadowMap,render(_lights,s){calls.push([...s.children]);}},renderer={shadowMap:map},owner=new RendererShadowTraversal(renderer);scene.add(light,group);group.add(near,far,branch);branch.add(child);far.position.x=100;
 try{owner.render([light],scene,camera);for(let i=0;i<30;i++){group.visible=i%6!==0;near.layers.set(i%4?0:1);branch.visible=i%5!==0;scene.updateMatrixWorld(true);owner.reuseMembership=false;owner.render([light],scene,camera);const expected=calls.at(-1);const m=membership(scene);owner.prepareMembership(m.objects,{scene,camera,hasLOD:m.hasLOD});owner.reuseMembership=true;owner.render([light],scene,camera);assert.deepEqual(calls.at(-1),expected);assert.equal(owner.snapshot().membership,'prepared');owner.render([light],scene,camera);assert.equal(owner.snapshot().membership,'hierarchy');}
 }finally{owner.dispose();}
});
test('light slot replacements use a live group marker in its original ordering position',()=>{
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),before=new T.PointLight(),after=new T.PointLight(),group=new T.Group(),old=new T.PointLight(),replacement=new T.PointLight();old.userData.rendererLightSlot=true;replacement.userData.rendererLightSlot=true;group.add(old);scene.add(before,group,after);let handoff;
 const slots={group,update(){old.removeFromParent();group.add(replacement);return{};}},budget={update:()=>({})};prepareRendererLights(scene,camera,{shadowBudget:budget,lightSlots:slots,onMembership:(objects,info)=>{handoff={objects,info};}});
 assert.deepEqual(handoff.objects,[before,group,after]);assert.equal(handoff.info.lightSlotGroup,group);assert.equal(group.children[0],replacement);
 const renderer={shadowMap:{render(){}},renderBufferDirect(){},xr:{enabled:false}},owner=new RendererFlatScene(renderer);scene.matrixWorldAutoUpdate=false;owner.prepareMembership(handoff.objects,handoff.info);const expected=projected(scene,camera);owner.render(scene,camera,()=>assert.deepEqual(projected(scene,camera),expected));owner.dispose();
});
