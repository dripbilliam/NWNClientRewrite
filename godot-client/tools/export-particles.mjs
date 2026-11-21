import * as T from 'three';
import {nativePolygonPlane} from '../../src/native_polygon_hit.js';
import {modelReferenceSceneForRoot} from '../../src/model_reference_scene.js';
const ids=new WeakMap();let serial=0;
const flag=value=>value===true||value==='true'||Number(value)!==0&&Number.isFinite(Number(value));
const ownerId=object=>{for(let p=object;p;p=p.parent){const id=p.userData.networkObjectId??p.userData.worldObjectId;if(Number.isInteger(id))return id;}return null;};
function referenceEndpoint(reference,owner,presentation,rigTransfer){
 if(!reference?.model68)return null;
 const model=reference.model68,attachment=owner.poses.attachmentFor(model),anchor=attachment?.anchor;
 let fallback=null;
 if(anchor){for(let p=anchor;p;p=p.parent){const id=p.userData.networkObjectId??p.userData.worldObjectId;if(Number.isInteger(id)&&presentation?.objects?.has(id)){fallback={objectId:id,matrix:p.matrixWorld.clone().invert().multiply(anchor.matrixWorld).toArray()};break;}}}
 return{matrix:model.root.matrixWorld.toArray(),nativeRoot:rigTransfer?.nodeBinding?.(model.root)??null,
  attachment:anchor?{binding:rigTransfer?.nodeBinding?.(anchor)??null,fallback,flags:attachment.flags}:null};
}
export function stampParticleBindings(data,content){
 const revisions=new Map(content.map(row=>[row.id,row.revision]));
 for(const row of data?.emitters??[])for(const binding of [row.nativeParent,row.nativeRoot,row.referenceTarget?.nativeRoot,row.referenceTarget?.attachment?.binding,row.referenceTarget?.attachment?.fallback])if(binding&&revisions.has(binding.objectId))binding.revision=revisions.get(binding.objectId);
}
export function prepareParticleTransfer({scene,camera,presentation,rigTransfer,objectIds=null}){
 const rows=[],meshes=new Map(),instances=new Map([...(presentation?.instances??[])].map(row=>[row.root,row]));
 scene.updateMatrixWorld(true);
 scene.traverse(mesh=>{
  const metadata=mesh.userData.mdlEmitter;if(!metadata||!mesh.isMesh||!mesh.layers.test(camera.layers)||objectIds&&!objectIds.has(ownerId(mesh)))return;
  let root=mesh.parent;while(root&&!root.userData.mdlRoot)root=root.parent;if(!root)throw Error('Particle model root is missing');
  if(!ids.has(mesh))ids.set(mesh,++serial);
  const instance=instances.get(root),source=instance?.model,animator=instance?.animator;
  const referenceOwner=modelReferenceSceneForRoot(root),reference=referenceOwner?.partForGroup(mesh.parent)?.children38.find(part=>part.node.type==='reference');
  const row={id:ids.get(mesh),objectId:ownerId(mesh),model:metadata.model,node:metadata.node,properties:structuredClone(metadata.properties),matrix:mesh.parent.matrixWorld.toArray(),rootMatrix:root.matrixWorld.toArray(),textureAvailable:Boolean(mesh.material.uniforms?.particleMap?.value),
   nativeParent:rigTransfer?.nodeBinding?.(mesh.parent)??null,nativeRoot:rigTransfer?.nodeBinding?.(root)??null,
   clips:Object.fromEntries((source?.animations??[]).map(clip=>[clip.name,{length:clip.length,events:clip.events??[],tracks:clip.tracks.filter(track=>track.node.toLowerCase()===metadata.node.toLowerCase()&&track.property.startsWith('emitter.'))}])),
   clock:{clip:animator?.clip?.name??'',time:animator?.time??0,playing:Boolean(animator?.playing),loop:animator?.loop??false,speed:animator?.nativeVisualSpeed??1},
   referenceTarget:referenceEndpoint(reference,referenceOwner,presentation,rigTransfer)};
  rows.push(row);meshes.set(mesh,row);
 });
 const collision=[];
 if(rows.some(row=>flag(row.properties.bounce)||Number(row.properties.flags)&16)){
  scene.traverse(tile=>{if(!tile.userData.nativeStaticTile)return;tile.traverse(mesh=>{
   if(!mesh.isMesh||!mesh.userData.nativeModelMesh)return;
   let faces=mesh.geometry.userData.nativeCameraHitFaces;
   if(!faces){faces=[];const positions=mesh.geometry.attributes.position,index=mesh.geometry.index,p=new T.Vector3();
    if(positions)for(let i=0,n=index?.count??positions.count;i+2<n;i+=3){const vertices=[0,1,2].map(j=>{p.fromBufferAttribute(positions,index?index.getX(i+j):i+j);return[Math.fround(p.x),Math.fround(-p.z),Math.fround(p.y)];});faces.push({vertices,...nativePolygonPlane(vertices)});}}
   collision.push({matrix:mesh.matrixWorld.toArray(),faces});
  });});
 }
 return{data:{version:1,emitters:rows,collision},binding:mesh=>meshes.get(mesh),meshes:new Map([...meshes].map(([mesh,row])=>[row.id,mesh]))};
}
