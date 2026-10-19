import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
import {normalizeNativeVector} from './native_vector.js';
import {nativeCosf,nativeSinf} from './native_math.js';
const f=Math.fround,call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native move-away provider ${n} is unavailable`);return p[n](...a);};
const bits=value=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,value,true);return d.getInt32(0,true);};
const squared=(a,b)=>{const x=f(a[0]-b[0]),y=f(a[1]-b[1]),z=f(a[2]-b[2]);return f(f(f(x*x)+f(y*y))+f(z*z));};
// CNWSArea::ComputeAwayVector140369a40. Native XYZ, eight45-degree candidates,
// directional weights and bounded distance-halving. Null path returns origin.
export async function computeAwayVector(area,origin,threat,distance,path,p){
 origin=origin.map(f);threat=threat.map(f);distance=f(distance);
 const direction=normalizeNativeVector([f(threat[0]-origin[0]),f(threat[1]-origin[1]),0]),zero=f(distance*0),z=f(zero+origin[2]);let best=0,result=origin.slice();
 for(let i=0;i<8;i++){
  const angle=f(f(i)*f(Math.PI/4)),cos=nativeCosf(angle),sin=nativeSinf(angle),dx=f(f(f(sin*direction[1])+f(cos*direction[0]))*distance),dy=f(f(f(cos*direction[1])-f(sin*direction[0]))*distance);
  let point=[f(dx+origin[0]),f(dy+origin[1]),z];
  if(squared(threat,point)<f(distance*distance))point=[f(point[0]+dx),f(point[1]+dy),f(z+zero)];
  if(!path)continue;
  area.nativePathInfo280=path;
  if(await call(p,'directLine',area,origin,point,path.field4,path.fieldC,1)!==1){
   let fraction=f(1),found=false;
   do{if(found)break;point=[f(f(fraction*dx)+origin[0]),f(f(fraction*dy)+origin[1]),f(f(zero*fraction)+origin[2])];const status=await call(p,'directLine',area,origin,point,path.field4,path.fieldC,1);fraction=f(fraction*f(.5));if(status===1)found=true;}while(f(.005)<=fraction);
   if(!found||squared(threat,point)<squared(threat,origin))continue;
  }
  const magnitude=f(Math.sqrt(squared(point,threat))),weight=i===4?256:[3,5].includes(i)?64:[2,6].includes(i)?16:[1,7].includes(i)?4:1,score=f(magnitude*weight);
  if(best<=score){result=point.slice();best=score;}
 }
 return result;
}
// ExecuteCommandMoveAwayFromObject5363d0: Ec !=0, existing target, action3
// reuses last groupFFFE. It does not compute a destination in this wrapper.
export function scriptMoveAwayObject(actor,target,run=0,distance=40){
 if(actor?.objectType!==5||actor.nativeFieldEc===0||!target)return;
 return addObjectAction(actor.objectActionState,3,65534,[{type:3,value:target.id},{type:1,value:run|0},{type:2,value:bits(distance)},{type:1,value:10}]);
}
// ExecuteCommandActionMoveAwayFromLocation50e400: exact Ec1 and same area;
// inclusive radius check, then ordinary move plus location recheck44.
export async function scriptMoveAwayLocation(actor,location,run=0,distance=40,p){
 if(actor?.objectType!==5||actor.nativeFieldEc!==1||!location)return;
 const origin=call(p,'position',actor),threat=location.position.map(f),area=call(p,'areaById',location.areaId);
 if(!area||area!==call(p,'area',actor)||!(squared(origin,threat)<=f(f(distance)*f(distance))))return;
 const point=await call(p,'away',area,origin,threat,f(distance),actor.nativePathInfo);
 await call(p,'moveBack',actor,65535,point,location.areaId,OBJECT_INVALID,run|0,0,0,0,0,0,0,1,0);
 return addObjectAction(actor.objectActionState,44,65534,[...threat.map(value=>({type:2,value:bits(value)})),{type:1,value:run|0},{type:2,value:bits(distance)},{type:1,value:10}]);
}
// AIActionCheckMoveAwayFromObject3b3180 and ...Location3b27f0. Both return2
// even when already outside range. Missing/dead/dying/exhausted checks abort3.
export async function executeMoveAway(actor,node,p){
 if(call(p,'dead',actor)===1||call(p,'dying',actor)===1)return 3;
 let area,threat,run,distance,retries,target;
 if(node.actionId===3){
  target=actionParameter(node,0);run=actionParameter(node,1)|0;distance=actionParameter(node,2);retries=actionParameter(node,3)|0;if(retries<=0)return 3;
  const object=call(p,'object',target);if(!object)return 3;threat=call(p,'position',object);area=call(p,'area',object);
  for(;;){const duplicate=[...actor.objectActionState.list].find(n=>n.actionId===3&&(n.parameterData[0]>>>0)===target);if(!duplicate)break;await call(p,'cancel',actor,0,duplicate.groupId);
   if([...actor.objectActionState.list].includes(duplicate))throw new Error('Native move-away cancellation did not remove the matching action');
  }
  if(!area||area!==call(p,'area',actor))return 2;
 }else{
  area=call(p,'area',actor);threat=[0,1,2].map(i=>actionParameter(node,i));run=actionParameter(node,3)|0;distance=actionParameter(node,4);retries=actionParameter(node,5)|0;if(retries<=0)return 3;
 }
 const origin=call(p,'position',actor),limit=f(f(distance)-f(.01));if(!(squared(origin,threat)<f(limit*limit)))return 2;
 const point=await call(p,'away',area,origin,threat,distance,actor.nativePathInfo);retries--;
 if(retries>0){const values=node.actionId===3?[{type:3,value:target},{type:1,value:run},{type:2,value:bits(distance)},{type:1,value:retries}]:[...threat.map(value=>({type:2,value:bits(value)})),{type:1,value:run},{type:2,value:bits(distance)},{type:1,value:retries}];addObjectAction(actor.objectActionState,node.actionId,node.groupId,values,true);}
 await call(p,'moveFront',actor,node.groupId,point,area.id,OBJECT_INVALID,run,0,0,0,0,0,0,1,0);await call(p,'waitFront',actor,node.groupId);return 2;
}
