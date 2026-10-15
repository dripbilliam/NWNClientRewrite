import {actionParameter} from './object_actions.js';
import {normalizeOrientation} from './combat_lifecycle.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native facing action provider ${n} is unavailable`);return p[n];};
// Coordinates at this boundary are native XYZ. Facing is horizontal even if
// the target stands at a different height. This is distinct from SetFacingPoint
// and the constantly updated object orientation lock.
const orient=async(actor,point,p)=>{
  const from=required(p,'position')(actor),dx=f(f(point[0])-f(from[0])),dy=f(f(point[1])-f(from[1]));
  if(f(f(f(dy*dy)+f(dx*dx))+0)>=f(.0001)){
    const direction=[dx,dy,0];
    const normalized=required(p,'normalize')(direction);
    await required(p,'orientation')(actor,normalized);
  }
  return 2;
};
// AIActionChangeFacingObject1403b0510, action19; RunActions1404ac665.
export async function faceObjectAction(actor,node,p){
  if(await required(p,'dead')(actor)===1||await required(p,'dying')(actor)===1)return 3;
  const target=required(p,'object')(actionParameter(node,0)>>>0);
  if(!target||target.objectType<=4||required(p,'area')(target)!==p.area(actor))return 3;
  const point=target.objectType===7?await required(p,'triggerPoint')(target):required(p,'position')(target);
  return orient(actor,point,p);
}
// AIActionChangeFacingPoint1403b0d70, action49; RunActions1404ac615.
export async function facePointAction(actor,node,p){
  if(await required(p,'dead')(actor)===1||await required(p,'dying')(actor)===1)return 3;
  return orient(actor,[actionParameter(node,0),actionParameter(node,1),actionParameter(node,2)],p);
}
export const normalizeNativeFacing=vector=>{
  const normalized=normalizeOrientation([vector[0],vector[2],f(-vector[1])]);return[normalized[0],f(-normalized[2]),normalized[1]];
};
// CNWSTrigger ctor1404febc2 zeroes +414/+418/+41c/+420. These are
// cached world-XY bounds, separate from the trigger object's position.
export const createTriggerFacingBounds=()=>[0,0,0,0];
// GetFacingPosition140501780. Equal bounds cause another polygon scan;
// a one-point polygon therefore is deliberately not marked as cached.
export async function triggerFacingPosition(trigger,height){
  const bounds=trigger.nativeFacingBounds;
  if(!Array.isArray(bounds)||bounds.length!==4||typeof height!=='function')
    throw new Error('Native trigger facing bounds/height provider is unavailable');
  if(bounds[0]===bounds[1]&&bounds[2]===bounds[3]){
    const vertices=trigger.geometry;
    if(!Array.isArray(vertices)||!vertices.length)throw new Error('Native trigger facing polygon has no first vertex');
    bounds[0]=bounds[1]=f(vertices[0][0]);bounds[2]=bounds[3]=f(vertices[0][1]);
    for(let i=1;i<vertices.length;i++){
      const x=f(vertices[i][0]),y=f(vertices[i][1]);
      if(bounds[0]>x)bounds[0]=x;if(bounds[2]>y)bounds[2]=y;
      if(x>bounds[1])bounds[1]=x;if(y>bounds[3])bounds[3]=y;
    }
  }
  const point=[f(f(f(bounds[1]-bounds[0])*f(.5))+bounds[0]),f(f(f(bounds[3]-bounds[2])*f(.5))+bounds[2]),0];
  point[2]=f(await height(trigger,point));return point;
}
