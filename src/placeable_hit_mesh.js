import {BufferGeometry,DoubleSide,Float32BufferAttribute,Mesh,MeshBasicMaterial} from 'three';

export function placeableUsable(object){return object?.objectType===9&&Boolean(object.replicated?.field264??object.nativeUseable264??object.usable??object.authored?.Useable);}
const hidden=node=>node.render===false||node.render===0||node.properties?.render===0||node.properties?.render==='0';
// Render=0 suppresses drawing, not the model's triangle hit geometry. Portal
// models such as plc_portal2 contain only emitters plus this hidden trimesh.
// Retain its actual geometry beneath the same animated node; no new bounds or
// collision volume are invented. Only an owned, usable placeable can pick it.
export function attachPlaceableHitMeshes(instance){
 if(instance.placeableHitMeshes)return instance.placeableHitMeshes;
 const groups=new Map();instance.root.traverse(group=>{const index=group.userData?.mdlNodeIndex;if(Number.isInteger(index))groups.set(index,group);});
 const meshes=[];
 for(const [index,node]of (instance.model?.nodes??[]).entries()){
  if(node.type!=='trimesh'||!hidden(node)||!node.verts?.length||!node.faces?.length)continue;
  const parent=groups.get(index);if(!parent)continue;const positions=[];
  for(const face of node.faces){const vertices=face.slice(0,3).map(i=>node.verts[i]);if(vertices.some(v=>!v||v.length<3||!v.slice(0,3).every(Number.isFinite)))continue;for(const [x,y,z]of vertices)positions.push(x,z,-y);}
  if(!positions.length)continue;
  const geometry=new BufferGeometry();geometry.setAttribute('position',new Float32BufferAttribute(positions,3));geometry.computeBoundingBox();geometry.computeBoundingSphere();
  const material=new MeshBasicMaterial({side:DoubleSide,visible:false,transparent:true,opacity:0,colorWrite:false,depthWrite:false}),mesh=new Mesh(geometry,material);mesh.name=node.name+' hit geometry';mesh.userData.nativeObjectHitMesh=true;mesh.userData.nativeModelMesh=true;parent.add(mesh);meshes.push(mesh);
 }
 instance.placeableHitMeshes=meshes;return meshes;
}
export function disposePlaceableHitMeshes(instance){for(const mesh of instance.placeableHitMeshes??[]){mesh.removeFromParent();mesh.geometry.dispose();mesh.material.dispose();}delete instance.placeableHitMeshes;}
