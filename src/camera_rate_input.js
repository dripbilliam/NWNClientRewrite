const f=Math.fround;
// Original7cfe60/7cfdb0/7d4340: flags block the setter, not already queued
// Follow values. Prediction fields are separate storage. Both impulse setters
// write module150, even yaw; module154 is NOT updated by the yaw impulse setter.
export function addCameraRate(s,axis,value,impulse=false){
 const block={yaw:16,pitch:32,zoom:64}[axis];if(block===undefined)throw new Error('Invalid camera input axis');if(s.flags&block)return false;
 const key=axis==='zoom'?'speed':axis==='yaw'?(impulse?'turnDelta':'turn'):(impulse?'tiltDelta':'tilt');
 s[key]=f((s[key]??0)+f(value));
 s.predictionInputs??={tilt:0,turn:0,tiltDelta:0,turnDelta:0,speed:0};
 s.predictionInputs[axis==='zoom'?'speed':impulse?'tiltDelta':axis==='yaw'?'turn':'tilt']=s[key];
 if(value!==0){s.manual=1;if(axis==='yaw')s.yawEvent=1;if(axis==='zoom')s.zoomEvent=1;}
 return true;
}
