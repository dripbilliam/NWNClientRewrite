'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),helper=require('../native-production-selection.cjs'),identity=require('../native-feature-manifest.cjs').sourceIdentity;
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function pin(file,expected){if(!/^[a-f0-9]{64}$/.test(expected??'')||sha(fs.readFileSync(file))!==expected)throw Error('Private movement pin differs: '+file);}
async function readSelection(file,expected){
 pin(file,expected);const s=JSON.parse(fs.readFileSync(file));
 if(s.version!==3||s.kind!=='private-movement-review-selection'||s.production!==false||s.experimental!==true||!['control','candidate'].includes(s.movementReview?.variant)||path.resolve(s.sourceProject)!==path.join(path.dirname(path.resolve(file)),'project'))throw Error('Private movement selection policy differs');
 const base=await helper.readProductionSelection(s.movementReview.base.file,s.movementReview.base.sha256);
 for(const field of ['options','runtime','engine','engineArguments','renderThread','flags','environment','featureSelection','performanceOptions','renderConfiguration','loadingPipeline','profiling','preferences','cameraPolicy'])if(JSON.stringify(s[field])!==JSON.stringify(base[field]))throw Error('Private movement configuration differs: '+field);
 helper.validatePins(s);helper.validatePreferencePins(s);
 if(identity(s.sourceProject).sha256!==s.mainSourceIdentity.sha256)throw Error('Private movement source identity differs');
 for(const name of ['source','focused'])pin(s.movementReview[name].file,s.movementReview[name].sha256);
 if(JSON.parse(fs.readFileSync(s.movementReview.focused.file)).success!==true)throw Error('Private focused correctness failed');
 if(s.movementReview.variant==='control'&&s.mainSourceIdentity.sha256!==base.mainSourceIdentity.sha256)throw Error('Control is not byte-exact current application');
 pin(s.particleLoop.module.file,s.particleLoop.module.sha256);
 return {...s,evidence:{file:path.resolve(file),sha256:expected,sourceProject:s.sourceProject,sourceSignature:s.mainSourceIdentity.sha256,engineSha256:s.runtime.executableSha256,particleSha256:s.particleLoop.module.sha256,flags:[...s.flags],production:false,experimental:'isolated-movement-review',scope:'Current client control versus isolated planner prototype; main source/defaults unchanged.'}};
}
function runtimeFiles(s){return {movementReplayAdapter:__filename,movementSourceProof:s.movementReview.source.file,movementFocusedProof:s.movementReview.focused.file,movementBaseSelection:s.movementReview.base.file};}
function verifyNative(s,n){
 const m=n?.world?.pending_appearance_schedule,errors=[];
 if(s.movementReview.variant==='candidate'&&!(m?.enumerations>0&&m.rebuilds>0&&m.writer_depth===0&&m.retired===false))errors.push('Actual candidate sparse planner activation/current scope was not observed');
 if(s.movementReview.variant==='control'&&m!==undefined)errors.push('Current client control unexpectedly selected the private prototype');
 return {status:errors.length?'rejected':'observed',errors,variant:s.movementReview.variant,metadata:m??null,scope:'Actual selected planner evidence only; performance, visual review and lifecycle gates remain separate.'};
}
module.exports={readSelection,runtimeFiles,verifyNative};
