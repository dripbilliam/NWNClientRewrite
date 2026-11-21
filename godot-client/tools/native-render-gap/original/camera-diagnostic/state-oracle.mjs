import assert from 'node:assert/strict';
import {CameraProbe} from './camera-probe.mjs';
const scope={connection:1,generation:2,areaId:3,actorId:4,lifetime:5};
const expected={status:'expected',scope,receivedPosition:[5,6,7],fovDegrees:45,follow:{yaw:30,pitch:38,distance:25,mode:1}};
function fixture(mode){
 let now=0,frame=0,yaw=30,done=false;const pending=[],report={},world={connection:1,generation:2,areaId:3,fps:100,state:{ready:true,object_visuals_complete:true,pending_batches:0,entities:12}};
 const camera=()=>({pose_valid:true,pose_space:'world',position:[25*Math.sin(yaw*Math.PI/180),4,25*Math.cos(yaw*Math.PI/180)],quaternion:[0,Math.sin(yaw*Math.PI/360),0,Math.cos(yaw*Math.PI/360)],follow:{...expected.follow,yaw},fov_degrees:45,controlled:{actor_id:4,lifetime:5,generation:2,area_id:3,active:false,script:0,driveHeld:false,position:[5,6,7],render:[5,6,7],received_position:[5,6,7]}});
 let probe;probe=new CameraProbe({mode,now:()=>now,origin:()=>0,report,fail:r=>{throw Error(r);},onReady:()=>probe.windowReady(),onDone:()=>{done=true;},send:m=>{const p=m.value.camera_probe;yaw=m.value.camera_state.yaw;if(p.observe)pending.push({at:now+20,command:p});}});
 const sample=command=>({kind:'camera-probe-observed',connection:1,generation:2,areaId:3,sequence:command.sequence,phase:command.phase,process_frames:frame,ticks_usec:Math.round(now*1000),camera:camera(),object_visuals_complete:true,pending_batches:0,entities:12});
 return{probe,report,world,run(){probe.start(world,expected);for(;now<70000&&!done;now+=10){frame++;for(let i=0;i<pending.length;){if(pending[i].at<=now){const item=pending.splice(i,1)[0];probe.ack(sample(item.command));}else i++;}if(now%500===0)probe.observeWorld(world);probe.tick(world);}assert(done);return report.cameraProbe;},sample};
}
const rows=[];for(const mode of ['static','yaw']){const f=fixture(mode),r=f.run();assert(r.success&&r.commands.length<=2500&&r.samples.length<=256);assert(r.engineThroughput.frames_delta>1900&&r.trimmedRollingFps.length>20);rows.push({mode,commands:r.commands.length,observations:r.samples.length,throughput:r.engineThroughput.average_fps});}
const bad=fixture('static');bad.probe.start(bad.world,expected);assert.throws(()=>bad.probe.observeWorld({...bad.world,generation:9}));assert.throws(()=>bad.probe.ack({...bad.sample({sequence:1,phase:'bind'}),sequence:999}));assert.throws(()=>bad.probe.ack({...bad.sample({sequence:1,phase:'bind'}),camera:{...bad.sample({sequence:1,phase:'bind'}).camera,controlled:{actor_id:4,lifetime:6}}}));
console.log(JSON.stringify({success:true,checks:7,rows,scope:'Deterministic host state/schedule/scope/readback oracle only. No engine/GPU/performance claim.'}));
