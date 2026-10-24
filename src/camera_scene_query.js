import {Box3,Matrix3,Matrix4,Vector3} from 'three';
import {nativePolygonHit,nativePolygonPlane} from './native_polygon_hit.js';
import {cameraFaceBounds,cameraSegmentOverlaps} from './camera_query_bounds.js';
const f=Math.fround,native=v=>[f(v.x),f(-v.z),f(v.y)];
// Scene::HitCheck c9c90 mode1 checks static BSP geometry. Membership and
// local transforms remain renderer adapters; polygon crossing uses the actual
// native f32 routine and binary MaxFace planes, independent of draw triangles.
export function cameraSceneQuery(root,walkmesh=[],{broadphase=true}={}){
 const meshes=[];root.updateWorldMatrix(true,true);
 root.traverse(tile=>{if(tile.userData.nativeStaticTile)tile.traverse(mesh=>{if(mesh.isMesh&&mesh.userData.nativeModelMesh)meshes.push(mesh);});});
 const start=new Vector3(),end=new Vector3(),inverse=new Matrix4(),point=new Vector3(),normalMatrix=new Matrix3();
 const surfaces=walkmesh.filter(t=>(t.surfaceType&63)!==30).map(t=>{const vertices=t.vertices.map(v=>[f(v[0]),f(-v[2]),f(v[1])]);return{vertices,...nativePolygonPlane(vertices)};});
 const fallback=new Map(),geometryCache=new WeakMap(),meshCache=new WeakMap();let stats={queries:0,meshesRejected:0,facesRejected:0,faceTests:0};
 const hit=(face,from,to,bounds)=>{if(broadphase&&!cameraSegmentOverlaps(bounds,from,to)){stats.facesRejected++;return null;}stats.faceTests++;return nativePolygonHit(face.vertices,face.normal,face.constant,from,to);};
 const surfaceBounds=surfaces.map(cameraFaceBounds);
 function geometryInfo(geometry){
  let faces=geometry.userData.nativeCameraHitFaces??fallback.get(geometry);if(!faces){
   // These are source hit faces, not a bbox of reconstructed visible draws.
   faces=[];const position=geometry.getAttribute('position'),index=geometry.index;
   if(position)for(let i=0,n=index?.count??position.count;i+2<n;i+=3){const vertices=[0,1,2].map(j=>native(point.fromBufferAttribute(position,index?index.getX(i+j):i+j)));faces.push({vertices,...nativePolygonPlane(vertices)});}
   fallback.set(geometry,faces);
  }
  let record=geometryCache.get(geometry);if(record?.faces===faces)return record;
  const bounds=faces.map(cameraFaceBounds);let box=null;
  if(faces.length&&bounds.every(Boolean)){box=new Box3();for(const b of bounds)box.expandByPoint(new Vector3(b.min[0],b.min[2],-b.max[1])).expandByPoint(new Vector3(b.max[0],b.max[2],-b.min[1]));}
  record={faces,bounds,box};geometryCache.set(geometry,record);return record;
 }
 function meshInfo(mesh,geometry){
  let record=meshCache.get(mesh);const elements=mesh.matrixWorld.elements;
  if(record?.geometry===geometry&&elements.every((v,i)=>v===record.matrix[i]))return record;
  const box=geometry.box?.clone().applyMatrix4(mesh.matrixWorld);let bounds=null;
  if(box&&[...box.min.toArray(),...box.max.toArray()].every(Number.isFinite)){const scale=Math.max(1,...box.min.toArray().map(Math.abs),...box.max.toArray().map(Math.abs)),margin=scale*2**-18;bounds={min:[box.min.x-margin,-box.max.z-margin,box.min.y-margin],max:[box.max.x+margin,-box.min.z+margin,box.max.y+margin]};}
  record={geometry,matrix:[...elements],inverse:new Matrix4().copy(mesh.matrixWorld).invert(),bounds};meshCache.set(mesh,record);return record;
 }
 const cast=(from,to,nearest,withNormal=false)=>{
  stats.queries++;let best=null,normal=null,limit=to;
  for(let i=0;i<surfaces.length;i++){const face=surfaces[i],result=hit(face,from,limit,surfaceBounds[i]);if(result){if(!nearest)return result;best=limit=result;normal=face.normal;}}
  start.set(from[0],from[2],-from[1]);
  for(const mesh of meshes){
   const geometry=geometryInfo(mesh.geometry),state=meshInfo(mesh,geometry);
   if(broadphase&&!cameraSegmentOverlaps(state.bounds,from,limit)){stats.meshesRejected++;continue;}
   end.set(limit[0],limit[2],-limit[1]);
   inverse.copy(state.inverse);const localFrom=native(point.copy(start).applyMatrix4(inverse)),localTo=native(point.copy(end).applyMatrix4(inverse));
   let localLimit=localTo;
   for(let i=0;i<geometry.faces.length;i++){const face=geometry.faces[i],result=hit(face,localFrom,localLimit,geometry.bounds[i]);if(result){point.set(result[0],result[2],-result[1]).applyMatrix4(mesh.matrixWorld);best=limit=native(point);if(!nearest)return best;localLimit=result;if(withNormal){point.set(face.normal[0],face.normal[2],-face.normal[1]).applyNormalMatrix(normalMatrix.getNormalMatrix(mesh.matrixWorld));normal=native(point);}}}
  }
  return withNormal&&best?{position:best,normal}:best;
 };
 const query=(from,to)=>cast(from,to,false)!==null;
 query.nearest=(from,to)=>cast(from,to,true);
 query.nearestHit=(from,to)=>cast(from,to,true,true);
 query.update=()=>{stats={queries:0,meshesRejected:0,facesRejected:0,faceTests:0};root.updateWorldMatrix(true,true);};
 query.stats=()=>({...stats});
 query.invalidate=geometry=>{geometryCache.delete(geometry);fallback.delete(geometry);};
 return query;
}
