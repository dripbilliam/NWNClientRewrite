'use strict';
// Diagnostic-only state probe of the privately staged original aligned emitter.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const from=path.join(root,'.cache/nwn64/mode-aligned-active-b');
const to=path.join(root,'.cache/nwn64/mode-aligned-state-c');
const relative='tests/geometry_worker_installed_models_test.gd';
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert(!fs.existsSync(to)); fs.cpSync(from,to,{recursive:true});
fs.rmSync(path.join(to,'mode-aligned-active-report.json'),{force:true});
const file=path.join(to,relative);let body=fs.readFileSync(file,'utf8');
const marker='var worker_stats: Dictionary=rows[1].presentation.call("dispatch",7,{})';
assert.equal(body.split(marker).length,2);
body=body.replace(marker,`var aligned_snapshot: Dictionary={}
	for aligned_index in rows[1].origins.size():
		if rows[1].origins[aligned_index]=="c_jelly": aligned_snapshot=rows[1].owners[aligned_index].call("dispatch",2,{},{})
	print("ALIGNED_STATE ",JSON.stringify(without_ids(aligned_snapshot)).substr(0,3500))
	${marker}`);
fs.writeFileSync(file,body);
console.log(JSON.stringify({project:to,sourceSha256:sha(file),dllSha256:sha(path.join(to,'.cache/native-kernel/nwn-particle-kernel.dll'))}));
