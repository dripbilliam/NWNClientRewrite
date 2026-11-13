'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn72/diagnostics-review-a');
const info=JSON.parse(fs.readFileSync(path.join(scope,'receipt.json')));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const baseline=path.join(root,'.cache/nwn72/coordinator-source/network_motion.gd');
const candidate=path.join(scope,'candidate.gd'),patch=path.join(root,info.patch);
for(const [file,pin] of [[baseline,info.beforeSha256],[candidate,info.candidateSha256],[patch,info.patchSha256],[path.join(root,'systems/network_motion.gd'),info.currentSha256]])assert.equal(sha(file),pin);
const applied=path.join(scope,'apply-check');assert(!fs.existsSync(applied));
const target=path.join(applied,'systems/network_motion.gd');fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(baseline,target);
for(const args of [['init','-q'],['config','core.autocrlf','false'],['apply','--check',patch],['apply',patch]]){
 const r=spawnSync('git',args,{cwd:applied,encoding:'utf8',windowsHide:true});assert.equal(r.status,0,r.stderr||r.stdout);
}
assert.equal(sha(target),info.candidateSha256);
const test=JSON.parse(fs.readFileSync(path.join(scope,'headless-a/report.json')));
assert(test.passed&&test.checks===13);
for(const c of test.cases){assert(c.legs.every(x=>x.state_sha256===c.legs[0].state_sha256));assert(c.legs[0].evaluation.updates>0&&c.legs[1].evaluation.updates===0)}
const receipt={issue:'NWN-72',passed:true,patchSha256:info.patchSha256,beforeSha256:info.beforeSha256,afterSha256:info.candidateSha256,headlessReportSha256:sha(path.join(scope,'headless-a/report.json')),checks:test.checks,rows:test.cases.map(c=>c.rows),scope:'Isolated patch applies byte-for-byte and captured motion state is unchanged with diagnostics off; no FPS'};
fs.writeFileSync(path.join(scope,'verification.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
