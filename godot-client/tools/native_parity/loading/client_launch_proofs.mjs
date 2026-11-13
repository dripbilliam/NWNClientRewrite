// Read-only reviewed supplemental evidence. No process launch or runtime writes.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const read=(file,expected)=>{
 const raw=fs.readFileSync(file),sha256=sha(raw);
 if(expected&&sha256!==expected)throw Error('Reviewed supplemental proof changed: '+file);
 return {value:JSON.parse(raw),pin:{file,sha256}};
};

export function selectClientLaunchDisplay(project){
 const proof=read(path.join(project,'.cache/native-presentation-parity/root/live-blockers-pixels-v2/run.json'),'931777854f9d535d2a00655b1b46ae885db97b07fa5586578f0f096cdcb4969d');
 const window=proof.value.result?.window;
 if(proof.value.success!==true||proof.value.exit!==0||proof.value.errors?.length!==0||proof.value.result?.success!==true||
    !Number.isSafeInteger(window?.screen)||!Number.isSafeInteger(window?.primary)||window.primary<0||
    window.screen!==window.first_nonprimary||window.screen!==(window.primary===0?1:0)||
    !window.unfocusable||window.focused!==false||window.mouse!==0)throw Error('Reviewed first-nonprimary display evidence unavailable');
 const stage=read(proof.value.stage.file,proof.value.stage.sha256);
 return {screen:window.screen,primary:window.primary,policy:'first-nonprimary',unfocusable:true,pointerCapture:false,proofPins:[proof.pin,stage.pin],observed:proof.value.finished};
}

export function verifyClientLaunchDisplay(display){
 if(display?.policy!=='first-nonprimary'||!Number.isSafeInteger(display.screen)||!Number.isSafeInteger(display.primary)||
    display.primary<0||display.screen!==(display.primary===0?1:0)||display.screen===display.primary||
    display.unfocusable!==true||display.pointerCapture!==false||display.proofPins?.length!==2)throw Error('Reviewed nonprimary launch display missing');
 for(const pin of display.proofPins)read(pin.file,pin.sha256);
}

export function selectMotionBoundaryProof(project,motionSha256){
 const proof=read(path.join(project,'.cache/native-presentation-parity/loading-agent/motion-position-boundary-recovery-v2/run.json'),'ae68e654efe819a6a68c86282e2911582537be0112e940e2e00353adb431218e');
 const run=proof.value,stage=read(run.stage.file,run.stage.sha256),motion=stage.value.pins.find(pin=>pin.source===path.join(project,'systems/network_motion.gd'));
 if(run.success!==true||run.sourceChanged?.length!==0||run.results?.length!==2||run.engine?.sha256!=='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc'||
    run.results.some((row,index)=>row.name!==['boundary','native-oracle'][index]||row.success!==true||row.exit!==0||row.errors?.length!==0||row.result?.failures?.length!==0||row.result?.checks!==[157,47421][index])||
    !motion||motion.sha256!==motionSha256)throw Error('Exact composed motion source has no matching boundary/native-oracle proof');
 for(const pin of stage.value.pins)if(sha(fs.readFileSync(pin.source))!==pin.sha256||sha(fs.readFileSync(pin.target))!==pin.sha256)throw Error('Motion boundary proof source changed: '+pin.source);
 return {motionSha256,checks:{boundary:157,nativeOracle:47421},engineSha256:run.engine.sha256,proofPins:[proof.pin,stage.pin],scope:'Separate exact-source CPU boundary and retained original-native math proof; excluded from aggregate capsule fixture count'};
}

export function verifyMotionBoundaryProof(proof,motionSha256){
 if(proof?.motionSha256!==motionSha256||proof.checks?.boundary!==157||proof.checks?.nativeOracle!==47421||proof.proofPins?.length!==2)throw Error('Motion supplemental evidence differs');
 for(const pin of proof.proofPins)read(pin.file,pin.sha256);
}
