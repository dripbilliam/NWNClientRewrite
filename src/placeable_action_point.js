import {nativeAtanf} from './native_math.js';
const f=Math.fround;
const vector=(point,name)=>{
 if(!Array.isArray(point)||point.length!==3||!point.every(Number.isFinite))throw new Error(`Native placeable ${name} vector is unavailable`);
 return point.map(f);
};
const zero=point=>point.every(v=>v===0);

// CNWSPlaceable::ComputeBoundingBox1404b1bf0. Despite its name this owner
// calculates the TWO world interaction points550/55c. Zero local points leave
// previous values intact. Local Z is only a zero-vector gate: output Z starts
// with the previous world cell, then height replaces it. Slope rejection is
// one-sided, atan((objectZ-groundZ)/horizontalDistance)>native double pi/3.
export async function computePlaceableActionPoints(object,p){
 if(!await p.area(object))return;
 const mesh=await p.walkMesh(object);if(!mesh)return;
 if(!Array.isArray(mesh.actionPoints)||mesh.actionPoints.length!==2||!Array.isArray(object.nativePlaceableActionPoints550)||object.nativePlaceableActionPoints550.length!==2)
  throw new Error('Native placeable action-point storage is unavailable');
 for(let i=0;i<2;i++){
  const local=vector(mesh.actionPoints[i],'local point');if(zero(local))continue;
  const orientation=vector(p.orientation(object),'orientation'),position=vector(p.position(object),'position'),old=vector(object.nativePlaceableActionPoints550[i],'stored point');
  const point=object.nativePlaceableActionPoints550[i];
  point.splice(0,3,f(position[0]+f(f(local[0]*orientation[1])+f(local[1]*orientation[0]))),
   f(position[1]+f(f(local[1]*orientation[1])-f(local[0]*orientation[0]))),f(position[2]+old[2]));
  point[2]=f(await p.height(await p.area(object),[...point]));
  const dx=f(position[0]-point[0]),dy=f(position[1]-point[1]),squared=f(f(f(dx*dx)+f(dy*dy))+0),distance=squared===1?1:squared>0?f(Math.sqrt(squared)):0;
  const angle=nativeAtanf(f(f(position[2]-point[2])/distance));
  if(angle>1.0472)point.splice(0,3,0,0,0); // native double140df3778.
 }
}

// GetNearestActionPoint1404b3f20. First zero point returns the object position,
// even when the second exists. Second zero selects first. Equal squared
// distances select second. No walkability test or point recompute occurs here.
export function nearestPlaceableActionPoint(object,from,p){
 const points=object.nativePlaceableActionPoints550;if(!Array.isArray(points)||points.length!==2)throw new Error('Native placeable world action points are unavailable');
 const a=vector(points[0],'first point');if(zero(a))return vector(p.position(object),'position');
 const b=vector(points[1],'second point');if(zero(b))return a;
 from=vector(from,'source point');const squared=point=>{const [x,y,z]=from.map((v,i)=>f(v-point[i]));return f(f(f(y*y)+f(x*x))+f(z*z));};
 return squared(b)>squared(a)?a:b;
}
