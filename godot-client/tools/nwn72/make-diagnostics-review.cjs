'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'.cache/nwn72/diagnostics-review-a');
const baselineFile=path.join(root,'.cache/nwn72/coordinator-source/network_motion.gd'),currentFile=path.join(root,'systems/network_motion.gd');
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const baseline=fs.readFileSync(baselineFile,'utf8'),current=fs.readFileSync(currentFile,'utf8');
assert.equal(sha(baseline),'ce9321701128554f145e1e326e22b65715927ea065cab63972d546e6c0732461');
assert.equal(sha(current),'7b943610ba9765c8052e22fccdeaf2ca0e33f27eb86917db8ac44be5ab1d0762');
assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
let candidate=baseline;
const once=(old,next)=>{assert.equal(candidate.split(old).length,2,old);candidate=candidate.replace(old,next)};
const span=(source,start,end)=>{const a=source.indexOf(start),b=source.indexOf(end,a+start.length);assert(a>=0&&b>a,start);return source.slice(a,b)};
once('var evaluation_stats:=','var collect_diagnostics:=true\nvar evaluation_stats:=');
once('\tvar evaluated:=0;','\tvar diagnostics:=collect_diagnostics\n\tvar evaluated:=0;');
once('\t\tevaluated+=1\n\t\tif state.active:active_rows+=1\n\t\tif int(state.correction)!=0:correcting+=1',
     '\t\tif diagnostics:\n\t\t\tevaluated+=1\n\t\t\tif state.active:active_rows+=1\n\t\t\tif int(state.correction)!=0:correcting+=1');
once('if facing_target!=0x7f000000 and facing_target!=int(id):targeted+=1','if diagnostics and facing_target!=0x7f000000 and facing_target!=int(id):targeted+=1');
once('state.orientation=Vector3(target.x,target.y,0);state.facingTurn=null;settled+=1;cardinal_rows+=1',
     'state.orientation=Vector3(target.x,target.y,0);state.facingTurn=null\n\t\t\t\tif diagnostics:\n\t\t\t\t\tsettled+=1\n\t\t\t\t\tcardinal_rows+=1');
once('state.orientation=normalized32(desired);state.facingTurn=null;settled+=1',
     'state.orientation=normalized32(desired);state.facingTurn=null\n\t\t\t\tif diagnostics:settled+=1');
once('state.facingTurn=null;settled+=1;deadband_rows+=1',
     'state.facingTurn=null\n\t\t\t\tif diagnostics:\n\t\t\t\t\tsettled+=1\n\t\t\t\t\tdeadband_rows+=1');
once('\t\tfull_steps+=1','\t\tif diagnostics:full_steps+=1');
const start='\tevaluation_stats.updates+=1;',end='\tif notify and not pending.is_empty():';
once(span(candidate,start,end),span(current,'\tif diagnostics:\n\t\tevaluation_stats.updates+=1',end));
const candidateFile=path.join(out,'candidate.gd');fs.writeFileSync(candidateFile,candidate,{flag:'wx'});
const diff=spawnSync('git',['diff','--no-index','--',baselineFile,candidateFile],{cwd:root,encoding:'utf8',windowsHide:true});assert.equal(diff.status,1);
const lines=diff.stdout.split(/\r?\n/);lines[0]='diff --git a/systems/network_motion.gd b/systems/network_motion.gd';
for(let i=0;i<lines.length;i++){
 if(lines[i].startsWith('--- '))lines[i]='--- a/systems/network_motion.gd';
 if(lines[i].startsWith('+++ '))lines[i]='+++ b/systems/network_motion.gd';
}
const patchFile=path.join(root,'tools/nwn72/diagnostics-gate-only.patch');fs.writeFileSync(patchFile,lines.join('\n'),{flag:'wx'});
const receipt={issue:'NWN-72',scope:'Isolated optional motion diagnostics counter gate; default true preserves direct diagnostic behavior; normal LiveWorld producer sets this false when FrameProfile disabled',beforeSha256:sha(baseline),candidateSha256:sha(candidate),currentSha256:sha(current),patchSha256:sha(fs.readFileSync(patchFile)),patch:'tools/nwn72/diagnostics-gate-only.patch',candidate:'.cache/nwn72/diagnostics-review-a/candidate.gd',savedComponentOracle:'.cache/nwn72/diagnostics-component-abba-a.json'};
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
