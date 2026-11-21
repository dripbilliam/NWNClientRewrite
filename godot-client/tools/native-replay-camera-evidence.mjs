// Read-only verification. Captured positions are expectations, never actor writes.
const vector=(v,n=3)=>Array.isArray(v)&&v.length===n&&v.every(Number.isFinite);
const distance=(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]));
const godot=v=>[v[0],v[2],-v[1]];
const near=(a,b,tolerance)=>Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=tolerance;
const angle=(a,b)=>Math.abs(((a-b+180)%360+360)%360-180);

export function deriveReplayCameraExpectation(records,fovDegrees){
 const errors=[],lastInput=records.findLast(row=>row.kind==='movement-input');
 const terminal=records.findLast(row=>row.kind==='movement-sample'),view=records.findLast(row=>row.kind==='view')?.value;
 const sample=terminal?.value,state=sample?.state;
 if(!near(fovDegrees,fovDegrees,0)||fovDegrees<20||fovDegrees>120)errors.push('Explicit common preference FOV unavailable');
 if(!lastInput||lastInput.value?.operation!=='stop')errors.push('Captured input section has no terminal stop');
 if(!terminal||!lastInput||terminal.sequence<=lastInput.sequence)errors.push('Captured terminal motion evidence is unavailable');
 for(const key of ['connection','generation','areaId','actorId','lifetime'])if(sample?.[key]!==lastInput?.value?.[key]||!Number.isSafeInteger(sample?.[key]))errors.push('Captured terminal actor scope mismatch: '+key);
 if(!state||state.active!==false||state.script!==0||state.driveHeld!==false||![0,1].includes(state.animation))errors.push('Captured terminal motion is not idle/released');
 if(!vector(state?.received_position)||!vector(state?.render)||!vector(state?.position)||vector(state?.received_position)&&vector(state?.render)&&distance(state.received_position,state.render)>0.02||vector(state?.received_position)&&vector(state?.position)&&distance(state.received_position,state.position)>0.02)errors.push('Captured terminal render/authority positions are not settled');
 if(!view?.camera_state||!['yaw','pitch','distance','mode'].every(k=>Number.isFinite(view.camera_state[k])))errors.push('Captured final follow-camera inputs unavailable');
 return {status:errors.length?'unavailable':'expected',errors,sourceSequence:terminal?.sequence,sourceAtMs:terminal?.at,scope:{connection:sample?.connection,generation:sample?.generation,areaId:sample?.areaId,actorId:sample?.actorId,lifetime:sample?.lifetime},receivedPosition:state?.received_position,player:vector(state?.received_position)?godot(state.received_position):null,fovDegrees,recordedFovDegrees:view?.fov,follow:view?.camera_state,scopeNote:'Captured terminal idle/authority and recorded follow inputs; explicit immutable preference FOV. No captured actor position is applied.'};
}

