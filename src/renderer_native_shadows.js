import {nativeLightPriority} from './renderer_light_selection.js';
const f=Math.fround;

// GetShadowLights14007f840, modes 1 then 0 in RenderSinglePass1400d0f10.
// Lists share PartLight+ac fade values. Allocation and exact std::sort ties
// are not emulated; equal priorities retain source traversal order.
export function selectNativeShadows(candidates,previous,fades,maximum,mode,delta){
 const selected=[];
 if(maximum>0)for(const c of candidates){
  if(mode===1&&!c.dynamic)continue;
  if(c.distance<=c.radius){selected.push(c.light);if(mode===1||selected.length>=maximum)break;}
 }
 const before=previous.slice();
 for(const light of selected)if(!before.includes(light))fades.set(light,0);
 for(const light of before.slice(0,maximum))if(!selected.includes(light)){
  const fade=f(Math.max(0,f(f(fades.get(light)??0)-f(f(f(delta)*2)/f(.3)))));
  fades.set(light,fade);if(fade>0)selected.unshift(light);
 }
 selected.length=Math.min(selected.length,maximum);
 for(const light of selected)fades.set(light,f(Math.min(1,f(f(fades.get(light)??0)+f(f(delta)/f(.3))))));
 return selected;
}

export class RendererNativeShadows{
 constructor({maximum=3}={}){this.maximum=maximum;this.reset();}
 reset(){this.previous=[[],[]];this.fades=new Map();this.root=null;this.lastAt=null;this.state=null;}
 update(candidates,present,{focus,delta=0,scene}={}){
  if(scene!==this.root){this.reset();this.root=scene;}
  const live=new Set(present),records=[];
  for(const light of this.fades.keys())if(!live.has(light))this.fades.delete(light);
  this.previous=this.previous.map(list=>list.filter(light=>live.has(light)));
  for(const c of candidates){
   const p=c.light.userData.mdlLight;if(!p)continue;
   const color=p.color??[1,1,1],radius=f(Number(p.radius??0)),shadow=f(Number(p.shadowradius??0));
   // PrioritizeShadow1400801b0: ambient-only and <=.1 RGB do not qualify.
   if(Number(p.ambientonly)||!color.some(v=>f(v)>f(.1)))continue;
   const score=nativeLightPriority({position:c.position,color,radius,multiplier:Number(p.multiplier??1),priority:Number(p.lightpriority??0),priorityOverride:c.light.userData.mdlLightPriority90??0,dynamic:Number(p.isdynamic??0),fading:Number(p.fadinglight??0)},focus);
   records.push({light:c.light,order:c.order,...score,radius:shadow>0?shadow:radius,dynamic:Boolean(Number(p.isdynamic))});
  }
  records.sort((a,b)=>a.priority-b.priority||a.order-b.order);
  const maximum=Math.max(0,Math.min(3,Math.trunc(this.maximum)||0)),dt=Number.isFinite(delta)?Math.max(0,delta):0;
  // One shared fade field; mode 1 runs first, as in the original call sites.
  for(const mode of [1,0])this.previous[mode]=selectNativeShadows(records,this.previous[mode],this.fades,maximum,mode,dt);
  const selected=new Set([...this.previous[1],...this.previous[0]]);
  this.state={maximum,eligible:records.length,normal:this.previous[0].length,dynamic:this.previous[1].length,selected:selected.size};
  return{...this.state,selected,fades:this.fades};
 }
}
