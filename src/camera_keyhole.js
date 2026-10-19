const f=Math.fround,mul=(a,b)=>f(a*b),add=(a,b)=>f(a+b);
// BoxAbovePlane22b350 chooses the corner with minimum signed distance.
export function keyholeBoxAbovePlane(min,max,plane){
 const point=min.map((v,i)=>plane[i]>0?v:max[i]);return add(add(add(mul(point[0],plane[0]),mul(point[1],plane[1])),mul(point[2],plane[2])),plane[3]);
}
// Camera::GetCanKeyholeDissolve58c50. field50 is Part::GetAurObject61af0,
// separate from the physical parent48. Strict comparisons matter at bounds.
export function canKeyholeDissolve({enabled,owner=0,min,max,plane,height}){
 return Boolean(enabled&&!owner&&height<max[2]&&keyholeBoxAbovePlane(min,max,plane)<0);
}
// RenderScene5a5d0 negates its outward near plane, then subtracts the
// camera-to-player distance minus near. Near cancels from the final plane.
export function keyholeCameraPlane(camera,forward,player){
 const delta=player.map((v,i)=>f(v-camera[i])),distance=f(Math.sqrt(add(add(mul(delta[0],delta[0]),mul(delta[1],delta[1])),mul(delta[2],delta[2]))));
 const normal=forward.map(f),dot=add(add(mul(normal[0],camera[0]),mul(normal[1],camera[1])),mul(normal[2],camera[2]));return[...normal,f(-dot-distance)];
}
