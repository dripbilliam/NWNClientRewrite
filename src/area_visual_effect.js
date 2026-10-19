const f=Math.fround;
export function createAreaVisualState(now){return{objectType:11,position:[0,0,0],since:{...now},elapsed58:0,sound170:null,retire178:0,remaining17c:0,visual180:-1,phase184:0,retiring188:0,suppressed18c:0,instant190:0,destroy194:1,orient198:0,detach19c:0,skipRetirement1a0:0,repeat1a4:0,model:null,destroyed:false};}

// Complete872770 table selection. Area effects select ONE model, in this
// physical order, rather than routing through CLoopingVisualEffect/dummies.
export async function loadAreaVisualEffect(e,id,p){
 id|=0;const orient=p.int(id,'OrientWithGround');e.orient198=Number(orient.found&&orient.value!==0);
 let selected={found:false,value:''};
 if(!p.quality())selected=p.string(id,'LowQuality');
 if(!selected.found)for(const name of ['Imp_HeadCon_Node','Imp_Impact_Node','Imp_Root_M_Node','Imp_Root_S_Node','Imp_Root_L_Node','Imp_Root_H_Node']){selected=p.string(id,name);if(selected.found)break;}
 const type=p.int(id,'ShakeType'),duration=p.float(id,'ShakeDuration'),delay=p.float(id,'ShakeDelay');
 if(type.found&&type.value===1)p.shake(1,Math.trunc(f(delay.found?delay.value:0)*1000),0);
 else if(type.found&&type.value===2)p.shake(2,Math.trunc(f(delay.found?delay.value:0)*1000),Math.trunc(f(duration.found?duration.value:0)*1000));
 if(selected.found&&!await p.loadModel(e,selected.value,255,8))return 0;
 if(((id-39)>>>0)<2)p.animationMode(e,3);
 if(id===253||id===219)p.defaultAnimation(e);
 e.visual180=id;return 1;
}

// Complete873160; the model wrapper reports milliseconds, not seconds.
export function startAreaVisualEffect(e,phase,p){
 phase&=65535;e.remaining17c=0;e.phase184=phase;const speed=e.visual180===40?p.speed40():1;
 if(phase===1||phase===3){
  const sound=p.string(e.visual180,phase===1?'SoundImpact':'SoundCessation');p.oneShot(sound.found?sound.value:'',e.position.map(f),f(1.5),11,0,0);
  if(phase===3&&e.sound170){p.stopSound(e.sound170);p.destroySound(e.sound170);e.sound170=null;}
  if(e.model){e.remaining17c=Math.trunc(f(p.animationLength(e,phase)))>>>0;p.play(e,phase,speed,Number(e.repeat1a4===0),0);}
 }else{
  const sound=p.string(e.visual180,'SoundDuration');e.sound170=p.createSound(sound.found?sound.value:'');
  if(e.sound170){p.sound3d(e.sound170,1);p.soundPriority(e.sound170,11);p.soundLooping(e.sound170,1);p.playSound(e.sound170);}
  if(e.model)p.play(e,phase,speed,0,0);
 }
}

// Complete872330 with profiling disabled. Unsigned millisecond REMAINDER from
// SubtractWorldTimes is used; the returned day count is deliberately ignored.
export function updateAreaVisualEffect(e,p){
 if(e.suppressed18c)return;
 const now=p.now();e.elapsed58=p.difference(now,e.since).time>>>0;e.since={...now};
 if(e.sound170)p.updateSound(e.sound170,e.position.map(f),f(1.5));
 if(e.remaining17c){
  if(e.elapsed58<e.remaining17c)e.remaining17c=(e.remaining17c-e.elapsed58)>>>0;
  else{e.remaining17c=0;
   if(e.phase184===1){if(!e.instant190)startAreaVisualEffect(e,2,p);else{e.retiring188=1;e.retire178=e.skipRetirement1a0?0:3000;}}
   else if(e.phase184===3){e.retiring188=1;e.retire178=3000;}
  }
 }
 if(e.retiring188){if(e.elapsed58<e.retire178)e.retire178=(e.retire178-e.elapsed58)>>>0;
  else if(!e.destroy194){if(e.detach19c)p.setScene(e,null);e.suppressed18c=1;e.retiring188=0;}
  else p.destroy(e);
 }
}
