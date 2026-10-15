import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction} from './object_actions.js';
const f=Math.fround;
const bits=v=>{const a=new DataView(new ArrayBuffer(4));a.setFloat32(0,v,true);return a.getInt32(0,true);};
const fromBits=v=>{const a=new DataView(new ArrayBuffer(4));a.setInt32(0,v,true);return a.getFloat32(0,true);};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native random-walk provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native random-walk ${n} is unavailable`);return v|0;};
const point=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native random-walk position is unavailable');return v.map(f);};
// ExecuteCommandActionRandomWalk14050e880. XYZ are type2 float bits;
// the fourth parameter is the canonical area ID (type3).
export function scriptRandomWalk(o,p){
  if(!o)return;if(o.objectType!==5)throw new Error('Native noncreature random-walk action owner is unavailable');
  const at=point(required(p,'position')(o)),area=required(p,'area')(o);if(!area||integer(o.nativeFieldEc,'commandability')===0)return;
  addObjectAction(o.objectActionState,45,65535,[{type:2,value:bits(at[0])},{type:2,value:bits(at[1])},{type:2,value:bits(at[2])},{type:3,value:area.id}]);
}
// AIActionRandomWalk1403c77b0: direct queued-node disposal, retry/wait,
// two CRT draws, and repeated .75 distance reductions until clear or <.1.
export async function executeRandomWalk(o,node,p){
  const origin=point(Array.from({length:3},(_,n)=>fromBits(node.parameterData[n]))),areaId=node.parameterData[3]>>>0,area=required(p,'areaById')(areaId);
  if(!area||!o.nativePathInfo)return 3;area.nativePathInfo280=o.nativePathInfo;
  const state=o.objectActionState;if(!state?.list)throw new Error('Native random-walk action list is unavailable');
  while(state.list.head){const old=state.list.shift();await required(p,'dispose')(old);}
  const retry=()=>addObjectAction(state,45,node.groupId,[...origin.map(v=>({type:2,value:bits(v)})),{type:3,value:areaId}],true);
  retry();addObjectAction(state,30,node.groupId,[{type:2,value:bits(integer(o.nativeAILevel7c,'AI level')<1?15:3)}],true);
  if(o.nativeAILevel7c<1)return 2;
  const random=()=>{const n=integer(required(p,'random')(),'CRT draw');if(n<0||n>32767)throw new Error('Native random-walk CRT draw is outside its range');return n;};
  let target=[f(origin[0]+f(f(random()%15)-7)),f(origin[1]+f(f(random()%15)-7)),0];target[2]=f(await required(p,'height')(area,target));
  const at=point(required(p,'position')(o)),difference=target.map((v,n)=>f(v-at[n]));let length=f(required(p,'magnitude')(difference));
  const direction=point(required(p,'normalize')(difference));
  let clear=await required(p,'directLine')(area,at,target,o.nativePathInfo.field4,o.nativePathInfo.fieldC,0),iterations=0;
  while(clear!==1){
    if(++iterations>10000)throw new Error('Native random-walk direction reduction exceeded the replacement action budget');
    length=f(length*f(.75));target=direction.map((v,n)=>f(f(v*length)+at[n]));if(length<f(.1))return 2;
    clear=await p.directLine(area,at,target,o.nativePathInfo.field4,o.nativePathInfo.fieldC,0);
  }
  await required(p,'moveFront')(o,node.groupId,target,areaId,OBJECT_INVALID,0,0,0,0,0,0,0,1,0);return 2;
}
