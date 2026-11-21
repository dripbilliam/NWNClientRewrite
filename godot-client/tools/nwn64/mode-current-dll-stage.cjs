'use strict';
// Read-only compatibility check of the installed-model fixture against the current accepted DLL.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const source=path.join(root,'.cache/nwn64/mode-local-z-a');
const target=path.join(root,'.cache/nwn64/mode-local-z-current-b');
const binary='.cache/native-kernel/nwn-particle-kernel.dll';
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert(!fs.existsSync(target));
fs.cpSync(source,target,{recursive:true});
fs.rmSync(path.join(target,'mode-report.json'),{force:true});
fs.copyFileSync(path.join(root,binary),path.join(target,binary));
const receipt={sourceProject:source,targetProject:target,fixtureSourceSha256:sha(path.join(target,'tests/geometry_worker_installed_models_test.gd')),candidateDllSha256:sha(path.join(source,binary)),currentDllSha256:sha(path.join(target,binary)),scope:'Exact fixture source, current accepted particle DLL substituted privately; no production change.'};
fs.writeFileSync(path.join(target,'current-dll-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
