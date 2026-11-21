import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const output=path.join(project,'reports/native-level-up-staged-associate-v1.json');
const directory=path.join(project,'.cache/level-up-associate/sealed-staged-v1');
if(fs.existsSync(output)||fs.existsSync(directory))throw Error('Existing evidence preserved');
const cases=[
 ['navigation30','.cache/level-up-source-owner/native-level-up-associate-compile-v1'],
 ['associate33','.cache/level-up-associate/native-level-up-associate-v3'],
 ['title66','.cache/level-up-title/native-level-up-title-v1'],
];
const inputs=new Map(),receipts=[];
for(const[name,relative]of cases){
 const home=path.join(project,relative),proofFile=path.join(home,'proof.json'),proof=JSON.parse(fs.readFileSync(proofFile));
 if(!proof.success||!proof.cleanEngine||proof.changedInputs.length||proof.gpu||proof.serverConnections||proof.nativeBuilds)throw Error('Rejected receipt '+name);
 for(const row of proof.inputs){
  const copied=path.join(home,'inputs',row.path),bytes=fs.readFileSync(copied);
  if(hash(bytes)!==row.sha256)throw Error('Accepted copy changed: '+row.path);
  const prior=inputs.get(row.path);if(prior&&prior.sha256!==row.sha256)throw Error('Different accepted source snapshots: '+row.path);
  if(!prior)inputs.set(row.path,{...row,source:copied,bytes});
 }
 receipts.push({name,checks:proof.checks,proof:path.relative(workspace,proofFile).replaceAll('\\','/'),sha256:hash(fs.readFileSync(proofFile)),scope:proof.scope});
}
const divergent=[];
for(const row of inputs.values())if(hash(fs.readFileSync(path.join(workspace,row.path)))!==row.sha256)divergent.push(row.path);
if(divergent.length)throw Error('Current accepted input diverged: '+JSON.stringify(divergent));
fs.mkdirSync(directory,{recursive:true});
for(const row of inputs.values()){
 const target=path.join(directory,'inputs',row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,row.bytes);
 if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Snapshot readback failed');
}
for(const receipt of receipts){
 const home=path.dirname(path.join(workspace,receipt.proof));
 for(const file of ['proof.json','result.json','engine.log','stdout.log','stderr.log']){
  const target=path.join(directory,receipt.name,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(home,file),target);
 }
}
const doc=path.join(project,'NATIVE-LEVEL-UP-SOURCE.md');fs.copyFileSync(doc,path.join(directory,path.basename(doc)));
const report={productionApplied:false,runtimeIntegrated:false,fullLevelUpAccepted:false,serverConnections:0,nativeBuilds:0,gpu:false,
 scope:'Exact staged navigation/Associate/text milestones; private Class→Skills→Associate→Summary uses actual active resources/workers. No runtime import, summary text/high-level RNG producer, server/pixel acceptance.',
 receipts,inputs:[...inputs.values()].map(({source,bytes,...row})=>row),divergent,documentationSha256:hash(fs.readFileSync(doc)),
 snapshot:path.relative(workspace,directory).replaceAll('\\','/'),
 remaining:['Exact mode1 title display/name/first-caption-line producer','Original Summary HP/text assembly','Private CRT random-state owner and received module context forwarding','Other-class School slot-cache presentation','Reviewed runtime entry and typed transaction wiring','Authoritative server acceptance and original pixels']};
const bytes=JSON.stringify(report,null,2)+'\n';fs.writeFileSync(output,bytes);fs.writeFileSync(path.join(directory,'manifest.json'),bytes);
if(hash(fs.readFileSync(output))!==hash(fs.readFileSync(path.join(directory,'manifest.json'))))throw Error('Manifest readback mismatch');
console.log(JSON.stringify({output,inputs:inputs.size,checks:receipts.map(r=>[r.name,r.checks]),sha256:hash(Buffer.from(bytes)),divergent}));
