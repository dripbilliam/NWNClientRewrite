'use strict';
// Hash-pinned private OFF/ON original-shader pixel oracle. Restores the old
// private project sources even if either child fails. No FPS observation.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const prior=path.join(root,'.cache/nwn71/gamma-original-pixels-a');
const project=path.join(prior,'project');
const out=path.join(root,'.cache/nwn71/cpu-midpoint-full-oracle-b');
const engine=path.join(root,'.cache/nwn71/scene-cull-entry-d/input/.tools/native-tracy/Godot_native_d_tracy_win64.exe');
const install='C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall';
const files={
  'systems/native_render/native_gamma_effect.gd':{old:'a0d92018181d096fb79d68cbfb851fc6ad8c3eaab2f9416b5aac9f6588ca3e3a',now:'8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468'},
  'systems/native_render/native_postprocess.gd':{old:'0495dc4364e242ab9cdf6889988e14501de1d358e077b903adc941f6835913d2',now:'539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b'},
};
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
assert(!fs.existsSync(out),'Preserve earlier full-oracle run');
assert(fs.existsSync(engine)&&fs.existsSync(install));
assert.equal(sha(fs.readFileSync(path.join(project,'tests/native_postprocess_pixels_test.gd'))),'bfa25a8c346201c56f9d2e2d4dee5ebf74515caad7c65abba8412c898aaf3257');
const originals=new Map();
for(const [relative,pin] of Object.entries(files)) {
  const saved=fs.readFileSync(path.join(project,relative));
  assert.equal(sha(saved),pin.old,`Private project changed: ${relative}`);
  const current=fs.readFileSync(path.join(root,relative));
  assert.equal(sha(current),pin.now,`Current candidate changed: ${relative}`);
  originals.set(relative,saved);
}
const manifest={issue:'NWN-71',scope:'Full original-shader GPU pixel oracle OFF/ON; no FPS or shared client restart',engineSha256:sha(fs.readFileSync(engine)),oracleSha256:'bfa25a8c346201c56f9d2e2d4dee5ebf74515caad7c65abba8412c898aaf3257',sourcePins:files,runs:[],sourceRestored:false};
fs.mkdirSync(out,{recursive:true});
try {
  for(const relative of originals.keys())fs.writeFileSync(path.join(project,relative),fs.readFileSync(path.join(root,relative)));
  for(const [relative,pin] of Object.entries(files))assert.equal(sha(fs.readFileSync(path.join(project,relative))),pin.now);
  for(const mode of ['off','on']) {
    const folder=path.join(out,mode),home=path.join(folder,'userdata');
    fs.mkdirSync(home,{recursive:true});
    const report=path.join(folder,'pixels.json'),log=path.join(folder,'engine.log');
    const args=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--windowed','--resolution','256x256','--screen','1','--log-file',log,'--script','res://tests/native_postprocess_pixels_test.gd','--','--report='+report,'--install='+install];
    const run=spawnSync(engine,args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:150000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN71_GAMMA_PREWARM:'0',NWN71_CPU_MIDPOINT:mode==='on'?'1':'0'}});
    fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');
    fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
    const parsed=fs.existsSync(report)?JSON.parse(fs.readFileSync(report,'utf8')):null;
    manifest.runs.push({mode,exit:run.status,signal:run.signal,error:run.error?.message??'',reportSha256:parsed?sha(fs.readFileSync(report)):null,checks:parsed?.checks??null,success:parsed?.success??false,failures:parsed?.failures?.slice(0,10)??[],samples:parsed?.samples??[],midpointPasses:parsed?.gamma?.midpoint_passes??null,midpointUploads:parsed?.gamma?.midpoint_uploads??null,gammaFailure:parsed?.gamma?.failure??null});
    console.log(JSON.stringify({mode,exit:run.status,error:run.error?.message??'',checks:parsed?.checks,success:parsed?.success,failures:parsed?.failures?.slice(0,3),midpointPasses:parsed?.gamma?.midpoint_passes,midpointUploads:parsed?.gamma?.midpoint_uploads}));
    if(run.status!==0||!parsed?.success)break;
  }
} finally {
  for(const [relative,saved] of originals)fs.writeFileSync(path.join(project,relative),saved);
  manifest.sourceRestored=Object.entries(files).every(([relative,pin])=>sha(fs.readFileSync(path.join(project,relative)))===pin.old && sha(fs.readFileSync(path.join(root,relative)))===pin.now);
  const [off,on]=manifest.runs;
  let maxSampleDelta=null;
  if(off?.samples?.length===192&&on?.samples?.length===192) {
    let max=0;
    for(let i=0;i<192;i++) {
      assert.equal(off.samples[i].mask,on.samples[i].mask);
      assert.equal(off.samples[i].lights,on.samples[i].lights);
      assert.equal(off.samples[i].gamma,on.samples[i].gamma);
      for(let channel=0;channel<3;channel++)max=Math.max(max,Math.abs(off.samples[i].actual[channel]-on.samples[i].actual[channel]));
    }
    maxSampleDelta=max;
  }
  manifest.maxSampleDelta=maxSampleDelta;
  manifest.success=manifest.sourceRestored&&manifest.runs.length===2&&manifest.runs.every(r=>r.exit===0&&r.success&&r.checks===428)&&maxSampleDelta!==null&&maxSampleDelta<=1/255;
  // Raw samples remain in the individual reports; keep this receipt compact.
  for(const run of manifest.runs)delete run.samples;
  fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify({success:manifest.success,sourceRestored:manifest.sourceRestored,maxSampleDelta:manifest.maxSampleDelta,exits:manifest.runs.map(r=>r.exit)}));
  if(!manifest.success)process.exitCode=1;
}

