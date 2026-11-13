import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const directory=path.join(project,'.cache/level-up-recommended/sealed-v1'),stage=path.join(directory,'checkpoint');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const reportPath=path.join(project,'reports/native-level-up-recommended-v1.json');
if(process.argv.includes('--compress')){
 const report=json(reportPath),manifest=path.join(stage,'manifest.json');
 if(report.archive?.format!=='verified-directory'||report.archive.sha256!==hash(fs.readFileSync(manifest)))throw Error('Accepted directory identity changed');
 for(const row of json(manifest))if(hash(fs.readFileSync(path.join(stage,row.path)))!==row.sha256)throw Error('Accepted checkpoint bytes changed');
 const zip=path.join(directory,'native-level-up-recommended-v1.zip');if(fs.existsSync(zip))throw Error('Existing compressed checkpoint preserved');
 const script='import sys,pathlib,zipfile,hashlib,json\nr=pathlib.Path(sys.argv[1]);p=pathlib.Path(sys.argv[2])\nwith zipfile.ZipFile(p,"x",zipfile.ZIP_DEFLATED,6) as z:\n for f in sorted(r.rglob("*")):\n  if f.is_file():z.write(f,f.relative_to(r).as_posix())\nwith zipfile.ZipFile(p) as z:\n m=json.loads(z.read("manifest.json"))\n assert len(z.namelist())==len(m)+1\n for a in m:assert hashlib.sha256(z.read(a["path"])).hexdigest()==a["sha256"]\nprint(json.dumps({"entries":len(m)+1,"readback":True}))\n';
 const child=spawnSync('C:/Users/Niflheim/AppData/Local/Programs/Python/Python312/python.exe',['-c',script,stage,zip],{windowsHide:true,encoding:'utf8',timeout:30000});
 if(child.status!==0||child.error)throw Error(child.stderr||child.error?.message||'Archive verification failed');
 report.compressedArchive={path:path.relative(project,zip).replaceAll('\\','/'),format:'zip-deflate',sha256:hash(fs.readFileSync(zip)),...JSON.parse(child.stdout)};fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report.compressedArchive));process.exit(0);
}
if(fs.existsSync(directory))throw Error('Existing accepted checkpoint preserved');
const entries=new Map();
function put(relative,bytes){
 if(path.isAbsolute(relative)||relative.split(/[\\/]/).includes('..'))throw Error('Invalid checkpoint path');
 if(entries.has(relative))throw Error('Duplicate checkpoint path '+relative);
 const target=path.join(stage,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);entries.set(relative,hash(bytes));
}
const specs=[
 ['level-up-recommended','native-level-up-recommendation-context-v1'],
 ['level-up-recommended','native-level-up-recommended-existing-v3'],
 ['level-up-recommended','native-level-up-recommended-later-v1'],
 ['level-up-recommended','native-level-up-recommended-missing-v1'],
 ['level-up-recommended','native-level-up-recommended-empty-v1'],
 ['level-up-recommended','native-level-up-recommended-failed-v1'],
 ['level-up-recommended','native-level-up-recommended-package-failed-v1'],
 ['level-up-rule-publication','native-level-up-rule-publication-v2'],
 ['level-up-rule-publication','native-level-up-rule-runtime-v3'],
 ['level-up-recommended','native-level-up-recommendation-catalog-v3',true],
 ['level-up-rule-publication','native-level-up-rule-runtime-v4',true],
];
const receipts=[],currentProduction=new Map();
for(const [category,label,current=false]of specs){
 const base=path.join(project,'.cache',category,label),proofPath=path.join(base,'proof.json'),proof=json(proofPath),currentDrift=[];
 if(!proof.success||!proof.cleanEngine||proof.changedInputs.length||(proof.changedCopies??[]).length)throw Error('Unaccepted case '+label);
 for(const row of proof.inputs){
  const bytes=fs.readFileSync(path.join(base,'inputs',row.path));if(hash(bytes)!==row.sha256)throw Error('Accepted copy changed '+row.path);
  put('cases/'+label+'/inputs/'+row.path,bytes);
  const currentFile=path.join(workspace,row.path),same=fs.existsSync(currentFile)&&hash(fs.readFileSync(currentFile))===row.sha256;
  if(!same)currentDrift.push(row.path);
  if(current&&row.path.startsWith('godot-client/systems/')){
   const prior=currentProduction.get(row.path);if(prior&&prior!==row.sha256)throw Error('Accepted producer versions differ '+row.path);
   if(!same)throw Error('Production changed after accepted cases '+row.path);
   currentProduction.set(row.path,row.sha256);
  }
 }
 for(const name of ['proof.json','result.json','engine.log','stdout.log','stderr.log'])put('cases/'+label+'/'+name,fs.readFileSync(path.join(base,name)));
 const resources=path.join(base,'result.json.resources');
 if(fs.existsSync(resources))for(const name of fs.readdirSync(resources)){
  const file=path.join(resources,name);if(!fs.statSync(file).isFile())throw Error('Unexpected generated resource directory');put('cases/'+label+'/resources/'+name,fs.readFileSync(file));
 }
 receipts.push({name:label,path:'.cache/'+category+'/'+label+'/proof.json',sha256:hash(fs.readFileSync(proofPath)),checks:proof.checks,inputs:proof.inputs.length,current,currentDrift});
}
const rejected=[];
for(const label of ['native-level-up-recommended-existing-v1','native-level-up-recommended-existing-v2','native-level-up-recommendation-catalog-v1','native-level-up-recommendation-catalog-v2']){
 const base=path.join(project,'.cache/level-up-recommended',label),proof=json(path.join(base,'proof.json'));if(proof.success)throw Error('Rejected receipt unexpectedly accepted');
 for(const row of proof.inputs){const bytes=fs.readFileSync(path.join(base,'inputs',row.path));if(hash(bytes)!==row.sha256)throw Error('Rejected evidence changed');put('rejected/'+label+'/inputs/'+row.path,bytes);}
 for(const name of ['proof.json','result.json','engine.log','stdout.log','stderr.log'])if(fs.existsSync(path.join(base,name)))put('rejected/'+label+'/'+name,fs.readFileSync(path.join(base,name)));
 rejected.push({name:label,checks:proof.checks,cleanEngine:proof.cleanEngine,failures:proof.failures,error:proof.error});
}
const backups=['before-attributes-skills-v1','before-catalog-guard-v1'];
for(const label of backups){
 const before=path.join(project,'.cache/level-up-recommended',label);put('before/'+label+'/before.json',fs.readFileSync(path.join(before,'before.json')));
 for(const row of json(path.join(before,'before.json'))){
  const old=path.join(before,label==='before-attributes-skills-v1'?path.basename(row.path):row.path),current=path.join(workspace,row.path);
  if(hash(fs.readFileSync(old))!==row.sha256)throw Error('Dirty before backup changed '+row.path);put('before/'+label+'/'+row.path,fs.readFileSync(old));
  const diff=spawnSync('git',['diff','--no-index','--',old,current],{windowsHide:true,encoding:'utf8'});
  if(![0,1].includes(diff.status)||diff.error)throw Error('Cannot read scoped diff');put('diff/'+label+'/'+row.path+'.patch',Buffer.from(diff.stdout));
 }
}
for(const name of ['NATIVE-LEVEL-UP-RECOMMENDED.md','NATIVE-LEVEL-UP-CLASS-PUBLICATION.md','NATIVE-LEVEL-UP-SOURCE.md'])put('docs/'+name,fs.readFileSync(path.join(project,name)));
for(const name of ['native-level-up-attributes-skills-recommended-source-v1.json','native-level-up-controls-research-v2.json','native-creation-skills-research-v1.json'])put('source/'+name,fs.readFileSync(path.join(project,'reports',name)));
put('tools/seal-native-level-up-recommended.mjs',fs.readFileSync(fileURLToPath(import.meta.url)));
const owned=['systems/native_level_up.gd','systems/native_level_up_runtime.gd','systems/native_level_up_frontend.gd','systems/native_level_up_attributes.gd','systems/native_level_up_recommendation_work.gd','systems/native_data/level_up_rule_publication.gd','systems/native_data/level_up_recommendation_context.gd','systems/native_data/level_up_source_owner.gd','systems/native_data/level_up_skill_state.gd'].map(file=>({path:file,sha256:currentProduction.get('godot-client/'+file)}));
if(owned.some(row=>!row.sha256))throw Error('Current owned source omitted from current acceptance');
const report={productionApplied:true,fullLevelUpAccepted:false,checks:receipts.reduce((sum,row)=>sum+row.checks,0),historicalChecks:receipts.filter(row=>!row.current).reduce((sum,row)=>sum+row.checks,0),currentChecks:receipts.filter(row=>row.current).reduce((sum,row)=>sum+row.checks,0),counting:'Assertion instances across scoped receipts; some repeat. Historical receipts retain exact versions and declared current drift.',receipts,rejected,ownedSources:owned,production:[...currentProduction].map(([file,sha256])=>({path:file,sha256})),before:backups.map(label=>'.cache/level-up-recommended/'+label+'/before.json'),scope:'Mode1 Attributes/Skills Recommended context and scoped private resource publication, actual native buttons/cancellation and failed/empty semantics, current catalog/generation and retired-UI guard; controlled headless art/fonts and authored received actor. No authoritative level-up result or pixel acceptance.',remaining:['Feats/Spells Recommended','Uncovered mode1 prestige/capacity native fields','Higher-level shared CRT owner','Late S9c pristine retry','Dynamic title display','Original local level-up result/received mutation'],serverConnections:0,nativeBuilds:0,gpu:false};
put('report.json',Buffer.from(JSON.stringify(report,null,2)+'\n'));
const manifest=[...entries].map(([file,sha256])=>({path:file,sha256})),manifestFile=path.join(stage,'manifest.json');fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
for(const row of json(manifestFile))if(hash(fs.readFileSync(path.join(stage,row.path)))!==row.sha256)throw Error('Checkpoint readback mismatch '+row.path);
report.archive={path:path.relative(project,stage).replaceAll('\\','/'),format:'verified-directory',sha256:hash(fs.readFileSync(manifestFile)),entries:entries.size+1,readback:true};fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
