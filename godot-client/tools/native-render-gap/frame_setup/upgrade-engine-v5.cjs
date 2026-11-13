'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const project=path.resolve(__dirname,'../../..'),stage=path.join(project,'.cache/native-render-gap/engine');
const manifest=path.join(stage,'manifest.json'),m=JSON.parse(fs.readFileSync(manifest)),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
if(m.revision!=='4.1')throw Error('Expected reviewed V4.1 source');
for(const p of m.patches)if(sha(fs.readFileSync(path.join(m.source,p.relative)))!==p.afterSha256)throw Error('Patch drift '+p.relative);
for(const p of m.modules)if(sha(fs.readFileSync(path.join(m.source,p.relative)))!==p.sha256)throw Error('Module drift '+p.relative);
const proposal=path.join(project,'.cache/native-render-gap/original/frame-pacing/source-b'),proof=path.join(proposal,'receipt.json'),r=JSON.parse(fs.readFileSync(proof));
const changes=[];
for(const p of r.pins){
 const target=path.join(m.source,p.relative),before=fs.readFileSync(target),after=fs.readFileSync(path.join(proposal,p.relative));
 if(sha(before)!==p.inputSha256||sha(after)!==p.outputSha256)throw Error('Pacing proposal drift '+p.relative);
 changes.push({relative:p.relative,target,before,after});
}
for(const p of r.modules){const after=fs.readFileSync(path.join(proposal,p.relative));if(sha(after)!==p.sha256)throw Error('Module proposal drift');const target=path.join(m.source,p.relative);if(fs.existsSync(target))throw Error('Pacing module already exists');changes.push({relative:p.relative,target,before:null,after});}
const saved=path.join(stage,'upgrade-v5');if(fs.existsSync(saved))throw Error('Existing upgrade preserved');fs.mkdirSync(saved,{recursive:true});fs.copyFileSync(manifest,path.join(saved,'previous-manifest.json'));
for(const c of changes){
 if(c.before){const f=path.join(saved,'before',c.relative);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,c.before,{flag:'wx'});}
 fs.mkdirSync(path.dirname(c.target),{recursive:true});fs.writeFileSync(c.target,c.after);
 if(c.relative.startsWith('modules/'))m.modules.push({relative:c.relative,sha256:sha(c.after)});
 else {const old=m.patches.find(p=>p.relative===c.relative);if(old)old.afterSha256=sha(c.after);else m.patches.push({relative:c.relative,beforeSha256:sha(c.before),afterSha256:sha(c.after)});}
}
m.revision=5;m.createdAt=new Date().toISOString();m.pacingProposal={file:proof,sha256:sha(fs.readFileSync(proof))};m.featuresDefaultOff.push('frame-pacing-metrics');m.upgradeV5='Default-off bounded numeric main/render wall chronology and own-thread CPU windows, cold policy snapshot; no settings/focus/priority/affinity writes.';
fs.writeFileSync(manifest,JSON.stringify(m,null,2)+'\n');fs.writeFileSync(path.join(saved,'receipt.json'),JSON.stringify({success:true,changes:changes.map(c=>({relative:c.relative,before:c.before?sha(c.before):null,after:sha(c.after)})),manifestSha256:sha(fs.readFileSync(manifest))},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,changes:changes.length,source:m.source}));
