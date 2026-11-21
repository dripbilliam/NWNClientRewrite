import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),directory=path.join(project,'.cache/level-up-rule-publication/sealed-v3');
const stage=path.join(directory,'checkpoint'),hash=b=>crypto.createHash('sha256').update(b).digest('hex'),readJson=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'')),entries=new Map();
if(process.argv.includes('--compress')){
 const reportPath=path.join(project,'reports/native-level-up-rule-publication-v1.json'),report=readJson(reportPath),manifestPath=path.join(stage,'manifest.json');
 if(report.archive?.format!=='verified-directory'||report.archive.sha256!==hash(fs.readFileSync(manifestPath)))throw Error('Accepted directory identity changed');
 for(const row of readJson(manifestPath))if(hash(fs.readFileSync(path.join(stage,row.path)))!==row.sha256)throw Error('Accepted checkpoint bytes changed');
 const zip=path.join(directory,'native-level-up-rule-publication-v1.zip');if(fs.existsSync(zip))throw Error('Existing compressed checkpoint preserved');
 const script='import sys,pathlib,zipfile,hashlib,json\nr=pathlib.Path(sys.argv[1]);p=pathlib.Path(sys.argv[2])\nwith zipfile.ZipFile(p,"x",zipfile.ZIP_DEFLATED,6) as z:\n for f in sorted(r.rglob("*")):\n  if f.is_file():z.write(f,f.relative_to(r).as_posix())\nwith zipfile.ZipFile(p) as z:\n m=json.loads(z.read("manifest.json"))\n assert len(z.namelist())==len(m)+1\n for a in m:assert hashlib.sha256(z.read(a["path"])).hexdigest()==a["sha256"]\nprint(json.dumps({"entries":len(m)+1,"readback":True}))\n';
 const child=spawnSync('C:/Users/Niflheim/AppData/Local/Programs/Python/Python312/python.exe',['-c',script,stage,zip],{windowsHide:true,encoding:'utf8',timeout:30000});if(child.status!==0||child.error)throw Error(child.stderr||child.error?.message||'Archive verification failed');
 report.compressedArchive={path:path.relative(project,zip).replaceAll('\\','/'),format:'zip-deflate',sha256:hash(fs.readFileSync(zip)),...JSON.parse(child.stdout)};fs.writeFileSync(reportPath,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report.compressedArchive));process.exit(0);
}
if(fs.existsSync(directory))throw Error('Existing accepted checkpoint preserved');
function put(relative,bytes){if(path.isAbsolute(relative)||relative.split(/[\\/]/).includes('..'))throw Error('Invalid checkpoint path');const prior=entries.get(relative);if(prior&&prior!==hash(bytes))throw Error('Different accepted bytes for '+relative);if(prior)return;const file=path.join(stage,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);entries.set(relative,hash(bytes));}
const receipts=[];
for(const label of ['native-level-up-rule-publication-v1','native-level-up-rule-runtime-v2']){
 const base=path.join(project,'.cache/level-up-rule-publication',label),file=path.join(base,'proof.json'),receipt=readJson(file);
 if(!receipt.success||!receipt.cleanEngine||receipt.changedInputs.length||(receipt.changedCopies??[]).length)throw Error('Unaccepted case '+label);
 for(const row of receipt.inputs){const bytes=fs.readFileSync(path.join(base,'inputs',row.path));if(hash(bytes)!==row.sha256)throw Error('Accepted copy changed '+row.path);put('inputs/'+row.path,bytes);}
 for(const name of ['proof.json','result.json','engine.log','stdout.log','stderr.log'])put('evidence/'+label+'/'+name,fs.readFileSync(path.join(base,name)));
 receipts.push({name:label,checks:receipt.checks,path:'.cache/level-up-rule-publication/'+label+'/proof.json',sha256:hash(fs.readFileSync(file)),inputs:receipt.inputs.length});
}
const before=path.join(project,'.cache/level-up-rule-publication/before-runtime-publication-v1');
put('before/before.json',fs.readFileSync(path.join(before,'before.json')));
for(const name of ['native_level_up.gd','native_level_up_runtime.gd']){
 const oldFile=path.join(before,name),current=path.join(project,'systems',name),diff=spawnSync('git',['diff','--no-index','--',oldFile,current],{windowsHide:true,encoding:'utf8'});
 if(![0,1].includes(diff.status)||diff.error)throw Error('Cannot read scoped diff');put('before/'+name,fs.readFileSync(oldFile));put('diff/'+name+'.patch',Buffer.from(diff.stdout));
 const accepted=entries.get('inputs/godot-client/systems/'+name);if(hash(fs.readFileSync(current))!==accepted)throw Error('Owned source changed after acceptance');
}
for(const name of ['NATIVE-LEVEL-UP-CLASS-PUBLICATION.md','NATIVE-LEVEL-UP-PARITY-AUDIT.md'])put('docs/'+name,fs.readFileSync(path.join(project,name)));
put('tools/seal-native-level-up-rule-publication.mjs',fs.readFileSync(fileURLToPath(import.meta.url)));
const sources=['systems/native_level_up.gd','systems/native_level_up_runtime.gd','systems/native_data/level_up_rule_publication.gd'].map(file=>({path:file,sha256:hash(fs.readFileSync(path.join(project,file)))}));
const report={productionApplied:true,fullLevelUpAccepted:false,checks:551,receipts,sources,before:'.cache/level-up-rule-publication/before-runtime-publication-v1/before.json',scope:'Private native mode1 class publication and current actual runtime/control boundary; raw/received isolation and typed transaction ownership. No authoritative level-up/server/pixel acceptance.',remaining:['Recommended bindings','Uncovered ArcSpellLvlMod/DivSpellLvlMod native storage mapping','Higher-level shared CRT owner','Late S9c pristine retry','Dynamic title display','Original local level-up result/received mutation'],serverConnections:0,nativeBuilds:0,gpu:false};
put('report.json',Buffer.from(JSON.stringify(report,null,2)+'\n'));
const manifest=[...entries].map(([name,sha256])=>({path:name,sha256}));fs.writeFileSync(path.join(stage,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
// A standalone directory checkpoint needs no Python/store-app process. Both
// failed optional packaging attempts are retained in sealed-v1/v2, unchanged.
const verified=readJson(path.join(stage,'manifest.json'));for(const row of verified)if(hash(fs.readFileSync(path.join(stage,row.path)))!==row.sha256)throw Error('Checkpoint readback mismatch '+row.path);
report.archive={path:path.relative(project,stage).replaceAll('\\','/'),format:'verified-directory',sha256:hash(fs.readFileSync(path.join(stage,'manifest.json'))),entries:verified.length+1,readback:true};fs.writeFileSync(path.join(project,'reports/native-level-up-rule-publication-v1.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
