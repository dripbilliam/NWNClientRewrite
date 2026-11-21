// Authored physical model/reference data only. This fixture exercises the real
// retained reference owner/attachment service and source particle presentation.
import * as T from 'three';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
import {ModelReferenceScene} from '../../src/model_reference_scene.js';
import {ModelAnimator} from '../../src/model_animation.js';
import {createModelEmitter,ModelParticlePresentation} from '../../src/model_particles.js';
import {prepareParticleTransfer,stampParticleBindings} from './export-particles.mjs';
const node=(name,parent,type='dummy',properties={})=>({name,parent,type,properties,position:[0,0,0],orientation:[0,0,0,1],scale:1});
export function createReferenceFixture({seed=17,flags=0,render='Linked'}={}){
 const properties={texture:'authored',update:'Lightning',render,blend:'Normal',birthrate:5,lifeexp:1,lightningdelay:.15,lightningradius:.03,lightningscale:.2,xsize:0,ysize:0,sizestart:.2,sizeend:.2,sizestart_y:.2,sizeend_y:.2,colorstart:[.4,.7,1],colorend:[.4,.7,1],alphastart:1,alphaend:1,xgrid:1,ygrid:1,velocity:0,p2p:1};
 const sourceModel={modelName:'authored_beam',animations:[],nodes:[node('base','NULL'),node('emitter','base','emitter',properties),node('nested','emitter'),node('nested_ref','nested','reference',{refmodel:'authored_endpoint',reattachable:1}),node('first_direct','emitter','reference',{refmodel:'authored_endpoint',reattachable:1}),node('second_direct','emitter','reference',{refmodel:'authored_endpoint',reattachable:1})]};
 const endpointModel={modelName:'authored_endpoint',animations:[],nodes:[node('endpoint','NULL')]},targetModel={modelName:'authored_target',animations:[],nodes:[node('target_root','NULL'),node('target_anchor','target_root'),node('near_anchor','target_root'),node('nested_anchor','target_root')]};
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),texture=new T.DataTexture(new Uint8Array([255,255,255,255]),1,1),diagnostics=[];
 const make=model=>{const hierarchy=createModelHierarchy(model);hierarchy.root.userData.mdlRoot=model.modelName;return{root:hierarchy.root,groups:hierarchy.groups,model,animator:new ModelAnimator(model,hierarchy.root)};};
 const source=make(sourceModel),target=make(targetModel),wrapper=new T.Group(),targetWrapper=new T.Group();wrapper.userData.networkObjectId=1;targetWrapper.userData.networkObjectId=2;wrapper.add(source.root);targetWrapper.add(target.root);scene.add(wrapper,targetWrapper);
 const emitter=createModelEmitter(sourceModel.nodes[1],new Map([['authored',texture]]),sourceModel.modelName);source.groups.get('emitter').add(emitter);
 const asset={model:sourceModel,references:new Map([['authored_endpoint',{model:endpointModel}]])};
 source.references=new ModelReferenceScene({owner:source,asset,sceneRoot:scene,createModel:child=>make(child.model),destroyModel:child=>child.root.removeFromParent()});
 const part=source.references.partForGroup(source.groups.get('emitter')),first=part.children38[1].model68,second=part.children38[2].model68,nested=part.children38[0].children38[0].model68;
 target.groups.get('target_anchor').position.set(7,1,-1);target.groups.get('near_anchor').position.set(1,0,0);target.groups.get('nested_anchor').position.set(.2,0,0);first.root.scale.setScalar(.65);
 source.references.poses.setParent(first,target,'target_anchor',flags);source.references.poses.setParent(second,target,'near_anchor',0);source.references.poses.setParent(nested,target,'nested_anchor',0);
 const presentation={instances:new Set([source,target,...source.references.models]),objects:new Map([[1,{wrapper}],[2,{wrapper:targetWrapper}]])};
 const bindings=new Map([[source.root,{objectId:1,rigNode:0,modelIndex:0}],[source.groups.get('emitter'),{objectId:1,rigNode:1,modelIndex:0}],[target.groups.get('target_anchor'),{objectId:2,rigNode:1,modelIndex:0}]]);
 const rigTransfer={nodeBinding:object=>bindings.get(object)?{...bindings.get(object)}:null};
 const particles=new ModelParticlePresentation({camera,seed,report:(code,message,data)=>diagnostics.push({code,message,data})});
 function capture(){scene.updateMatrixWorld(true);const transfer=prepareParticleTransfer({scene,camera,presentation,rigTransfer,objectIds:new Set([1])});stampParticleBindings(transfer.data,[{id:1,revision:10},{id:2,revision:20}]);return transfer.data.emitters[0];}
 function update(index,delta=.05){
  wrapper.position.set(index*.03,0,-index*.02);source.root.scale.setScalar(1.2);source.groups.get('emitter').scale.setScalar(.75);
  targetWrapper.position.set(Math.sin(index*.2),.2,Math.cos(index*.1));targetWrapper.scale.setScalar(3);targetWrapper.rotation.y=index*.07;
  target.groups.get('target_anchor').position.y=1+Math.sin(index*.1);target.groups.get('target_anchor').rotation.z=index*.03;
  source.references.update(0);camera.position.set(4,3,6);camera.lookAt(0,0,0);scene.updateMatrixWorld(true);camera.updateWorldMatrix(true,false);
  const descriptor=capture();particles.update(scene,delta);const entry=particles.entries.get(emitter);
  return {descriptor,entry,frame:{epoch:1,sequence:index,delta,camera:camera.matrixWorld.toArray(),poses:[{id:descriptor.id,matrix:descriptor.matrix,rootMatrix:descriptor.rootMatrix,referenceMatrix:descriptor.referenceTarget.matrix}]}};
 }
 return{scene,camera,source,target,first,second,nested,wrapper,targetWrapper,emitter,particles,diagnostics,capture,update,close(){particles.dispose();source.references.dispose();texture.dispose();scene.clear();}};
}
