'use strict';
// Substitute the current accepted DLL privately; fixture source stays byte-identical.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const from=path.join(root,'.cache/nwn64/mode-aligned-movement-d');
const to=path.join(root,'.cache/nwn64/mode-aligned-current-e');
const binary='.cache/native-kernel/nwn-particle-kernel.dll';
const source='tests/geometry_worker_installed_models_test.gd';
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert(!fs.existsSync(to));fs.cpSync(from,to,{recursive:true});
fs.rmSync(path.join(to,'mode-aligned-movement-report.json'),{force:true});
fs.copyFileSync(path.join(root,binary),path.join(to,binary));
const receipt={from,to,fixtureSourceSha256:sha(path.join(to,source)),privateCandidateDllSha256:sha(path.join(from,binary)),currentAcceptedDllSha256:sha(path.join(to,binary)),scope:'Private DLL substitution only; exact original c_jelly moving-source fixture source unchanged.'};
fs.writeFileSync(path.join(to,'accepted-dll-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
