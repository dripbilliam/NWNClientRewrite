import {Matrix3,Matrix4,Vector3} from 'three';
import {nativePolygonHit,nativePolygonPlane} from './native_polygon_hit.js';
const f=Math.fround,native=v=>[f(v.x),f(-v.z),f(v.y)];
// Scene::HitCheck c9c90 mode1 checks static BSP geometry. Membership and
// local transforms remain renderer adapters; polygon crossing uses the actual
// native f32 routine and binary MaxFace planes, independent of draw triangles.
export function cameraSceneQuery(root,walkmesh=[]){
 const meshes=[];root.updateWorldMatrix(true,true);
 root.traverse(tile=>{if(tile.userData.nativeStaticTile)tile.traverse(mesh=>{if(mesh.isMesh&&mesh.userData.nativeModelMesh)meshes.push(mesh);});});
 const start=new Vector3(),end=new Vector3(),inverse=new Matrix4(),point=new Vector3(),normalMatrix=new Matrix3();
 const surfaces=walkmesh.filter(t=>(t.surfaceType&63)!==30).map(t=>{const vertices=t.vertices.map(v=>[f(v[0]),f(-v[2]),f(v[1])]);return{vertices,...nativePolygonPlane(vertices)};});
 const fallback=new Map();
 const hit=(face,from,to)=>nativePolygonHit(face.vertices,face.normal,face.constant,from,to);
 const cast=(from,to,nearest,withNormal=false)=>{
  let best=null,normal=null,limit=to;
  for(const face of surfaces){const result=hit(face,from,limit);if(result){if(!nearest)return result;best=limit=result;normal=face.normal;}}
  start.set(from[0],from[2],-from[1]);
  for(const mesh of meshes){
   end.set(limit[0],limit[2],-limit[1]);
   inverse.copy(mesh.matrixWorld).invert();const localFrom=native(point.copy(start).applyMatrix4(inverse)),localTo=native(point.copy(end).applyMatrix4(inverse));
   let faces=mesh.geometry.userData.nativeCameraHitFaces??fallback.get(mesh.geometry);
   if(!faces){
    // Authored Three-only fixtures have no MDL source faces. Production meshes
    // attach original face records at buildMesh, including explicitly empty lists.
    faces=[];const position=mesh.geometry.getAttribute('position'),index=mesh.geometry.index;if(!position)continue;
    for(let i=0,n=index?.count??position.count;i+2<n;i+=3){const vertices=[0,1,2].map(j=>native(point.fromBufferAttribute(position,index?index.getX(i+j):i+j)));faces.push({vertices,...nativePolygonPlane(vertices)});}
    fallback.set(mesh.geometry,faces);
   }
   let localLimit=localTo;
   for(const face of faces){const result=hit(face,localFrom,localLimit);if(result){point.set(result[0],result[2],-result[1]).applyMatrix4(mesh.matrixWorld);best=limit=native(point);if(!nearest)return best;localLimit=result;if(withNormal){point.set(face.normal[0],face.normal[2],-face.normal[1]).applyNormalMatrix(normalMatrix.getNormalMatrix(mesh.matrixWorld));normal=native(point);}}}
  }
  return withNormal&&best?{position:best,normal}:best;
 };
 const query=(from,to)=>cast(from,to,false)!==null;
 query.nearest=(from,to)=>cast(from,to,true);
 query.nearestHit=(from,to)=>cast(from,to,true,true);
 query.update=()=>root.updateWorldMatrix(true,true);
 return query;
}
