import * as T from 'three';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
import {ModelAnimator} from '../../src/model_animation.js';
import {buildModelGeometry} from '../../src/prepared_model_geometry.js';
import {deformSkinnedVertices,updateSkinnedMesh} from '../../src/model_skinning.js';
import {prepareRigTransfer} from './export-rigs.mjs';
import {prepareGodotRoom} from './export-room.mjs';
import {visualLocalPoseServices} from '../../src/visual_scene_pose.js';

export function createRigFixture(){
 const model={modelName:'authored_rig',nodes:[
  {name:'root',parent:'NULL',parentIndex:-1,type:'dummy',position:[0,0,0],orientation:[0,0,0,1],scale:1},
  {name:'hand',parent:'root',parentIndex:0,type:'dummy',position:[1,0,0],orientation:[0,0,0,1],scale:3},
  {name:'robe',parent:'root',parentIndex:0,type:'trimesh',position:[0,0,0],orientation:[0,0,0,1],scale:2,skinned:true,verts:[[0,0,0],[1,0,0],[0,0,1]],faces:[[0,1,2,0,0,1,2,0]],tverts:[[0,0],[1,0],[0,1]],bitmap:'',skinData:{weights:[[.5,.2,0,0],[1,0,0,0],[0,0,0,0]],boneIndices:[[0,1,0,0],[0,0,0,0],[0,0,0,0]],boneConstantSlots:[1,0,0,...Array(61).fill(-1)],qboneRefInv:[[1,0,0,0],[1,0,0,0],[1,0,0,0]],tboneRefInv:[[0,0,0],[0,0,0],[0,0,0]]}}
 ],animations:[{name:'pause1',length:1,tracks:[{node:'hand',property:'position',interpolation:'linear',frames:[{time:0,value:[1,0,0]},{time:1,value:[2,0,0]}]},{node:'hand',property:'orientation',interpolation:'slerp',frames:[{time:0,value:[0,0,0,1]},{time:1,value:[0,0,Math.SQRT1_2,Math.SQRT1_2]}]}],events:[{time:.5,name:'authored_event'}]}, {name:'walk',length:1,tracks:[{node:'hand',property:'position',interpolation:'linear',frames:[{time:0,value:[1,0,0]},{time:1,value:[1,1,0]}]}],events:[]}]};
 model.animations.push({name:'curve',length:1,events:[],tracks:[{node:'hand',property:'position',interpolation:'bezier',frames:[{time:0,value:[1,0,0],in:[0,0,0],out:[.8,.3,0]},{time:.43,value:[2,1,0],in:[-.2,-.1,0],out:[.1,-.3,0]},{time:1,value:[1,0,0],in:[.6,.1,0],out:[0,0,0]}]},{node:'hand',property:'scale',interpolation:'bezier',frames:[{time:0,value:[3],in:[0],out:[.8]},{time:1,value:[3],in:[-.6],out:[0]}]}]});
 const {root,groups,nodeGroups}=createModelHierarchy(model),skinNode=model.nodes[2],skinGroup=nodeGroups.get(skinNode),skinMesh=new T.Mesh(buildModelGeometry(skinNode,deformSkinnedVertices(skinNode,model.nodes,groups,skinGroup,nodeGroups)),new T.MeshLambertMaterial({color:0xffaaaa}));
 skinMesh.userData.sourceVertexIndices=skinMesh.geometry.userData.sourceVertexIndices;skinGroup.add(skinMesh);
 const rigid=new T.Mesh(new T.BoxGeometry(.2,.3,.2),new T.MeshLambertMaterial({color:0x88aaff}));nodeGroups.get(model.nodes[1]).add(rigid);
 const animator=new ModelAnimator(model,root,()=>updateSkinnedMesh(skinMesh,deformSkinnedVertices(skinNode,model.nodes,groups,skinGroup,nodeGroups)));animator.play('pause1');
 const wrapper=new T.Group();wrapper.userData.networkObjectId=1;wrapper.add(root);
 const scene=new T.Scene();scene.add(wrapper);root.userData.mdlRoot=model.modelName;
 const heldModel={modelName:'authored_held',nodes:[{name:'held_root',parent:'NULL',parentIndex:-1,type:'dummy',position:[0,0,0],orientation:[0,0,0,1],scale:1}],animations:[]},heldParts=createModelHierarchy(heldModel),heldMesh=new T.Mesh(new T.BoxGeometry(.1,.6,.1),new T.MeshLambertMaterial({color:0x88ff88}));heldParts.groups.get('held_root').add(heldMesh);
 const heldInstance={model:heldModel,root:heldParts.root,animator:null},held={root:new T.Group(),pieces:[heldInstance],anchor:'hand',scale:2};held.root.userData.worldObjectId=1;held.root.scale.setScalar(2);held.root.add(heldParts.root);
 const poses=visualLocalPoseServices({sceneRoot:scene});poses.setParent(held,{model,root,animator},'hand',0);poses.updateAttachments();
 const object={id:1,objectType:5,areaId:2,appearance:{equipment:[]},replicated:{animation:0}},binding={wrapper,bodyType:0,models:[{model,root,animator},heldInstance],held:[held],animator};
 const presentation={objects:new Map([[1,binding]]),world:{registry:{get:id=>id===1?object:null}},tables:{}};
 return{model,root,groups,nodeGroups,animator,wrapper,presentation,skinMesh,rigid,skinNode,scene,held,heldMesh,poses};
}

export function rigFixtureOracle(){
 const f=createRigFixture(),scene=f.scene,camera=new T.PerspectiveCamera();camera.position.set(4,4,6);camera.lookAt(0,0,0);
 const transfer=prepareRigTransfer(f.presentation),prepared=prepareGodotRoom({scene,camera,buffer:[800,600],inventory:[{id:1,resources:['authored_rig']}],entities:[{id:1,type:5,name:'Authored rig',eligible:true}],rigTransfer:transfer});
 const meshes=prepared.scene.children.filter(c=>c.isMesh).map(c=>({name:c.name,position:Array.from(c.geometry.attributes.position.array),normal:Array.from(c.geometry.attributes.normal.array),uv:Array.from(c.geometry.attributes.uv?.array??[]),index:c.geometry.index?Array.from(c.geometry.index.array):null,matrix:c.matrix.toArray()}));
 const samples=[];
 for(const clip of ['pause1','walk','curve','walk'])for(const time of [0,.25,.5,.75,1]){
  f.animator.apply(f.model.animations.find(c=>c.name===clip),time);f.wrapper.updateMatrixWorld(true);f.poses.updateAttachments();
  samples.push({clip,time,skin:Array.from(f.skinMesh.geometry.attributes.position.array),rigidMatrix:f.rigid.matrixWorld.toArray(),heldMatrix:f.heldMesh.matrixWorld.toArray(),handPosition:f.nodeGroups.get(f.model.nodes[1]).position.toArray()});
 }
 const result={scope:'Authored triangle/box, original JS pose and native skin arithmetic as independent reference; no game assets',metadata:prepared.manifest,meshes,samples};prepared.dispose();return result;
}

if(process.argv[1]?.replaceAll('\\','/').endsWith('/rig-fixture.mjs')){
 const {writeFile}=await import('node:fs/promises'),file=process.argv.find(a=>a.startsWith('--output='))?.slice(9);if(!file)throw Error('Provide --output');await writeFile(file,JSON.stringify(rigFixtureOracle())+'\n',{flag:'wx'});console.log(JSON.stringify({authoredOracle:file}));
}
