// File-only, pinned-parent capsule clone. Never launches an engine or edits main.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2];
if(!['native-dense-registry-v1','native-dense-registry-v2'].includes(label))throw Error('Exact reviewed fresh capsule label required');
const stage=path.join(project,'.cache/native-dense-area',label),destination=path.join(stage,'candidate');
if(fs.existsSync(stage))throw Error('Existing capsule/evidence is preserved');
const parentStage=path.join(project,'.cache/native-dense-area/native-dense-pair-v3');
const parentFile=path.join(parentStage,'candidate-sources.json'),parentBytes=fs.readFileSync(parentFile);
const parent=JSON.parse(parentBytes.toString('utf8').replace(/^\uFEFF/,''));
const parentSource=path.join(parentStage,'candidate');
if(parent.schema!==1||parent.variant!=='candidate'||parent.sourceProject!==parentSource||!Array.isArray(parent.sourcePins))throw Error('Parent capsule identity differs');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const focus='systems/native_render/focus_lighting.gd',candidatePath=path.join(project,'systems/native_render/focus_lighting_incremental_registry.gd');
const expectedBase='51c375c4e5c16e36d015443e5ee782a9fef8103d1d826382abfe79399d065be8';
const expectedCandidate='eb65c7db5d11b70b3123f2cfa27d5f42b9132a656f28cafc6d4eb9610a1aef4c';
const code=fs.readFileSync(candidatePath),mainFocus=path.join(project,focus);
if(hash(code)!==expectedCandidate||hash(fs.readFileSync(mainFocus))!==expectedBase)throw Error('Validated candidate/main Focus differs');
const validationPath=path.join(project,'reports/native-light-registry-retained-accepted-v1.json');
const validationBytes=fs.readFileSync(validationPath),validation=JSON.parse(validationBytes);
if(!validation.accepted||validation.checks!==225||validation.historyMapDetaches!==0||validation.candidateSha256!==expectedCandidate)throw Error('Required accepted candidate proof absent');
const childPath=(root,relative)=>{
 if(typeof relative!=='string'||path.isAbsolute(relative)||relative.includes(':')||relative.includes('\0'))throw Error('Invalid pinned relative path');
 const target=path.resolve(root,relative),rel=path.relative(root,target);
 if(!rel||rel.startsWith('..'+path.sep)||rel==='..'||path.isAbsolute(rel))throw Error('Pinned path escapes capsule');
 return target;
};
const names=new Set();let inputBytes=0,sourceBytes=0;const sourcePins=[],metadataLengthDifferences=[];
fs.mkdirSync(stage);fs.mkdirSync(destination);
for(const pin of parent.sourcePins){
 if(names.has(pin.relative))throw Error('Duplicate parent pin');names.add(pin.relative);
 const input=childPath(parentSource,pin.relative),original=fs.readFileSync(input);
 if(hash(original)!==pin.finalSha256)throw Error('Frozen parent differs: '+pin.relative);
 // Parent bytes describe capture-before-overlay in its preparer. The final
 // hash, also used by Root's runner, certifies the actual overlaid content.
 if(original.length!==pin.bytes)metadataLengthDifferences.push({relative:pin.relative,declaredBytes:pin.bytes,actualBytes:original.length});
 inputBytes+=original.length;
 if(pin.relative===focus&&pin.finalSha256!==expectedBase)throw Error('Parent Focus is not the accepted baseline');
 const value=pin.relative===focus?code:original,target=childPath(destination,pin.relative);
 fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,value,{flag:'wx'});
 const finalSha256=hash(value);if(hash(fs.readFileSync(target))!==finalSha256)throw Error('Child pin readback differs');
 sourceBytes+=value.length;sourcePins.push({relative:pin.relative,capturedSha256:pin.finalSha256,finalSha256,bytes:value.length});
}
if(!names.has(focus))throw Error('Parent file inventory lacks Focus');
const deltas=sourcePins.flatMap((pin,i)=>pin.finalSha256===parent.sourcePins[i].finalSha256?[]:[{relative:pin.relative,before:parent.sourcePins[i].finalSha256,after:pin.finalSha256}]);
if(deltas.length!==1||deltas[0].relative!==focus)throw Error('Expected exactly one copied Focus delta');
const privateUserData=path.join(stage,'candidate-user-data');fs.mkdirSync(privateUserData);
const capsule={...parent,run:label,sourceProject:destination,privateUserData,sourcePins,sourceBytes,
 scope:'Frozen parent candidate pins with ONE copied-only validated retained-registry Focus override. No main source, native output, rendering or performance promotion.',
 overrides:[...parent.overrides,{source:'copied-only validated retained registry candidate',relative:focus,sha256:expectedCandidate,sourcePath:candidatePath,baseSha256:expectedBase}],
 parentReceipt:{path:parentFile,sha256:hash(parentBytes),run:parent.run,sourceProject:parentSource,declaredBytes:parent.sourceBytes,actualBytes:inputBytes,metadataLengthDifferences},
 registryValidation:{path:validationPath,sha256:hash(validationBytes),checks:225,historyMapDetaches:0,promotedToMain:false}};
