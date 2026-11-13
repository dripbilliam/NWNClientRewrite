'use strict';
// Assert the original distance-spawn emitter actually owns live particles after the paired run.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const from=path.join(root,'.cache/nwn64/mode-aligned-movement-d');
const to=path.join(root,'.cache/nwn64/mode-aligned-activity-f');
const relative='tests/geometry_worker_installed_models_test.gd';
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert(!fs.existsSync(to));fs.cpSync(from,to,{recursive:true});
fs.rmSync(path.join(to,'mode-aligned-movement-report.json'),{force:true});
const file=path.join(to,relative);let body=fs.readFileSync(file,'utf8');
const marker='var worker_stats: Dictionary=rows[1].presentation.call("dispatch",7,{})';
assert.equal(body.split(marker).length,2);
body=body.replace(marker,`var aligned_active_count:=0
	for aligned_index in rows[1].origins.size():
		if rows[1].origins[aligned_index]=="c_jelly":
			var aligned_state: Dictionary=rows[1].owners[aligned_index].call("dispatch",2,{},{})
			aligned_active_count+=aligned_state.active188.records.size()
	check(aligned_active_count>0,"Original c_jelly aligned emitter has live particles")
	${marker}`);
const reportMarker='"worker_vertices":worker_stats.get("geometry_worker_vertices",0),"unsupported":unsupported';
assert.equal(body.split(reportMarker).length,2);
body=body.replace(reportMarker,'"worker_vertices":worker_stats.get("geometry_worker_vertices",0),"aligned_active_count":aligned_active_count,"unsupported":unsupported');
fs.writeFileSync(file,body);
const receipt={from,to,sourceSha256:sha(file),dllSha256:sha(path.join(to,'.cache/native-kernel/nwn-particle-kernel.dll')),change:'Require live original c_jelly aligned particles after controlled movement, in addition to exact serial/worker packet/state/RNG parity and extra worker geometry.'};
fs.writeFileSync(path.join(to,'activity-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(receipt));
