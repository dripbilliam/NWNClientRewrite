import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const directory=path.join(project,'.cache/level-up-runtime/sealed-runtime-v1'),output=path.join(project,'reports/native-level-up-runtime-v1.json');
if(fs.existsSync(directory)||fs.existsSync(output))throw Error('Existing evidence preserved');
const cases=[['runtime45','.cache/level-up-associate/native-level-up-runtime-reject-v2'],['summary393','.cache/level-up-summary/native-level-up-summary-v3'],['context141','.cache/level-up-context/native-level-up-context-integrated-v1'],['entryCompile1','.cache/level-up-entry-compile/native-level-up-entry-compile-v1']];
const inputs=new Map(),receipts=[];
for(const[name,relative]of cases){
 const home=path.join(project,relative),proofFile=path.join(home,'proof.json'),proof=JSON.parse(fs.readFileSync(proofFile));
 if(!proof.success||proof.exitCode!==0||proof.cleanEngine===false||proof.changedInputs?.length||proof.serverConnections||proof.nativeBuilds||proof.gpu)throw Error('Rejected receipt '+name);
 for(const row of proof.inputs){const bytes=fs.readFileSync(path.join(home,'inputs',row.path));if(hash(bytes)!==row.sha256)throw Error('Accepted copy changed '+row.path);const old=inputs.get(row.path);if(old&&old.sha256!==row.sha256)throw Error('Different accepted snapshots '+row.path);if(!old)inputs.set(row.path,{...row,bytes});}
 receipts.push({name,checks:proof.checks,path:path.relative(workspace,proofFile).replaceAll('\\','/'),sha256:hash(fs.readFileSync(proofFile)),scope:proof.scope,home});
}
const divergent=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(workspace,row.path)))!==row.sha256).map(row=>row.path);if(divergent.length)throw Error('Current source diverged '+JSON.stringify(divergent));
fs.mkdirSync(directory,{recursive:true});
for(const row of inputs.values()){const target=path.join(directory,'inputs',row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,row.bytes);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Readback failed');}
for(const row of receipts)for(const file of ['proof.json','result.json','engine.log','stdout.log','stderr.log']){const original=path.join(row.home,file);if(!fs.existsSync(original))continue;const target=path.join(directory,'receipts',row.name,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(original,target);}
const extras=['NATIVE-LEVEL-UP-SOURCE.md','reports/native-level-up-runtime-scope-corrections-v1.json','reports/native-level-up-summary-hp-original-v1.json','reports/native-level-up-app-flag-source-v1.json'];
const files=[];for(const relative of extras){const bytes=fs.readFileSync(path.join(project,relative)),target=path.join(directory,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);files.push({path:relative,sha256:hash(bytes)});}
const before=path.join(project,'.cache/level-up-runtime/before-runtime-v1');fs.cpSync(before,path.join(directory,'before-runtime-v1'),{recursive:true,errorOnExist:true});
const historical=[['protocol16','.cache/level-up-gui-tests/native-level-up-protocol-v1/proof.json'],['pendingCancel38','.cache/level-up-associate/native-level-up-runtime-v1/proof.json']].map(([name,relative])=>({name,path:relative,sha256:hash(fs.readFileSync(path.join(project,relative))),currentWholeSourceAccepted:false}));
const report={productionApplied:true,fullLevelUpAccepted:false,serverConnections:0,nativeBuilds:0,gpu:false,receipts:receipts.map(({home,...row})=>row),historical,inputs:[...inputs.values()].map(({bytes,...row})=>row),divergent,files,
 snapshot:path.relative(workspace,directory).replaceAll('\\','/'),scope:'Exact native runtime-owner/panel controls, original Summary helper, received context producer and actual SessionWorld static parse. Controlled art/fonts/authored replies; no original server/pixel acceptance.',
 active:['Original low-level Class/Skills/Associate/Summary runtime bridge','Available-first source/generic Class publication with physical IDs','Original token/area/actor fences; one-shot typed submit and unresolved/resolved cancel distinction','Explicit standard-editor fallback for missing/unsupported data'],
 pending:['Late S9c context refresh under existing draft/token; current fallback needs reopen','Higher-level private CRT RNG owner, including force maximum','Mode1 title display/name/first-line binding','All class-dependent branches composed through runtime','Original authoritative local proposal/result/level changes and GUI16 outcomes','Original pixels and other-class School slot caches']};
const bytes=JSON.stringify(report,null,2)+'\n';fs.writeFileSync(output,bytes);fs.writeFileSync(path.join(directory,'manifest.json'),bytes);if(hash(fs.readFileSync(output))!==hash(fs.readFileSync(path.join(directory,'manifest.json'))))throw Error('Manifest readback mismatch');
console.log(JSON.stringify({output,inputs:inputs.size,receipts:report.receipts.map(r=>[r.name,r.checks]),sha256:hash(Buffer.from(bytes)),divergent}));