const capsuleFile=path.join(stage,'candidate-sources.json');fs.writeFileSync(capsuleFile,JSON.stringify(capsule,null,2)+'\n',{flag:'wx'});
// Final parent + child readback, including the six identical native outputs.
for(const [i,pin]of sourcePins.entries()){
 if(hash(fs.readFileSync(childPath(destination,pin.relative)))!==pin.finalSha256)throw Error('Final child pin differs');
 if(hash(fs.readFileSync(childPath(parentSource,pin.relative)))!==parent.sourcePins[i].finalSha256)throw Error('Parent changed during copy');
}
if(hash(fs.readFileSync(parentFile))!==hash(parentBytes)||hash(fs.readFileSync(mainFocus))!==expectedBase||hash(fs.readFileSync(candidatePath))!==expectedCandidate)throw Error('Parent/main/candidate changed during preparation');
const native=sourcePins.filter(p=>/^\.cache\/native-(?:window|kernel|resource-index)\//.test(p.relative));
if(native.length!==6||native.some(p=>p.capturedSha256!==p.finalSha256))throw Error('Six native output pins differ');
const proof={version:1,kind:'native-light-registry-retained-frozen-capsule',success:true,run:label,variant:'candidate',sourceProject:destination,privateUserData,
 parentReceipt:capsule.parentReceipt,registryValidation:capsule.registryValidation,sourcePins:sourcePins.length,sourceBytes,parentSourceBytes:inputBytes,deltas,
 nativeOutputs:native,engine:parent.engine,engineIdentityInherited:true,engineRehashed:false,
 guards:{parentPinsReadback:true,childPinsReadback:true,parentReceiptUnchanged:true,mainFocusUnchanged:true,candidateSourceUnchanged:true,onlyCopiedFocusDiffers:true,separateEmptyUserData:fs.readdirSync(privateUserData).length===0},
 capsuleReceipt:{path:capsuleFile,sha256:hash(fs.readFileSync(capsuleFile))},preparer:{path:fileURLToPath(import.meta.url),sha256:hash(fs.readFileSync(fileURLToPath(import.meta.url)))},
 engines:0,builds:0,servers:0,sockets:0,gpu:false,mainSourceEdits:0,profileKeyCopies:0,performanceAccepted:false};
const proofFile=path.join(stage,'preparation.json');fs.writeFileSync(proofFile,JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
const report=path.join(project,'reports/native-light-registry-retained-capsule-'+label.slice(-2)+'.json');fs.writeFileSync(report,JSON.stringify({...proof,preparation:{path:proofFile,sha256:hash(fs.readFileSync(proofFile))}},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,sourcePins:sourcePins.length,sourceBytes,deltas,sourceProject:destination,privateUserData,capsuleReceipt:proof.capsuleReceipt,report,reportSha256:hash(fs.readFileSync(report))}));
