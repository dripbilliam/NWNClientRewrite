'use strict';
// Two isolated native-kernel component fixtures; no renderer or FPS sample.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),base=path.join(root,'.cache/nwn64/clock-validity-control-runtime-a/project'),candidate=path.join(root,'.cache/nwn64/clock-validity-runtime-a/project'),out=path.join(root,'.cache/nwn64/clock-validity-parity-c');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const engine=path.join(root,'.tools/native-core/Godot_native_core_e_win64.exe');
const descriptor=JSON.parse(fs.readFileSync(path.join(root,'.tools/native-core/accepted-core-e.json'),'utf8'));
const cases=[['focused','res://tests/nwn64_clock_test.gd'],['heavy','res://tests/nwn64_shared_clock_test.gd']];
const rows=[];
for(const [test,script] of cases)for(const [mode,project] of [['base',base],['candidate',candidate]]){
 const report=path.join(out,`${test}-${mode}.json`),home=path.join(out,`${test}-${mode}-user`);
 fs.mkdirSync(home,{recursive:true});
 const args=['--headless','--path',project,'--script',script,'--',...descriptor.fullFunctionalFlags,'--particle-clock-read=native','--expect-native=on','--profile=false','--report='+report];
 const run=spawnSync(engine,args,{cwd:project,env:{...process.env,APPDATA:home,LOCALAPPDATA:home},encoding:'utf8',windowsHide:true,timeout:180000,maxBuffer:4*1024*1024});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(out,`${test}-${mode}.log`),output,{flag:'wx'});
 assert.equal(run.status,0,`${test}/${mode} exit ${run.status}: ${output.slice(-5000)}`);
 const withoutKnownCert=output.replace(/ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform\\windows\\os_windows\.cpp:2582\)/g,'');
 assert(!/SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use/.test(withoutKnownCert),output.slice(-5000));
 const value=JSON.parse(fs.readFileSync(report,'utf8'));
 assert(value.success,`${test}/${mode} failures: ${JSON.stringify(value.failures)}`);
 rows.push({test,mode,project,kernelSha256:sha(path.join(project,'.cache/native-kernel/nwn-particle-kernel.dll')),reportSha256:sha(report),checks:value.checks,digest:value.packet_digest||value.digest,rngState:value.rng_state??null,rngDraws:value.rng_draws??null,clock:value.clock_info||value.final_clock_diagnostics,summary:value.last||null});
 console.log(JSON.stringify({test,mode,checks:value.checks,digest:rows.at(-1).digest,validity:rows.at(-1).clock.clock_validity_dispatches,reads:rows.at(-1).clock.native_clock_reads}));
}
for(const test of cases.map(x=>x[0])){
 const a=rows.find(x=>x.test===test&&x.mode==='base'),b=rows.find(x=>x.test===test&&x.mode==='candidate');
 assert.equal(a.digest,b.digest,`${test} packet digest`);
 assert.equal(a.rngState,b.rngState,`${test} RNG state`);
 assert.equal(a.rngDraws,b.rngDraws,`${test} RNG draws`);
 assert.equal(a.checks,b.checks,`${test} checks`);
 if(test==='heavy'){assert.deepEqual(a.summary,b.summary);assert.equal(a.clock.clock_validity_dispatches,42000);assert.equal(b.clock.clock_validity_dispatches,0);assert.equal(b.clock.native_clock_reads,42000);assert.equal(b.clock.native_clock_fallbacks,0);}
}
const receipt={issue:'NWN-64',success:true,scope:'Private canonical-clock validity bypass parity. No renderer, FPS, shared client or accepted source edit.',engineSha256:sha(engine),descriptorSha256:sha(path.join(root,'.tools/native-core/accepted-core-e.json')),rows};
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,receipt:path.join(out,'receipt.json')}));
