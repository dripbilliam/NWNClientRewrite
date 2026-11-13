// Produces review artifacts only. Never changes the shared working tree.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^(?:weak-residency|material-init|combined-loading|cache-directory|first-placement|readonly-loan|job-digest|source-packet|material-pose|raster-selection|processor-identity|raster-child|static-actor-route|raster-write-queue|bulk-float-stream)-[a-z0-9-]+$/.test(label??''))throw Error('Prepared loading candidate label required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),manifestFile=path.join(stage,'manifest.json'),bytes=fs.readFileSync(manifestFile),manifest=JSON.parse(bytes),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const output=path.join(stage,'integration.patch'),planFile=path.join(stage,'integration.json');
if(fs.existsSync(output)||fs.existsSync(planFile))throw Error('Existing integration artifacts preserved');
let patch='# Isolated candidate '+label+'\n# Manifest SHA256 '+hash(bytes)+'\n# Review artifact only; no shared source has been changed by this exporter.\n';
const rows=[];
let baseline=manifest.baseline;
if(!baseline&&manifest.changes?.length){const parentBytes=fs.readFileSync(manifest.parent.file);if(hash(parentBytes)!==manifest.parent.sha256)throw Error('Parent source manifest differs');baseline=JSON.parse(parentBytes).project;}
for(const entry of manifest.changed?.length?manifest.changed:(manifest.changes??[])){
 const candidateFile=path.join(manifest.candidate,entry.relative),candidateBytes=fs.readFileSync(candidateFile);
 if(hash(candidateBytes)!==entry.after)throw Error('Candidate pin changed: '+entry.relative);
 if(entry.before===null){
  const lines=candidateBytes.toString().replaceAll('\r\n','\n').replace(/\n$/,'').split('\n');
  patch+='diff --git a/'+entry.relative+' b/'+entry.relative+'\nnew file mode 100644\n--- /dev/null\n+++ b/'+entry.relative+'\n@@ -0,0 +1,'+lines.length+' @@\n'+lines.map(v=>'+'+v).join('\n')+'\n';
 }else{
  const baselineFile=path.join(baseline,entry.relative);
  if(hash(fs.readFileSync(baselineFile))!==entry.before)throw Error('Baseline backup pin changed: '+entry.relative);
  const result=spawnSync('git',['diff','--no-index','--no-ext-diff','--',baselineFile,candidateFile],{encoding:'utf8',windowsHide:true,maxBuffer:4*1024*1024});
  if(result.error||result.status!==1)throw Error('Could not produce source diff: '+(result.error?.message??result.stderr));
  const lines=result.stdout.replaceAll('\r\n','\n').split('\n').map(v=>v.startsWith('diff --git ')?'diff --git a/'+entry.relative+' b/'+entry.relative:v.startsWith('--- ')?'--- a/'+entry.relative:v.startsWith('+++ ')?'+++ b/'+entry.relative:v);
  patch+=lines.join('\n');
 }
 rows.push({relative:entry.relative,before:entry.before,after:entry.after,candidateFile,verifiedBaselineBackup:entry.before===null?null:path.join(baseline,entry.relative)});
}
fs.writeFileSync(output,patch);
const plan={version:1,label,manifestFile,manifestSha256:hash(bytes),patchFile:output,patchSha256:hash(Buffer.from(patch)),changes:rows,integration:'Root-only, after matched graphics/loading acceptance. Compare each current shared file to before SHA256, back up its exact bytes, then copy the approved pinned candidate file. A mismatching current file needs manual merge; never replace concurrent changes. The patch is for review and may need line-ending normalization. This exporter performs no promotion.',sharedFilesChanged:0};
fs.writeFileSync(planFile,JSON.stringify(plan,null,2)+'\n');console.log(JSON.stringify({success:true,planFile,patchFile:output,changedFiles:rows.length}));
