import {normalizeOrientation} from './combat_lifecycle.js';
import {nativeCosf,nativeSinf} from './native_math.js';
const f=Math.fround;

// ExecuteCommandGetDistanceToObject140522840: source defaults to SELF,
// target must be CNWSObject. Equal null area pointers also compare equal.
export function scriptObjectDistance(source,target,area){
  if(!source||!target||target.objectType<=4)return f(-1);
  if(area(source)!==area(target))return f(-1);
  if(![source,target].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(Number.isFinite)))throw new Error('Native distance positions are unavailable');
  const [x,z,negativeY]=target.position.map((v,i)=>f(f(v)-f(source.position[i]))),y=f(-negativeY);
  return f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z))));
}
// ExecuteCommandGetDistanceBetween140522610 accesses GObject XYZ directly,
// accepts differing areas and pushes0 when either registry lookup fails.
export function scriptDistanceBetween(first,second){
  if(!first||!second)return f(0);
  if(![first,second].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(Number.isFinite)))throw new Error('Native between-object distance position storage is unavailable');
  const x=f(f(first.position[0])-f(second.position[0])),y=f(f(-first.position[2])-f(-second.position[2])),z=f(f(first.position[1])-f(second.position[1]));
  return f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z))));
}
// ExecuteCommandGetDistanceBetweenLocations140522750 compares stored area
// IDs without resolving them. Equal INVALID IDs still compute native XYZ.
export function scriptDistanceBetweenLocations(first,second){
  if(![first,second].every(o=>o&&Number.isInteger(o.areaId)))throw new Error('Native between-location area storage is unavailable');
  if((first.areaId>>>0)!==(second.areaId>>>0))return f(-1);
  if(![first,second].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(n=>typeof n==='number')))throw new Error('Native between-location position storage is unavailable');
  const d=first.position.map((n,i)=>f(f(n)-f(second.position[i])));
  return f(Math.sqrt(f(f(f(d[0]*d[0])+f(d[1]*d[1]))+f(d[2]*d[2]))));
}
// ExecuteCommandSetFacing140541400 permits creature/item/waypoint/placeable,
// then requires commandable to equal ONE, rather than any nonzero value.
export function scriptFacingVector(actor,value,point){
  if(!actor||![5,6,9,12].includes(actor.objectType))return null;
  let orientation;
  if(point){
    if(!Array.isArray(value)||value.length!==3||!value.every(Number.isFinite)||!Array.isArray(actor.position))throw new Error('Native facing positions are unavailable');
    const native=[actor.position[0],-actor.position[2],actor.position[1]].map(f),difference=value.map((v,i)=>f(f(v)-native[i]));
    if(difference.every(v=>v===0))return null;
    orientation=normalizeOrientation([difference[0],difference[2],f(-difference[1])]);
  }else{
    const radians=f(f(value)*f(.01745329238474369));
    orientation=[nativeCosf(radians),0,f(-nativeSinf(radians))];
  }
  return actor.nativeFieldEc===1?orientation:null;
}
