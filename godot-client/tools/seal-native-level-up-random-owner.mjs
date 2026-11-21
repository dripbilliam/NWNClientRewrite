import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),directory=path.join(project,'.cache/level-up-random-owner/sealed-v1'),stage=path.join(directory,'checkpoint'),reportPath=path.join(project,'reports/native-level-up-random-owner-v1.json');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),json=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
if(process.argv.includes('--compress')){
 const report=json(reportPath),manifest=path.join(stage,'manifest.json');if(report.archive.sha256!==hash(fs.readFileSync(manifest)))throw Error('Accepted directory identity changed');
 for(const row of json(manifest))if(hash(fs.readFileSync(path.join(stage,row.path)))!==row.sha256)throw Error('Accepted checkpoint bytes changed');
 const zip=path.join(directory,'native-level-up-random-owner-v1.zip');if(fs.existsSync(zip))throw Error('Existing ZIP preserved');
 const script='import sys,pathlib,zipfile,hashlib,json\nr=pathlib.Path(sys.argv[1]);p=pathlib.Path(sys.argv[2])\nwith zipfile.ZipFile(p,"x",zipfile.ZIP_DEFLATED,6) as z:\n for f in sorted(r.rglob("*")):\n  if f.is_file():z.write(f,f.relative_to(r).as_posix())\nwith zipfile.ZipFile(p) as z:\n m=json.loads(z.read("manifest.json"))\n assert len(z.namelist())==len(m)+1\n for a in m:assert hashlib.sha256(z.read(a["path"])).hexdigest()==a["sha256"]\nprint(json.dumps({"entries":len(m)+1,"readback":True}))\n';
 const child=spawnSync('C:/Users/Niflheim/AppData/Local/Programs/Python/Python312/python.exe',['-c',script,stage,zip],{windowsHide:true,encoding:'utf8',timeout:30000});if(child.status!==0||child.error)throw Error(child.stderr||child.error?.message||'Archive verification failed');
 report.compressedArchive={path:path.relative(project,zip).replaceAll('\\','/'),format:'zip-deflate',sha256:hash(fs.readFileSync(zip)),...JSON.parse(child.stdout)};fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report.compressedArchive));process.exit(0);
}
if(fs.existsSync(directory))throw Error('Existing checkpoint preserved');
const entries=new Map(),acceptedFiles=new Map(),receipts=[];
function put(name,bytes){if(path.isAbsolute(name)||name.split(/[\\/]/).includes('..')||entries.has(name))throw Error('Invalid/duplicate checkpoint path');const file=path.join(stage,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);entries.set(name,hash(bytes));}
for(const [category,label,scope]of [
 ['level-up-class-metadata','native-level-up-class-metadata-v1','metadata'],
 ['level-up-rule-publication','native-level-up-rule-publication-v3','metadata'],
 ['level-up-random-owner','native-level-up-random-owner-v1','random'],
 ['level-up-random-owner','native-level-up-random-runtime-v2','random'],
 ['level-up-rule-publication','native-level-up-rule-runtime-v6','random']
]){
 const base=path.join(project,'.cache',category,label),file=path.join(base,'proof.json'),proof=json(file);
 if(!proof.success||!proof.cleanEngine||proof.changedInputs.length||(proof.changedCopies??[]).length)throw Error('Unaccepted receipt');
 for(const row of proof.inputs){const source=path.join(base,'inputs',row.path),bytes=fs.readFileSync(source);if(hash(bytes)!==row.sha256)throw Error('Accepted copied input changed');put('cases/'+label+'/inputs/'+row.path,bytes);const prior=acceptedFiles.get(row.path);if(prior&&prior.sha256!==row.sha256)throw Error('Different selected accepted versions of '+row.path);acceptedFiles.set(row.path,{source,sha256:row.sha256});}
 for(const name of ['proof.json','result.json','engine.log','stdout.log','stderr.log'])put('cases/'+label+'/'+name,fs.readFileSync(path.join(base,name)));
 const resources=path.join(base,'result.json.resources');if(fs.existsSync(resources))for(const name of fs.readdirSync(resources)){const resource=path.join(resources,name);if(!fs.statSync(resource).isFile())throw Error('Unexpected generated resource directory');put('cases/'+label+'/resources/'+name,fs.readFileSync(resource));}
 receipts.push({name:label,scope,checks:proof.checks,inputs:proof.inputs.length,path:'.cache/'+category+'/'+label+'/proof.json',sha256:hash(fs.readFileSync(file))});
}
const before=[];
for(const [category,label]of [['level-up-class-metadata','before-publication-v1'],['level-up-random-owner','before-runtime-v1']]){
 const base=path.join(project,'.cache',category,label);put('before/'+label+'/before.json',fs.readFileSync(path.join(base,'before.json')));before.push('.cache/'+category+'/'+label+'/before.json');
 for(const row of json(path.join(base,'before.json'))){const old=path.join(base,path.basename(row.path)),accepted=acceptedFiles.get(row.path);if(hash(fs.readFileSync(old))!==row.sha256||!accepted)throw Error('Dirty before/accepted pair unavailable');put('before/'+label+'/'+row.path,fs.readFileSync(old));const diff=spawnSync('git',['diff','--no-index','--',old,accepted.source],{windowsHide:true,encoding:'utf8'});if(![0,1].includes(diff.status)||diff.error)throw Error('Cannot create exact accepted scoped diff');put('diff/'+label+'/'+row.path+'.patch',Buffer.from(diff.stdout));}
}
for(const name of ['NATIVE-LEVEL-UP-RANDOM-OWNER.md','NATIVE-LEVEL-UP-RANDOM-OWNER-PLAN.md','NATIVE-LEVEL-UP-CLASS-EXTRA-FIELDS.md'])put('docs/'+name,fs.readFileSync(path.join(project,name)));
for(const name of ['native-level-up-class-extra-fields-source-v1.json','native-level-up-rng-ownership-followup-v1.json','native-level-up-summary-cancel-source-v1.json'])put('source/'+name,fs.readFileSync(path.join(project,'reports',name)));
put('tools/seal-native-level-up-random-owner.mjs',fs.readFileSync(fileURLToPath(import.meta.url)));
const owned=['systems/native_level_up.gd','systems/native_level_up_runtime.gd','systems/native_data/level_up_rule_publication.gd','systems/native_data/level_up_class_metadata.gd','systems/native_data/native_client_random.gd','systems/native_data/level_up_hit_die_owner.gd'].map(file=>({path:file,sha256:acceptedFiles.get('godot-client/'+file)?.sha256}));if(owned.some(row=>!row.sha256))throw Error('Accepted owned source missing');
const report={productionApplied:true,fullLevelUpAccepted:false,checks:receipts.reduce((sum,row)=>sum+row.checks,0),metadataChecks:620,randomChecks:882,counting:'Scoped assertion instances; overlap is explicit. Current runtime53 counted once in random coverage.',receipts,ownedSources:owned,before,currentSourceEqualityClaim:false,sourcePolicy:'Archive and scoped diffs use immutable accepted copies; later approved current-worktree edits are outside this checkpoint.',seedAdaptation:'Once per native app lifetime, Godot application uptime milliseconds replace original Win32 system-uptime GetTickCount. Original DWORD recurrence/15-bit return preserved; no claim of complete112-caller original history.',scope:'Mode1-only advancement BYTE projection and native app-lifetime random owner, per-Summary/current-module/token lifecycle, actual level4+ native controls and valid current proposal/rejection/Cancel. Authored received snapshots/replies; no original-local level-up or pixel acceptance.',remaining:['Feats/Spells Recommended','Native late-S9c waiting/start','Native title/presentation and special valid class paths','Original-local level/HP result and received mutation'],serverConnections:0,nativeBuilds:0,gpu:false};
put('report.json',Buffer.from(JSON.stringify(report,null,2)+'\n'));const manifest=[...entries].map(([file,sha256])=>({path:file,sha256})),manifestFile=path.join(stage,'manifest.json');fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');for(const row of json(manifestFile))if(hash(fs.readFileSync(path.join(stage,row.path)))!==row.sha256)throw Error('Checkpoint readback mismatch');report.archive={path:path.relative(project,stage).replaceAll('\\','/'),format:'verified-directory',sha256:hash(fs.readFileSync(manifestFile)),entries:entries.size+1,readback:true};fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks:report.checks,metadataChecks:report.metadataChecks,randomChecks:report.randomChecks,archive:report.archive,ownedSources:owned}));
