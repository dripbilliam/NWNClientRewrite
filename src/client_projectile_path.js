import {OBJECT_INVALID} from './game_object_array.js';
import {normalizeNativeVector} from './native_vector.js';
const f=Math.fround,copy=p=>p.map(f),sub=(a,b)=>a.map((v,i)=>f(v-b[i])),add=(a,b)=>a.map((v,i)=>f(v+b[i]));
const squared=v=>f(f(f(v[1]*v[1])+f(v[0]*v[0]))+f(v[2]*v[2]));
const call=(p,key,...args)=>{if(typeof p?.[key]!=='function')throw new Error(`Native projectile path provider ${key} is unavailable`);return p[key](...args);};

// CNWCProjectile140987770. Physical node layouts/ownership and UINT duration
// arithmetic; complex path builders retain their separate native boundaries.
export function configureClientProjectilePath(state,path,p){
 state.path=path|0;
 if((state.targetId>>>0)!==OBJECT_INVALID){const found=call(p,'getObject',state.targetId>>>0);if(found.status===0)state.endpoint=copy(found.object.position);}
 while(state.nodes.length){const node=state.nodes.shift();if(node)call(p,'destroyNode',node);}
 if([1,2,4,5,7,9,10,50].includes(state.path)){
  const point=(state.targetId>>>0)===OBJECT_INVALID||!call(p,'clientObject',state.targetId>>>0)?copy(state.endpoint):[0,0,0];
  const make=(kind,attachment,duration,threshold=0,spawnCount=0,childPath=0)=>({point:copy(point),attachment:copy(attachment),targetId:state.targetId>>>0,childPath,duration:duration>>>0,threshold:threshold>>>0,radius:-1,spawnCount,kind});
  const append=node=>{call(p,'allocateNode',node);state.nodes.push(node);};
  if(state.path===50){
   const split=Math.floor((Math.imul(state.totalTime,6)>>>0)/10);
   append(make(2,state.endpoint,state.totalTime,split));append(make(4,state.endpoint,split,0,3,9));
  }else append(make(state.path===10?12:state.path,state.path===7?[0,0,0]:point,state.totalTime));
 }else if([3,6,8,11,12,13].includes(state.path))call(p,'buildPath',state,state.path);
 else return;
 state.node=state.nodes.shift();
 if(!state.node)throw new Error('Native projectile path builder returned no physical node');
 state.remaining=state.totalTime=state.node.duration>>>0;state.endpoint=copy(state.node.point);
 call(p,'initializeNode',state,copy(state.orientation));
}

// Deterministic initialization140987f10. Type admission and unresolved-object
// behavior differ from per-frame target resolution; preserve that distinction.
// Random/linked/model operations are explicit providers, never generic stand-ins.
export function initializeClientProjectileNode(state,orientation,p){
 const node=state.node;if(!node)return;
 let point=[0,0,0];
 if((state.targetId>>>0)===OBJECT_INVALID)point=copy(node.point);
 else{
  const found=call(p,'getObject',state.targetId>>>0);
  if(found.status===0&&found.object.objectType>=5){
   const object=found.object,model=call(p,'model',object);
   if(!model)point=copy(state.endpoint);
   else{
    // Native queries the model twice before looking up the named part.
    const pose=[0,0,0],quaternion=[1,0,0,0],second=call(p,'model',object);
    if(!call(p,'nodePose',second,state.impactNode??'',pose,quaternion))point=[f(object.position[0]),f(object.position[1]),f(f(object.position[2])+1.25)];
    else point=copy(pose);
    point=add(point,node.point);
   }
  }
 }
 const delta=sub(point,copy(state.position));
 if(squared(delta)<=f(1e-10)){state.velocity=[0,0,0];state.acceleration=[0,0,0];return;}
 const time=f(f(state.remaining>>>0)/1000);
 if(node.kind===2)state.acceleration=[0,0,f(-9.81)];
 else if([1,6].includes(node.kind))state.acceleration=[0,0,0];
 else if(node.kind===5){
  state.velocity=[0,0,0];const scale=f(1/f(time*time));
  state.acceleration=delta.map(v=>f(f(v+v)*scale));
 }else if(node.kind===10){
  orientation[2]=0;state.acceleration=normalizeNativeVector(orientation).map(v=>f(v*7.5));
  const scale=f(2/time);state.velocity=delta.map((v,i)=>f(f(v*scale)-state.acceleration[i]));
  for(let i=0;i<2;i++)state.acceleration[i]=f(f(f(state.acceleration[i]*state.acceleration[i])-f(state.velocity[i]*state.velocity[i]))/f(delta[i]*2));
 }else if([4,7,9,12].includes(node.kind))call(p,'initializeSpecial',state,orientation,delta,time);
 else{state.velocity=[0,0,0];state.acceleration=[0,0,0];}
}

