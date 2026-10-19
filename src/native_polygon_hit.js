import {tileTriangleNormal} from './tile_surface_mesh.js';
const f=Math.fround,add=(a,b)=>f(a+b),mul=(a,b)=>f(a*b),sub=(a,b)=>f(a-b);
// NormalOf22d960 and the native cached face-plane constant. Coordinates are
// native Z-up; polygonHit's start/end dot products have different sum order.
export function nativePolygonPlane(vertices){
 const normal=tileTriangleNormal(...vertices.slice(0,3)),v=vertices[0];
 return{normal,constant:f(-add(add(mul(v[1],normal[1]),mul(v[0],normal[0])),mul(v[2],normal[2])))};
}
// polyhit231810..231a99. Inclusive edges/endpoints, front-to-back only; no
// ray normalization, barycentric epsilon or distance tolerance is introduced.
export function nativePolygonHit(vertices,normal,constant,start,end){
 const from=add(add(add(mul(normal[1],start[1]),mul(normal[0],start[0])),mul(normal[2],start[2])),constant);
 if(from<0)return null;
 const to=add(add(add(mul(normal[0],end[0]),mul(normal[1],end[1])),mul(normal[2],end[2])),constant);
 if(to>0||from===to)return null;
 const t=f(from/sub(from,to)),a=sub(1,t),point=[add(mul(a,start[0]),mul(t,end[0])),add(mul(a,start[1]),mul(t,end[1])),add(mul(t,end[2]),mul(a,start[2]))];
 for(let i=0;i<vertices.length;i++){
  const v=vertices[i],next=vertices[(i+1)%vertices.length],d=next.map((n,j)=>sub(n,v[j])),p=point.map((n,j)=>sub(n,v[j]));
  const x=sub(mul(d[1],p[2]),mul(p[1],d[2])),z=sub(mul(d[0],p[1]),mul(d[1],p[0])),y=sub(mul(p[0],d[2]),mul(d[0],p[2]));
  if(!(add(add(mul(y,normal[1]),mul(x,normal[0])),mul(z,normal[2]))>=0))return null;
 }
 return point;
}
export function cameraModelHitFaces(node,transformedVertices=null){
 // Stored MaxFace planes survive optimized draw-list replacement. ASCII nodes
 // build their planes from original vertices using native NormalOf semantics.
 return(node.nativeCollisionFaces??node.faces.map(face=>({indices:face.slice(0,3)}))).map(face=>{
  const vertices=face.indices.map(i=>transformedVertices?[transformedVertices[i][0],-transformedVertices[i][2],transformedVertices[i][1]].map(f):node.verts[i].map(f));
  return{vertices,...(!transformedVertices&&face.normal?{normal:face.normal,constant:face.constant}:nativePolygonPlane(vertices))};
 });
}
