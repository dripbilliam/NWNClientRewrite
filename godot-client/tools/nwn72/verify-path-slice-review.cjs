'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn72/path-slice-review-a');
const info=JSON.parse(fs.readFileSync(path.join(scope,'receipt.json')));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const baseline=path.join(root,'.cache/nwn72/path-traversal-20261112a/before.gd');
const candidate=path.join(scope,'candidate.gd'),patch=path.join(root,info.patch);
assert.equal(sha(baseline),info.beforeSha256);assert.equal(sha(candidate),info.candidateSha256);
assert.equal(sha(patch),info.patchSha256);assert.equal(sha(path.join(root,'systems/network_motion.gd')),info.currentSha256);
const applied=path.join(scope,'apply-check-c');assert(!fs.existsSync(applied));
const target=path.join(applied,'systems/network_motion.gd');fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(baseline,target);
const init=spawnSync('git',['init','-q'],{cwd:applied,encoding:'utf8',windowsHide:true});assert.equal(init.status,0,init.stderr||init.stdout);
const config=spawnSync('git',['config','core.autocrlf','false'],{cwd:applied,encoding:'utf8',windowsHide:true});assert.equal(config.status,0,config.stderr||config.stdout);
for(const args of [['apply','--check',patch],['apply',patch]]){
 const r=spawnSync('git',args,{cwd:applied,encoding:'utf8',windowsHide:true});assert.equal(r.status,0,r.stderr||r.stdout);
}
assert.equal(sha(target),info.candidateSha256,'patch reproduces pinned candidate byte-for-byte');
const oracle=JSON.parse(fs.readFileSync(path.join(root,info.savedCapturedTimed)));
assert(oracle.passed&&oracle.checks===9);assert.equal(oracle.baseline_sha256,info.beforeSha256);assert.equal(oracle.motion_sha256,info.candidateSha256);
for(const row of oracle.cases){assert(row.legs.length===4);assert(row.legs.every(leg=>leg.state_sha256===row.legs[0].state_sha256));}
const receipt={issue:'NWN-72',passed:true,patchSha256:info.patchSha256,beforeSha256:info.beforeSha256,afterSha256:info.candidateSha256,oracleSha256:sha(path.join(root,info.savedCapturedTimed)),oracleChecks:oracle.checks,oracleRows:oracle.cases.map(row=>row.rows),scope:'Private patch apply and saved captured ABBA byte-identical state oracle; no FPS/full-client timing'};
fs.writeFileSync(path.join(scope,'verification.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
