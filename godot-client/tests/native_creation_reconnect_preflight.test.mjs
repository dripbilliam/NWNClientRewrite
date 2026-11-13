import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),stamp=Date.now(),label='native-creation-reconnect-preflight-'+stamp,directory=path.join(project,'.cache',label),wrapper=path.join(project,'tools/test-native-creation-vault-reconnect.ps1');fs.mkdirSync(directory);
const cases=[];
function reject(reference,suffix,reason){
 const run=label+'-'+suffix,result=spawnSync('pwsh.exe',['-NoProfile','-File',wrapper,'-Run',run,'-AcceptedCreate',reference],{windowsHide:true,encoding:'utf8',timeout:10000,maxBuffer:64*1024});
 fs.writeFileSync(path.join(directory,suffix+'.log'),(result.stdout??'')+(result.stderr??''));
 assert.notEqual(result.status,0);assert.match((result.stdout??'')+(result.stderr??''),reason);assert(!fs.existsSync(path.join(project,'.cache/creation-vault-reconnect-tests',run)));
 cases.push({suffix,rejected:true,expectedReason:reason.source});
}
test('reconnect rejects non-owned and unaccepted references before lease/server/login setup',()=>{
 const outside=path.join(directory,'outside.json');fs.writeFileSync(outside,'{}');reject(outside,'outside',/Explicit accepted owned create report required/);
 const unaccepted=path.join(project,'reports',label+'-unaccepted.json');fs.writeFileSync(unaccepted,JSON.stringify({authoredRejectionOnly:true,success:false}));reject(unaccepted,'unaccepted',/Accepted original Wizard server-vault create/);
});
test('changed retained fixture cannot reach an original server or protected login',()=>{
 const home=path.join(project,'.cache/creation-full-vault-tests',label,'server');fs.mkdirSync(home,{recursive:true});fs.writeFileSync(path.join(home,'fixture.json'),'{}\n');
 const reference=path.join(project,'reports',label+'-fixture.json');fs.writeFileSync(reference,JSON.stringify({authoredRejectionOnly:true,success:true,creationProof:{success:true,expected:{classId:10}},creationHpProof:{success:true},creationTailExportProof:{success:true},creationPostAdmissionExportComplete:true,creationWireProof:{success:true,expectedSubtype:19},endpoint:'127.0.0.1:5129',creationVaultFixture:{directory:home,descriptorSha256:'changed'}}));
 reject(reference,'fixture',/Retained fixture identity\/rules differ/);
});
test.after(()=>fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify({success:cases.length===3,cases,scope:'New wrapper preflight rejection only: path, acceptance and changed fixture fail before lease/server/login branch. No original process, key read or game connection.'},null,2)+'\n'));