// Native high-ballistic986390 and spiral986890 builders. The latter preserves
// its2500ms orbit phase, including UINT underflow for shorter travel times.
export function buildClientProjectilePath(state,path,p){
 const append=(point,attachment,kind,duration,targetId=state.targetId,radius=-1)=>{
  const node={point:copy(point),attachment:copy(attachment),kind,duration:duration>>>0,targetId:targetId>>>0,radius,threshold:0,spawnCount:0,childPath:0};
  call(p,'allocateNode',node);state.nodes.push(node);
 };
 if(path===3){
  const point=(state.targetId>>>0)===OBJECT_INVALID||!call(p,'clientObject',state.targetId>>>0)?copy(state.endpoint):[0,0,0],half=(state.totalTime>>>0)>>>1;
  const lift=copy(state.position);lift[2]=f(lift[2]+30);
  append(lift,point,1,half,OBJECT_INVALID);
  const reset=copy(point);reset[2]=f(reset[2]+30);append(reset,point,11,0);
  append(point,point,1,((state.totalTime>>>0)-half)>>>0);
 }else if(path===6){
  const random=call(p,'random');if(!Number.isInteger(random)||random<0||random>32767)throw new Error('Native projectile CRT draw is unavailable');
  state.spiralSide=random%2;
  const delta=sub(copy(state.endpoint),copy(state.position)),perpendicular=state.spiralSide?[f(-delta[1]),delta[0],0]:[delta[1],f(-delta[0]),0];
  if(squared(perpendicular)<=f(1e-10))perpendicular.splice(0,3,0,1,0);
  let point=normalizeNativeVector(perpendicular).map(v=>f(v+v));
  const invalid=(state.targetId>>>0)===OBJECT_INVALID;
  if(invalid)point=[f(point[0]+f(state.endpoint[0])),f(point[1]+f(state.endpoint[1])),f(state.position[2])];
  if((state.totalTime|0)===2500){
   let admitted=invalid;
   if(!invalid){const found=call(p,'getObject',state.targetId>>>0);if(found.status===0){point=[f(f(found.object.position[0])+point[0]),f(f(found.object.position[1])+point[1]),f(state.position[2])];admitted=true;}}
   if(admitted)call(p,'setPosition',state,point);
  }else append(point,invalid?state.endpoint:[0,0,0],10,(state.totalTime-2500)>>>0,state.targetId,2);
  const final=invalid?state.endpoint:[0,0,0];append(final,final,6,2500);
 }else throw new Error(`Native projectile path builder ${path} is unavailable`);
}

// CNWCProjectile140988ed0: physical-node advancement. The optional child
// projectile creation block remains an explicit service, with no fake spawn.
export function nextClientProjectileNode(state,p){
 if(state.node){call(p,'destroyNode',state.node);state.node=null;}
 while(state.nodes.length){
  state.node=state.nodes.shift();const node=state.node;if(!node)return 0;
  if(node.kind===11){
   if(state.model&&call(p,'setStage',state,0)!==0)state.stage=0;
   call(p,'animateExternal',call(p,'model',state),1);
   if((node.targetId>>>0)===OBJECT_INVALID)call(p,'setPosition',state,copy(node.point));
   else{const found=call(p,'getObject',node.targetId>>>0);if(found.status===0)call(p,'setPosition',state,add(copy(found.object.position),node.point));}
   call(p,'animateExternal',call(p,'model',state),1);
   if(state.model&&call(p,'setStage',state,1)!==0)state.stage=1;
  }
  if((node.spawnCount&255)!==0)call(p,'spawnNodeChildren',state,node);
  state.remaining=state.totalTime=node.duration>>>0;state.endpoint=copy(node.point);
  call(p,'initializeNode',state,copy(state.orientation));
  if(node.kind!==11&&(state.elapsed>>>0)<(state.remaining>>>0))return 1;
 }
 return 0;
}

// CNWCProjectile140984f00..1409854c1. Path/AI providers own physical node
// transitions and rendering. The coordinator retains native timer ordering,
// target attachment caching, radius admission and motion dispatch.
export function updateClientProjectilePath(state,p){
 if(!state.node)return;
 let resolved=[0,0,0];
 const endpoint=first=>{
  const node=state.node;
  if((node.targetId>>>0)===OBJECT_INVALID){state.endpoint=copy(node.point);return;}
  const found=call(p,'getObject',node.targetId>>>0);
  if(found.status!==0){if(first)state.endpoint=copy(node.point);return;}
  const object=found.object,model=call(p,'model',object);
  if(!model)resolved=copy(state.endpoint);
  else{
   const pose=[0,0,0],quaternion=[1,0,0,0],second=call(p,'model',object);
   if(!call(p,'nodePose',second,state.impactNode??'',pose,quaternion)){
    resolved=[f(object.position[0]),f(object.position[1]),f(f(object.position[2])+1.25)];
    if((((state.result&255)-2)&255)<2)resolved=add(resolved,copy(state.orientation).map(v=>f(v*f(-.5))));
   }else resolved=copy(pose);
  }
  node.attachment=copy(resolved);state.endpoint=add(resolved,node.point);
 };
 endpoint(true);
 const expired=(state.remaining>>>0)<=(state.elapsed>>>0);
 if(expired){state.elapsed=(state.elapsed-state.remaining)>>>0;state.remaining=0;call(p,'setPosition',state,copy(state.endpoint));}
 if(((((state.remaining-state.elapsed)>>>0)<=(state.node.threshold>>>0))||expired)&&call(p,'nextNode',state)===0)return;
 state.remaining=(state.remaining-state.elapsed)>>>0;
 if(!state.node)return;
 endpoint(false);
 const delta=sub(copy(state.endpoint),copy(state.position));
 if(squared(delta)>f(1e-10)){
  const node=state.node;
  if(!(node.radius>=0&&(node.targetId>>>0)!==OBJECT_INVALID&&squared(sub(copy(state.position),resolved))<=f(f(node.radius)*f(node.radius)))){
   state.previousPosition=copy(state.position);
   if([1,2,4,5,9,10,12].includes(node.kind))call(p,'basicMotion',state);
   else if(node.kind===6)call(p,'spiralMotion',state);
   return;
  }
 }else{
  call(p,'setPosition',state,copy(state.endpoint));
  if(state.node.radius<0)return;
 }
 const saved=state.remaining|0;call(p,'nextNode',state);state.remaining=(state.remaining+saved)>>>0;
}
