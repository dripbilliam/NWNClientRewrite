'use strict';
// Apply only the already accepted header and identical tested binary. Back up
// every destination, preserve receipts, and leave all launch options unchanged.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),[label,mode]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!['--check','--apply'].includes(mode))throw Error('Explicit experiment label and --check|--apply required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','particle-loop-'+label),hash=b=>crypto.createHash('sha256').update(b).digest('hex'),read=file=>JSON.parse(fs.readFileSync(file));
const acceptanceFile=path.join(root,'acceptance.json'),a=read(acceptanceFile),source=read(path.join(root,'source-proof.json')),buildFile=path.join(root,'candidate/build/build-proof.json'),b=read(buildFile),identity=require('../native-feature-manifest.cjs').sourceIdentity;
if(!a.accepted||a.mainSource!==source.mainSource||a.candidateBinarySha256!==b.binarySha256||identity(project).sha256!==source.mainSource)throw Error('Accepted cohort/main identity differs');
const header='native/particle_presentation.hpp',dll='.cache/native-kernel/nwn-particle-kernel.dll',manifest='.cache/native-kernel/build-manifest.json',old=read(path.join(project,manifest));
for(const [relative,sha256] of Object.entries(old.sources))if(hash(fs.readFileSync(path.join(project,relative)))!==sha256)throw Error('Installed native source differs: '+relative);
if(hash(fs.readFileSync(path.join(project,header)))!==source.control||hash(fs.readFileSync(path.join(project,dll)))!==source.installedBinary)throw Error('Installed particle baseline differs');
const newHeader=fs.readFileSync(path.join(root,'candidate',header)),newDll=fs.readFileSync(path.join(root,'candidate/build/nwn-particle-kernel.dll'));
if(hash(newHeader)!==source.candidate||hash(newDll)!==b.binarySha256)throw Error('Accepted private payload differs');
for(const pin of b.sourcePins){const bytes=fs.readFileSync(path.join(root,'candidate',pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen build input changed');if(pin.relative!==header&&hash(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256)throw Error('Unexpected native source drift: '+pin.relative);}
// sources also supplies the normal ensure script's future rebuild inputs.
// Keep that builder's unchanged hash while recording the actual private
// compiler invocation separately in privateBuildProof.
const next=structuredClone(old);next.binarySha256=b.binarySha256;next.sources[header]=source.candidate;next.sources['tools/native-particle-loop/build-private.ps1']=b.builderSha256;
if(hash(fs.readFileSync(path.join(project,'tools/native-particle-loop/build-private.ps1')))!==b.builderSha256)throw Error('Actual private builder changed');
next.privateBuildProof={file:buildFile,sha256:hash(fs.readFileSync(buildFile))};next.acceptance={file:acceptanceFile,sha256:hash(fs.readFileSync(acceptanceFile))};next.scope='Native particle bookkeeping gain accepted in repeated matched private graphical replays and exact state/geometry/order/lifetime checks on verified and official engines. Same tested binary installed; no default render/runtime/thread/light/loading policy change. Arelith and default-configuration FPS remain separate live evidence.';
const outputs=new Map([[header,newHeader],[dll,newDll],[manifest,Buffer.from(JSON.stringify(next,null,2)+'\n')]]);
const plan={version:1,ready:true,mainBefore:source.mainSource,files:[...outputs].map(([relative,bytes])=>({relative,before:hash(fs.readFileSync(path.join(project,relative))),after:hash(bytes)})),acceptance:{file:acceptanceFile,sha256:hash(fs.readFileSync(acceptanceFile))},launchOptionWrites:0,processStarts:0};
if(mode==='--check'){console.log(JSON.stringify(plan));process.exit(0);}
const backup=path.join(root,'promotion');if(fs.existsSync(backup))throw Error('Existing promotion/backup preserved');fs.mkdirSync(backup);
for(const [relative]of outputs){const dest=path.join(backup,'before',relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(project,relative),dest,fs.constants.COPYFILE_EXCL);}
fs.writeFileSync(path.join(backup,'plan.json'),JSON.stringify(plan,null,2)+'\n',{flag:'wx'});
const changed=[];
try{
 for(const [relative,bytes]of outputs){const dest=path.join(project,relative),expected=plan.files.find(r=>r.relative===relative).before;if(hash(fs.readFileSync(dest))!==expected)throw Error('Concurrent destination change: '+relative);const incoming=dest+'.incoming-particle-'+label;fs.writeFileSync(incoming,bytes,{flag:'wx'});if(hash(fs.readFileSync(dest))!==expected)throw Error('Concurrent destination change before rename: '+relative);fs.renameSync(incoming,dest);changed.push(relative);}
 for(const [relative,bytes]of outputs)if(hash(fs.readFileSync(path.join(project,relative)))!==hash(bytes))throw Error('Installed payload verification failed');
 const result={...plan,success:true,mainAfter:identity(project).sha256,installedBinarySha256:b.binarySha256,scope:next.scope};fs.writeFileSync(path.join(backup,'result.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
}catch(error){
 const conflicts=[];for(const relative of changed.reverse()){const dest=path.join(project,relative);if(hash(fs.readFileSync(dest))!==hash(outputs.get(relative))){conflicts.push(relative);continue;}fs.copyFileSync(path.join(backup,'before',relative),dest);}
 fs.writeFileSync(path.join(backup,'failure.json'),JSON.stringify({success:false,error:error.message,restored:changed.filter(r=>!conflicts.includes(r)),conflicts},null,2)+'\n',{flag:'wx'});throw error;
}
