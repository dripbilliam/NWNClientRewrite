import assert from 'node:assert/strict';
export class CameraProbe {
 constructor({mode,send,now,report,fail,onReady,onDone,origin}){
  assert(['static','yaw'].includes(mode));Object.assign(this,{mode,send,now,report,fail,onReady,onDone,origin});
  this.phase='idle';this.sequence=0;this.samples=[];this.fps=[];this.commandLedger=[];
  this.result={version:1,mode,diagnosticOnly:true,actorInput:false,authorityTest:false,phase:'idle',samples:this.samples,rollingFps:this.fps,commands:this.commandLedger,scope:'Post-completion camera/render admission diagnostic; original input timeline and authority remain untouched. Process throughput differs from displayed FPS.'};report.cameraProbe=this.result;
 }
 start(observation,expected){
  assert(this.phase==='idle');assert(expected?.status==='expected');this.expected=expected;this.scope={...expected.scope};this.baseYaw=expected.follow.yaw;this.entities=observation.state.entities;
  this.assertObservation(observation);this.phase='binding';this.sendPose('bind',this.baseYaw,true,{expected:this.scope});
 }
 assertObservation(o){assert(o?.connection===this.scope.connection&&o.generation===this.scope.generation&&o.areaId===this.scope.areaId,'Camera probe world scope changed');assert(o.state?.object_visuals_complete===true&&o.state.ready===true&&o.state.pending_batches===0&&o.state.entities===this.entities,'Camera probe world incomplete/population changed');}
 sendPose(phase,yaw,observe,extra={}){
  if(this.sequence>=2500)throw Error('Camera command bound exceeded');const sequence=++this.sequence;
  this.commandLedger.push({sequence,phase,yaw,observe,elapsedMs:this.now()-this.origin()});
  this.lastSentAt=this.now();
  this.send({kind:'replay-view',connection:this.scope.connection,generation:this.scope.generation,areaId:this.scope.areaId,value:{camera_state:{yaw},camera_probe:{sequence,phase,observe,...extra}}});
 }
 observeWorld(o){if(this.phase==='idle'||this.phase==='done')return;this.assertObservation(o);if(this.phase==='measure'&&Number.isFinite(o.fps))this.fps.push({elapsedMs:this.now()-this.origin(),fps:o.fps});}
 ack(v){
  assert(this.samples.length<256,'Camera observation overflow');assert(v.connection===this.scope.connection&&v.generation===this.scope.generation&&v.areaId===this.scope.areaId,'Camera observation scope differs');
  const command=this.commandLedger.find(x=>x.sequence===v.sequence);assert(command?.observe&&command.phase===v.phase&&!this.samples.some(x=>x.sequence===v.sequence),'Unsolicited/repeated camera observation');
  assert(v.object_visuals_complete===true&&v.pending_batches===0&&v.entities===this.entities);assert(Number.isSafeInteger(v.process_frames)&&Number.isSafeInteger(v.ticks_usec));
  const c=v.camera,actor=c?.controlled;assert(c?.pose_valid===true&&c.pose_space==='world'&&Number.isFinite(c.follow?.yaw));assert(Array.isArray(c.position)&&c.position.length===3&&c.position.every(Number.isFinite)&&Array.isArray(c.quaternion)&&c.quaternion.length===4&&c.quaternion.every(Number.isFinite),'Actual camera transform unavailable');
  assert(actor?.actor_id===this.scope.actorId&&actor.lifetime===this.scope.lifetime&&actor.generation===this.scope.generation&&actor.area_id===this.scope.areaId&&actor.active===false&&actor.script===0&&actor.driveHeld===false,'Actor state changed');
  for(const key of ['position','render','received_position']){assert(Array.isArray(actor[key])&&actor[key].length===3);assert(Math.hypot(...actor[key].map((n,i)=>n-this.expected.receivedPosition[i]))<=0.02,'Actor authority/presentation moved');}
  assert(Math.abs(c.fov_degrees-this.expected.fovDegrees)<1e-4&&Math.abs(c.follow.pitch-this.expected.follow.pitch)<1e-4&&Math.abs(c.follow.distance-this.expected.follow.distance)<1e-4&&c.follow.mode===this.expected.follow.mode,'Camera settings changed');
  this.samples.push({...v,hostElapsedMs:this.now()-this.origin(),hostUtcMs:Date.now()});
  if(v.phase==='bind'){assert(this.phase==='binding');this.phase='prewarm';this.phaseStart=this.now();this.slot=0;}
  else if(v.phase==='warm-restored'){assert(this.phase==='warm-restoring');this.phase='settle';this.phaseStart=this.now();}
  else if(v.phase==='measure-start'){assert(this.phase==='measure-starting');this.phase='measure';this.phaseStart=this.now();this.slot=0;this.result.hostWindow={beginElapsedMs:this.phaseStart-this.origin(),beginUtcMs:Date.now()};this.result.nativeBegin=v;}
  else if(v.phase==='measure-end'){assert(this.phase==='measure-ending');this.result.nativeEnd=v;this.result.hostWindow.endElapsedMs=this.now()-this.origin();this.result.hostWindow.endUtcMs=Date.now();this.phase='restoring';this.sendPose('restored',this.baseYaw,true);}
  else if(v.phase==='restored'){assert(this.phase==='restoring');assert(Math.abs(c.follow.yaw-this.baseYaw)<1e-3);this.phase='done';this.complete();this.onDone();}
 }
 windowReady(){assert(this.phase==='window-requested');this.phase='measure-starting';this.sendPose('measure-start',this.baseYaw,true);}
 tick(observation){
  if(['idle','done'].includes(this.phase))return;this.assertObservation(observation);
  if(!['prewarm','measure','settle'].includes(this.phase))assert(this.now()-this.lastSentAt<10000,'Camera observation/window acknowledgement timeout');
  if(['prewarm','measure'].includes(this.phase)){
   const elapsed=this.now()-this.phaseStart;if(elapsed>=20000){if(this.phase==='prewarm'){this.phase='warm-restoring';this.sendPose('warm-restored',this.baseYaw,true);}else{this.phase='measure-ending';this.sendPose('measure-end',this.baseYaw,true);}return;}
   const due=Math.floor(elapsed*60/1000);if(due>=this.slot){const at=elapsed/1000,yaw=this.baseYaw+((this.phase==='prewarm'||this.mode==='yaw')?20*Math.sin(2*Math.PI*at/5):0);this.sendPose(this.phase,yaw,this.slot%12===0);this.slot=due+1;}
  }else if(this.phase==='settle'&&this.now()-this.phaseStart>=5000){this.phase='window-requested';this.lastSentAt=this.now();this.onReady();}
  this.result.phase=this.phase;
 }
 complete(){
  const begin=this.result.nativeBegin,end=this.result.nativeEnd;assert(begin&&end);const frames=end.process_frames-begin.process_frames,usec=end.ticks_usec-begin.ticks_usec;assert(frames>0&&usec>=19500000&&usec<23000000,'Native camera interval differs');
  const moving=this.samples.filter(x=>x.phase==='measure'),deltas=moving.map(x=>Math.abs(x.camera.follow.yaw-this.baseYaw));assert(moving.length>=60,'Insufficient actual camera readback');
  const poseDeltas=moving.map(x=>Math.hypot(...x.camera.position.map((v,i)=>v-begin.camera.position[i])));
  if(this.mode==='yaw'){assert(Math.max(...deltas)>18&&deltas.filter(x=>x>5).length>=30,'Actual camera did not sweep');assert(Math.max(...poseDeltas)>1,'Actual world camera pose did not move');}else{assert(Math.max(...deltas)<1e-3,'Static camera moved');assert(Math.max(...poseDeltas)<0.02,'Static world camera pose moved');}
  const endElapsed=this.result.hostWindow.endElapsedMs,beginElapsed=this.result.hostWindow.beginElapsedMs;
  this.result.engineThroughput={begin_process_frames:begin.process_frames,end_process_frames:end.process_frames,begin_ticks_usec:begin.ticks_usec,end_ticks_usec:end.ticks_usec,frames_delta:frames,elapsed_usec:usec,average_fps:frames*1e6/usec,scope:'Exact Engine process-frame delta/native monotonic interval. Not GPU/displayed frames.'};
  this.result.hostWindow.elapsedMs=endElapsed-beginElapsed;this.result.hostWindow.scope='Driver hello-origin elapsed clock at actual native camera start/end acknowledgements; rolling FPS uses2s leading margin.';
  this.result.trimmedRollingFps=this.fps.filter(x=>x.elapsedMs>=beginElapsed+2000&&x.elapsedMs<=endElapsed-500);assert(this.result.trimmedRollingFps.length>=10,'FPS window observations insufficient');
  this.result.success=true;this.result.phase='done';
 }
}