export function verifyReplayCameraEvidence(expected,native,{tolerance=0.02}={}){
 const errors=[],camera=native?.runtime_features?.presentation?.camera,controlled=camera?.controlled;
 if(expected?.status!=='expected')errors.push('Terminal camera/motion expectation unavailable');
 const point=expected?.player;
 if(!vector(point)||!vector(native?.camera?.player)||vector(point)&&vector(native?.camera?.player)&&distance(point,native.camera.player)>tolerance)errors.push('Rendered controlled actor differs from captured terminal authority');
 if(!controlled||controlled.actor_id!==expected?.scope?.actorId||controlled.lifetime!==expected?.scope?.lifetime||controlled.generation!==expected?.scope?.generation||controlled.area_id!==expected?.scope?.areaId)errors.push('Actual terminal actor scope mismatch');
 if(controlled?.active!==false||controlled?.script!==0||controlled?.driveHeld!==false)errors.push('Actual terminal motion is not idle/released');
 for(const key of ['position','render','received_position'])if(!vector(controlled?.[key])||!vector(expected?.receivedPosition)||vector(controlled?.[key])&&vector(expected?.receivedPosition)&&distance(controlled[key],expected.receivedPosition)>tolerance)errors.push('Actual terminal '+key+' differs from captured authority');
 if(camera?.pose_space!=='world'||!vector(camera?.position)||!vector(camera?.quaternion,4)||!vector(camera?.target))errors.push('Actual world camera pose unavailable');
 errors.push(...verifyReplayProjection(camera,expected?.fovDegrees).errors);
 if(!Number.isFinite(camera?.follow_height)||!vector(point)||!vector(camera?.target)||vector(point)&&vector(camera?.target)&&distance(camera.target,[point[0],point[1]+camera.follow_height,point[2]])>tolerance)errors.push('Actual camera target differs from terminal follow anchor');
 for(const key of ['pitch','distance'])if(!near(camera?.follow?.[key],expected?.follow?.[key],0.0001))errors.push('Actual final follow '+key+' differs from recorded input');
 if(!Number.isFinite(camera?.follow?.yaw)||!Number.isFinite(expected?.follow?.yaw)||angle(camera.follow.yaw,expected.follow.yaw)>0.0001||camera?.follow?.mode!==expected?.follow?.mode)errors.push('Actual final follow yaw/mode differs from recorded input');
 if(vector(camera?.quaternion,4)&&Math.abs(Math.hypot(...camera.quaternion)-1)>0.001)errors.push('Actual camera quaternion is not normalized');
 if(vector(camera?.position)&&vector(camera?.target)&&!near(distance(camera.position,camera.target),camera?.follow?.distance,tolerance))errors.push('Actual world camera distance differs from follow distance');
 if(vector(camera?.position)&&vector(camera?.target)&&vector(camera?.quaternion,4)){
  const [x,y,z,w]=camera.quaternion,forward=[-2*(x*z+w*y),-2*(y*z-w*x),-(1-2*(x*x+y*y))],offset=camera.target.map((v,i)=>v-camera.position[i]),length=Math.hypot(...offset);
  if(length<=0||forward.reduce((sum,v,i)=>sum+v*offset[i]/length,0)<0.999999)errors.push('Actual camera orientation does not face the terminal target');
 }
 if(native?.performance_window?.steady===true){
  for(const key of ['view_begin','view_end']){
   const view=native.performance_window[key]?.camera;
   if(!view){errors.push('Steady camera boundary missing: '+key);continue;}
   errors.push(...verifyReplayProjection(view,expected?.fovDegrees).errors.map(error=>key+': '+error));
   for(const field of ['position','target'])if(!vector(view[field])||!vector(camera?.[field])||vector(view[field])&&vector(camera?.[field])&&distance(view[field],camera[field])>tolerance)errors.push('Steady camera '+key+' '+field+' differs from terminal view');
   if(!vector(view.quaternion,4)||!vector(camera?.quaternion,4)||vector(view.quaternion,4)&&vector(camera?.quaternion,4)&&Math.abs(view.quaternion.reduce((sum,v,i)=>sum+v*camera.quaternion[i],0))<0.999999)errors.push('Steady camera '+key+' rotation differs from terminal view');
   const motion=view.controlled;
   if(!motion||motion.actor_id!==controlled?.actor_id||motion.lifetime!==controlled?.lifetime||motion.generation!==controlled?.generation||motion.area_id!==controlled?.area_id||motion.active!==false||motion.script!==0||motion.driveHeld!==false)errors.push('Steady camera '+key+' controlled scope/motion differs from terminal evidence');
   for(const field of ['position','render','received_position'])if(!vector(motion?.[field])||!vector(expected?.receivedPosition)||vector(motion?.[field])&&vector(expected?.receivedPosition)&&distance(motion[field],expected.receivedPosition)>tolerance)errors.push('Steady camera '+key+' '+field+' differs from terminal authority');
   for(const field of ['near','far'])if(!near(view[field],camera?.[field],0.0001))errors.push('Steady camera '+key+' clip plane changed: '+field);
  }
 }
 return {status:errors.length?'rejected':'observed',errors,expected,actual:{camera,renderedPlayer:native?.camera?.player},scope:'Final actual world camera, active preference projection and settled controlled motion checked against retained capture evidence; no claim of exact original network timing or per-frame trajectory equivalence'};
}

export function verifyReplayProjection(camera,fovDegrees){
 const errors=[];
 if(!near(camera?.fov_degrees,fovDegrees,0.0001)||camera?.projection!==0||camera?.keep_aspect!==1)errors.push('Actual projection differs from explicit common FOV/perspective convention');
 if(!Number.isFinite(camera?.near)||!Number.isFinite(camera?.far)||camera.near<=0||camera.far<=camera.near)errors.push('Actual clip-plane evidence unavailable');
 return {status:errors.length?'rejected':'observed',errors,expected:{fovDegrees,projection:0,keepAspect:1},actual:camera,scope:'Actual camera projection properties; common preference FOV overrides historical recorded FOV. Clip planes observed, not silently inferred from capture metadata.'};
}
