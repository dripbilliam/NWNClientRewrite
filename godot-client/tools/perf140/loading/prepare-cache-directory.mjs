import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];
if(!/^cache-directory-[a-z0-9-]+$/.test(label??''))throw Error('Fresh cache-directory label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const parentFile=path.join(project,'.cache/native-render-trials/native-manual-light-input-movement-1793869228225/overlay.json');
const parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);
if(fs.existsSync(stage))throw Error('Existing candidate/evidence preserved');
const baseline=path.join(stage,'baseline'),candidate=path.join(stage,'candidate'),pins=[];
for(const target of [baseline,candidate]){
 fs.mkdirSync(target,{recursive:true});
 for(const pin of parent.trialPins){
  const bytes=fs.readFileSync(path.join(parent.rendererProject,pin.relative));
  if(hash(bytes)!==pin.sha256)throw Error('Frozen source changed: '+pin.relative);
  const file=path.join(target,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);
  if(target===baseline)pins.push({...pin});
 }
}
const relative='systems/native_data/prepared_cache.gd',original=fs.readFileSync(path.join(baseline,relative));
let value=original.toString().replaceAll('\r\n','\n');
const before='\tif DirAccess.make_dir_recursive_absolute(resolved) != OK: failure = "Native prepared cache is unavailable"; return false';
const after='\t# Recursive creation attempts every parent even for an existing directory.\n\t# One existence query avoids repeating that filesystem work per decoded asset.\n\t# A removed directory still follows the original creation/error path.\n\tif not DirAccess.dir_exists_absolute(resolved) and DirAccess.make_dir_recursive_absolute(resolved) != OK: failure = "Native prepared cache is unavailable"; return false';
if(value.split(before).length!==2)throw Error('Prepared-directory boundary changed');
value=value.replace(before,after);fs.writeFileSync(path.join(candidate,relative),value);
const fixture='tests/fixtures/native_perf140_loading_prepared_cache_before.gd';
for(const target of [baseline,candidate])fs.writeFileSync(path.join(target,fixture),original);
const changed=[{relative,before:hash(original),after:hash(Buffer.from(value))}];
const manifest={version:1,label,stage,baseline,candidate,parent:{file:parentFile,sha256:hash(parentBytes),rendererProject:parent.rendererProject},pins,fixture:{relative:fixture,sha256:hash(original)},changed,backup:[{file:path.join(baseline,relative),sha256:hash(original),verified:hash(fs.readFileSync(path.join(baseline,relative)))===hash(original)}],serverConnections:0,sharedNativeBuilds:0,scope:'Existing prepared-cache directory fast path only. Preserve workspace rejection, absent-directory creation, external deletion recovery, content identity, validation and disk data schema. No permanent directory memo.'};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({success:true,file,baseline,candidate,changed}));
