'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const project=path.resolve(__dirname,'../../..'),root=path.join(project,'.cache/native-render-gap'),stage=path.join(root,'scene/normal-integration-c');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),read=file=>JSON.parse(fs.readFileSync(file)),pin=file=>({file,sha256:sha(fs.readFileSync(file))});
const mf=path.join(stage,'manifest.json'),m=read(mf),acceptFile=path.join(stage,'functional-acceptance.json'),accept=read(acceptFile),queue=path.join(root,'queues/normal-full-c-abba-a'),comparisonFile=path.join(queue,'comparison.json'),comparison=read(comparisonFile);
if(!accept.success||accept.manifestSha256!==sha(fs.readFileSync(mf))||!comparison.success||comparison.rows.length!==4||comparison.rows.some(r=>!r.success||r.exit!==0))throw Error('Functional or repeated matched acceptance missing');
for(const row of comparison.rows)if(sha(fs.readFileSync(row.file))!==row.sha256)throw Error('Matched result drift');
const oldIdentity=require('../../native-feature-manifest.cjs').sourceIdentity(project);
if(oldIdentity.sha256!==m.mainBefore)throw Error('Installed source changed before promotion');
const candidateSelection=read(path.join(root,'replays/normal-full-candidate-c/selection.json'));
const dir=path.join(root,'promotions/normal-c-a');if(fs.existsSync(dir))throw Error('Existing promotion retained');
const specs=[...m.overlays.map(p=>({relative:p.relative,file:p.file,before:p.beforeSha256,after:p.sha256})),{relative:m.artifact.relative,file:path.join(m.candidate,m.artifact.relative),before:null,after:m.artifact.sha256,hardlink:true},{relative:m.artifact.proofRelative,file:path.join(m.candidate,m.artifact.proofRelative),before:null,after:m.artifact.proofSha256}];
const plans=[];
for(const p of specs){const target=path.resolve(project,p.relative),rel=path.relative(project,target);if(rel.startsWith('..')||path.isAbsolute(rel)||target===project)throw Error('Promotion target outside project');const before=fs.existsSync(target)?fs.readFileSync(target):null,after=fs.readFileSync(p.file);if((before?sha(before):null)!==p.before||sha(after)!==p.after)throw Error('Promotion source/target drift '+p.relative);plans.push({...p,target,beforeBytes:before,afterBytes:after});}
// Predict the application signature using the unchanged source-identity policy.
const replacements=new Map(plans.map(p=>[p.relative,p.after])),predicted=oldIdentity.files.map(p=>({...p,sha256:replacements.get(p.file)??p.sha256}));
if(sha(Buffer.from(JSON.stringify(predicted)))!==candidateSelection.mainSourceIdentity.sha256)throw Error('Candidate/application file-set signature differs');
fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'plan.json'),JSON.stringify({manifest:pin(mf),acceptance:pin(acceptFile),comparison:pin(comparisonFile),before:oldIdentity.sha256,expectedAfter:candidateSelection.mainSourceIdentity.sha256,files:plans.map(({relative,before,after,hardlink})=>({relative,before,after,hardlink:!!hardlink})),scope:'Exact accepted private-C bytes only. Back up every prior file; retain unrelated dirty work and original runtime/settings/assets.'},null,2)+'\n',{flag:'wx'});
for(const p of plans)if(p.beforeBytes){const backup=path.join(dir,'before',p.relative);fs.mkdirSync(path.dirname(backup),{recursive:true});fs.writeFileSync(backup,p.beforeBytes,{flag:'wx'});}
const applied=[];
try{
 for(const p of plans){const current=fs.existsSync(p.target)?sha(fs.readFileSync(p.target)):null;if(current!==p.before)throw Error('Concurrent target change '+p.relative);fs.mkdirSync(path.dirname(p.target),{recursive:true});if(p.hardlink)fs.linkSync(p.file,p.target);else{const temp=p.target+'.normal-c-'+process.pid;if(fs.existsSync(temp))throw Error('Existing temporary path');fs.writeFileSync(temp,p.afterBytes,{flag:'wx'});fs.renameSync(temp,p.target);}applied.push(p);}
 delete require.cache[require.resolve('../../native-feature-manifest.cjs')];const actual=require('../../native-feature-manifest.cjs').sourceIdentity(project);
 if(actual.sha256!==candidateSelection.mainSourceIdentity.sha256)throw Error('Installed signature differs from tested C source');
 for(const p of plans)if(sha(fs.readFileSync(p.target))!==p.after)throw Error('Installed file drift '+p.relative);
 const receipt={success:true,installed:true,createdAt:new Date().toISOString(),before:oldIdentity.sha256,after:actual.sha256,files:plans.length,engine:m.artifact.sha256,particle:m.nativeKernel.sha256,artifact:{relative:m.artifact.relative,proofRelative:m.artifact.proofRelative},functional:pin(acceptFile),matched:pin(comparisonFile),scope:'Exact tested C application/native/runtime installed. Existing source backed up, original runtime/assets/preferences retained. Post-install ordinary launcher/local authority verification remains required; native-original performance parity is not established.'};
 fs.writeFileSync(path.join(dir,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));
}catch(error){const conflicts=[];for(const p of applied.reverse()){if(sha(fs.readFileSync(p.target))!==p.after){conflicts.push(p.relative);continue;}if(p.beforeBytes)fs.writeFileSync(p.target,p.beforeBytes);else fs.unlinkSync(p.target);}fs.writeFileSync(path.join(dir,'failure.json'),JSON.stringify({success:false,error:error.stack,rolledBack:conflicts.length===0,conflicts},null,2)+'\n',{flag:'wx'});throw error;}
