'use strict';
// One headless CPU component ABBA. No renderer or FPS measurement.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),suffix=process.argv[2]||'a';assert(['a','b'].includes(suffix));const out=path.join(root,'.cache/nwn64/clock-validity-cost-'+suffix);
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const stage=mode=>path.join(root,'.cache/native-render-gap/particles/nwn64-clock-validity-'+(mode==='control'?'control-a':'a'));
const view=mode=>path.join(root,'.cache/nwn64/clock-validity-'+(mode==='control'?'control-runtime-a':'runtime-a')+'/project');
const old=JSON.parse(fs.readFileSync(path.join(stage('control'),'kernel-source-pins.json'))),now=JSON.parse(fs.readFileSync(path.join(stage('candidate'),'kernel-source-pins.json')));
assert.deepEqual(old.pins.filter((x,i)=>x.sha256!==now.pins[i].sha256).map(x=>x.relative),['native/particle_presentation.hpp']);
for(const mode of ['control','candidate']){
 const build=JSON.parse(fs.readFileSync(path.join(stage(mode),'kernel-build/build-receipt.json'),'utf8').replace(/^\uFEFF/,''));
 assert(build.success);assert.equal(sha(build.binary),build.binarySha256);
 assert.equal(sha(path.join(view(mode),'.cache/native-kernel/nwn-particle-kernel.dll')),build.binarySha256);
 for(const pin of (mode==='control'?old:now).pins)assert.equal(sha(path.join(stage(mode),'kernel-project',pin.relative)),pin.sha256);
}
assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const engine=path.join(root,'.tools/native-core/Godot_native_core_e_win64.exe'),descriptor=JSON.parse(fs.readFileSync(path.join(root,'.tools/native-core/accepted-core-e.json')));
const rows=[];
const legs=suffix==='a'?[['a1','control'],['b1','candidate'],['b2','candidate'],['a2','control']]:[['b1','candidate'],['a1','control'],['a2','control'],['b2','candidate']];
for(const [leg,mode] of legs){
 const project=view(mode),report=path.join(out,leg+'.json'),home=path.join(out,leg+'-user');fs.mkdirSync(home,{recursive:true});
 const args=['--headless','--path',project,'--script','res://tests/nwn64_shared_clock_test.gd','--',...descriptor.fullFunctionalFlags,'--particle-clock-read=native','--expect-native=on','--profile=false','--benchmark=on','--report='+report];
 const run=spawnSync(engine,args,{cwd:project,env:{...process.env,APPDATA:home,LOCALAPPDATA:home},encoding:'utf8',windowsHide:true,timeout:180000,maxBuffer:4*1024*1024});
 const output=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(out,leg+'.log'),output,{flag:'wx'});
 assert.equal(run.status,0,output.slice(-5000));
 const clean=output.replace(/ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform\\windows\\os_windows\.cpp:2582\)/g,'');
 assert(!/SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances leaked|resources still in use/.test(clean),output.slice(-5000));
 const value=JSON.parse(fs.readFileSync(report,'utf8'));
 assert(value.success&&value.checks===3744&&value.frames===240&&value.actual_phase_packets===0);
 assert(value.component_call_us.samples===160&&value.clock_info.native_clock_reads===84000);
 rows.push({leg,mode,reportSha256:sha(report),meanUs:value.component_call_us.mean_us,medianUs:value.component_call_us.median_us,p95Us:value.component_call_us.p95_us,packetDigest:value.packet_digest,rngState:value.rng_state,rngDraws:value.rng_draws,validityCalls:value.clock_info.clock_validity_dispatches,nativeReads:value.clock_info.native_clock_reads});
 console.log(JSON.stringify(rows.at(-1)));
}
for(const row of rows){assert.equal(row.packetDigest,rows[0].packetDigest);assert.equal(row.rngState,rows[0].rngState);assert.equal(row.rngDraws,rows[0].rngDraws);assert.equal(row.validityCalls,row.mode==='control'?84000:0);}
const avg=mode=>rows.filter(row=>row.mode===mode).reduce((sum,row)=>sum+row.meanUs,0)/2;
const receipt={issue:'NWN-64',success:true,scope:'Private headless shared-presentation 1750-source CPU component ABBA, 240 frames/leg, 160 timed component calls. No renderer, FPS, shared engine or accepted source edit.',engineSha256:sha(engine),controlBinarySha256:sha(path.join(view('control'),'.cache/native-kernel/nwn-particle-kernel.dll')),candidateBinarySha256:sha(path.join(view('candidate'),'.cache/native-kernel/nwn-particle-kernel.dll')),rows,controlMeanUs:avg('control'),candidateMeanUs:avg('candidate'),savedMeanUs:avg('control')-avg('candidate')};
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,controlMeanUs:receipt.controlMeanUs,candidateMeanUs:receipt.candidateMeanUs,savedMeanUs:receipt.savedMeanUs}));
