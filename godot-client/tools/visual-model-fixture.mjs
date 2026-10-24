// Authored boxes/triangle and existing original hierarchy/animation arithmetic.
// No installed game assets are serialized by this oracle.
import * as T from 'three';
import {createRigFixture} from './rig-fixture.mjs';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
import {ModelAnimator} from '../../src/model_animation.js';
import {ModelReferenceScene} from '../../src/model_reference_scene.js';
import {prepareVisualModelTransfer} from './export-visual-model.mjs';
import {prepareGodotRoom} from './export-room.mjs';

export function createVisualModelFixture({flags=0}={}){
 const f=createRigFixture(),scene=new T.Scene(),camera=new T.PerspectiveCamera(),model=f.presentation.objects.get(1).models[0];scene.add(model.root);
 const ref={name:'endpoint_ref',parent:'hand',parentIndex:1,type:'reference',position:[0,0,0],orientation:[0,0,0,1],scale:1,properties:{refmodel:'authored_child',reattachable:1}};
 model.model.nodes.push(ref);const group=new T.Group();group.name=ref.name;group.userData={mdlNode:ref.name,mdlNodeIndex:3,mdlModel:model.model.modelName};f.groups.get('hand').add(group);
 const childModel={modelName:'authored_child',nodes:[{name:'child_base',parent:'NULL',type:'dummy',position:[0,0,0],orientation:[0,0,0,1],scale:1}],animations:[]};
 const asset={model:model.model,references:new Map([['authored_child',{model:childModel}]])};
 model.references=new ModelReferenceScene({owner:model,asset,sceneRoot:scene,createModel:value=>{
  const hierarchy=createModelHierarchy(value.model),mesh=new T.Mesh(new T.BoxGeometry(.1,.6,.1),new T.MeshLambertMaterial({color:0x88ff88}));hierarchy.groups.get('child_base').add(mesh);hierarchy.root.userData.mdlRoot=value.model.modelName;
  return{model:value.model,root:hierarchy.root,animator:new ModelAnimator(value.model,hierarchy.root)};
 },destroyModel:child=>child.root.removeFromParent()});
 const child=model.references.models[0];child.root.scale.setScalar(2);model.references.poses.setParent(child,model,'endpoint_ref',flags);
 camera.position.set(4,3,6);camera.lookAt(0,0,0);scene.updateMatrixWorld(true);
 return{...f,scene,camera,model,child,group,close(){model.references.dispose();scene.clear();}};
}

export function visualModelOracle(){
 const f=createVisualModelFixture(),transfer=prepareVisualModelTransfer(f),prepared=prepareGodotRoom({...f,inventory:[],entities:[],includeCamera:false,rigTransfer:transfer.rigs,particleTransfer:transfer.particles});
 prepared.manifest.kind='visual-model';prepared.manifest.modelResources=transfer.models.map(model=>model.model.modelName);
 const meshes=prepared.scene.children.filter(c=>c.isMesh).map(c=>({name:c.name,position:Array.from(c.geometry.attributes.position.array),normal:Array.from(c.geometry.attributes.normal.array),uv:Array.from(c.geometry.attributes.uv?.array??[]),index:c.geometry.index?Array.from(c.geometry.index.array):null,matrix:c.matrix.toArray()}));
 const samples=[];
 for(const flags of [0,3]){
  f.model.references.poses.setParent(f.child,f.model,'endpoint_ref',flags);f.child.root.quaternion.identity();
  for(const time of [0,.25,.5,.75,1]){
   f.animator.apply(f.model.model.animations[0],time);f.scene.updateMatrixWorld(true);f.model.references.update(0);
   samples.push({flags,time,skin:Array.from(f.skinMesh.geometry.attributes.position.array),rigidMatrix:f.rigid.matrixWorld.toArray(),referenceMatrix:f.child.root.matrixWorld.toArray()});
  }
 }
 const result={scope:'Authored visual-only rig/skin/reference oracle; not actual server effect lifecycle',metadata:prepared.manifest,meshes,samples};prepared.dispose();f.close();return result;
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/visual-model-fixture.mjs')){
 const {writeFile}=await import('node:fs/promises'),output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output)throw Error('Provide --output');await writeFile(output,JSON.stringify(visualModelOracle())+'\n',{flag:'wx'});console.log(JSON.stringify({authoredOracle:output}));
}
