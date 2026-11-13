import assert from 'node:assert/strict';import fs from 'node:fs/promises';import path from 'node:path';import {createHash,randomUUID}from'node:crypto';import {createRequire}from'node:module';import {fileURLToPath}from'node:url';
const {readAssociateRecordServerPin}=createRequire(import.meta.url)('../tools/native-associate-record-pin.cjs');
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project),evidenceRoot=process.env.NWN_ASSOCIATE_RECORD_EVIDENCE_ROOT??root,directory=path.join(project,'.cache/associate-record-pin-tests',randomUUID());
let checks=0;const check=(value,label)=>{checks++;assert.ok(value,label);};
const identity=name=>Buffer.from('authored-log-identity-'+name).toString('base64');
const homes={old:path.join(directory,'prior-action-home/server'),current:path.join(directory,'current-invocation/server'),missing:path.join(directory,'missing/server')};
for(const key of ['old','current']){await fs.mkdir(path.join(homes[key],'logs'),{recursive:true});await fs.writeFile(path.join(homes[key],'logs/nwengineLog.txt'),'Owned test engine: cryptographic public identity is: '+identity(key)+'\n',{flag:'wx'});}
const actual=await readAssociateRecordServerPin(homes.current),old=await readAssociateRecordServerPin(homes.old);
check(actual.pin===identity('current')&&actual.pin!==old.pin,'Current invocation owns its exact pin, distinct from previous action home');
check(actual.sourcePath===path.join(homes.current,'logs/nwengineLog.txt'),'Provenance is the current owned profile log');
check(actual.identitySha256===createHash('sha256').update(Buffer.from(identity('current'),'base64')).digest('hex'),'Identity witness hashes decoded current key bytes');
await assert.rejects(readAssociateRecordServerPin(homes.missing));checks++;
await fs.mkdir(path.join(homes.missing,'logs'),{recursive:true});await fs.writeFile(path.join(homes.missing,'logs/nwengineLog.txt'),'No cryptographic identity published yet\n');
await assert.rejects(readAssociateRecordServerPin(homes.missing));checks++;
for(const invalid of [undefined,'relative/server',directory]){await assert.rejects(readAssociateRecordServerPin(invalid));checks++;}
const captured=JSON.parse(await fs.readFile(path.join(project,'reports/native-associate-record-pin-source-v1.json')));
const real=await readAssociateRecordServerPin(path.join(evidenceRoot,path.dirname(path.dirname(captured.actualOwned5127Source.path))));
check(real.identitySha256===captured.actualOwned5127Source.sha256&&real.identitySha256!==captured.expectedOldActionSource.sha256,'Retained actual failed invocation chooses its own identity rather than mismatched shared5125 witness');
console.log(JSON.stringify({success:true,checks,scope:'Current-invocation authored log routing and retained real failed-profile provenance. No network or cryptographic-validation bypass.'}));
