'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'.cache/nwn72/path-slice-review-a');
const beforeFile=path.join(root,'.cache/nwn72/path-traversal-20261112a/before.gd');
const currentFile=path.join(root,'systems/network_motion.gd');
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const before=fs.readFileSync(beforeFile,'utf8'),current=fs.readFileSync(currentFile,'utf8');
assert.equal(sha(before),'717f9d432b74d3eb7d018c765705df3f63f605bb66b52d197374acea663f5310');
assert.equal(sha(current),'7b943610ba9765c8052e22fccdeaf2ca0e33f27eb86917db8ac44be5ab1d0762');
assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
function body(source,start,end){const a=source.indexOf(start),b=source.indexOf(end,a+start.length);assert(a>=0&&b>a,start);return source.slice(a,b)}
let candidate=before;
for(const [start,end] of [['static func distance(state: Dictionary, dt: int) -> Dictionary:','func step_path(state: Dictionary, amount: float) -> Dictionary:'],['func step_path(state: Dictionary, amount: float) -> Dictionary:','func support_snapshot() -> Dictionary:']]){
 const old=body(candidate,start,end),next=body(current,start,end);
 assert.equal(candidate.split(old).length,2,start);candidate=candidate.replace(old,next);
}
const candidateFile=path.join(out,'candidate.gd');fs.writeFileSync(candidateFile,candidate,{flag:'wx'});
const diff=spawnSync('git',['diff','--no-index','--',beforeFile,candidateFile],{cwd:root,encoding:'utf8',windowsHide:true});
assert.equal(diff.status,1);assert(diff.stdout.includes('state.path.slice'));
const lines=diff.stdout.split(/\r?\n/);lines[0]='diff --git a/systems/network_motion.gd b/systems/network_motion.gd';
for(let i=0;i<lines.length;i++){
 if(lines[i].startsWith('--- '))lines[i]='--- a/systems/network_motion.gd';
 if(lines[i].startsWith('+++ '))lines[i]='+++ b/systems/network_motion.gd';
}
const patchFile=path.join(root,'tools/nwn72/path-slice-only.patch');fs.writeFileSync(patchFile,lines.join('\n'),{flag:'wx'});
const receipt={issue:'NWN-72',scope:'Isolated path slice removal and cached path length in distance/step_path; no facing, diagnostics or live_world changes',beforeSha256:sha(before),candidateSha256:sha(candidate),currentSha256:sha(current),patchSha256:sha(fs.readFileSync(patchFile)),patch:'tools/nwn72/path-slice-only.patch',candidate:'.cache/nwn72/path-slice-review-a/candidate.gd',savedCapturedOracle:'.cache/nwn72/path-traversal-20261112a/captured-report.json',savedCapturedTimed:'.cache/nwn72/path-traversal-20261112a/captured-timed-a.json'};
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
