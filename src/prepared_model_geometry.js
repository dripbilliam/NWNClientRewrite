import * as THREE from 'three';
import {groupFacesByMaterial} from './mdl_mesh.js';
import {cameraModelHitFaces} from './native_polygon_hit.js';

// The same geometry calculation serves cold rendering and worker preparation.
// Skinned/deformed geometry stays with its live instance.
export function buildModelGeometry(node,transformedVertices){
 if(!node.verts.length||!node.faces.length)return null;
 const saved=!node.skinned&&!transformedVertices?node.preparedGeometry:null;
 if(saved){
  const geometry=new THREE.BufferGeometry();
  for(const [name,size]of [['position',3],['uv',2],['normal',3]])geometry.setAttribute(name,new THREE.Float32BufferAttribute(saved[name],size));
  for(const group of saved.groups)geometry.addGroup(group.start,group.count,group.materialIndex);
  geometry.boundingSphere=new THREE.Sphere(new THREE.Vector3(...saved.sphere.center),saved.sphere.radius);
  geometry.userData.nativeCameraHitFaces=saved.hitFaces;
  geometry.userData.sourceVertexIndices=saved.sourceVertexIndices;
  return geometry;
 }
 const positions=[],sourceVertexIndices=[],uvs=[],geometry=new THREE.BufferGeometry(),bitmapNames=node.bitmaps?.length?node.bitmaps:[node.bitmap||''];
 for(const faceGroup of groupFacesByMaterial(node.faces,bitmapNames.length)){
  const groupStart=positions.length/3;
  for(const face of faceGroup.faces)for(let corner=0;corner<3;corner++){
   const index=face[corner],vertex=node.verts[index];sourceVertexIndices.push(index);
   if(!vertex||vertex.length<3)throw Error(`Face index outside vertex array in ${node.name}.`);
   const transformed=transformedVertices?.[index];
   if(transformed)positions.push(...transformed);else positions.push(vertex[0],vertex[2],-vertex[1]);
   const uv=node.tverts[face[4+corner]];uvs.push(uv?.[0]??0,uv?.[1]??0);
  }
  geometry.addGroup(groupStart,positions.length/3-groupStart,faceGroup.materialIndex);
 }
 if(!positions.length){geometry.dispose();return null;}
 geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
 geometry.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));
 geometry.computeVertexNormals();geometry.computeBoundingSphere();
 geometry.userData.nativeCameraHitFaces=cameraModelHitFaces(node,transformedVertices);
 geometry.userData.sourceVertexIndices=sourceVertexIndices;return geometry;
}

export function prepareModelGeometry(model){
 let meshes=0,vertices=0,bytes=0;
 for(const node of model.nodes){
  if(node.type!=='trimesh'||node.skinned||node.render===false||node.properties?.render===0||node.properties?.render==='0')continue;
  const geometry=buildModelGeometry(node);if(!geometry)continue;
  try{
   node.preparedGeometry={position:geometry.attributes.position.array,uv:geometry.attributes.uv.array,normal:geometry.attributes.normal.array,groups:geometry.groups.map(g=>({...g})),sphere:{center:geometry.boundingSphere.center.toArray(),radius:geometry.boundingSphere.radius},hitFaces:geometry.userData.nativeCameraHitFaces,sourceVertexIndices:geometry.userData.sourceVertexIndices};
   meshes++;vertices+=geometry.attributes.position.count;bytes+=Object.values(geometry.attributes).reduce((n,a)=>n+a.array.byteLength,0);
  }finally{geometry.dispose();}
 }
 return{meshes,vertices,bytes};
}
