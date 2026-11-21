'use strict';
// Private 256 px GPU correctness/teardown diagnostic. No FPS or shared client.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),project=path.join(root,'.cache/nwn71/cpu-midpoint-a/fixture'),out=path.join(root,'.cache/nwn71/cpu-midpoint-close-gate-c');
const test=path.join(project,'tests/nwn71/gamma_prewarm_pixels.gd'),engine=path.join(root,'.tools/Godot_v4.7.2-stable_win64.exe');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const old=fs.readFileSync(test);assert.equal(hash(old),'ceb96a4bfe0796d0ef617fc1b623b3013d1c30abc6e754c733404cfedca986ec');
assert.equal(hash(fs.readFileSync(path.join(project,'systems/native_render/native_gamma_effect.gd'))),'8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468');
assert.equal(hash(fs.readFileSync(path.join(project,'systems/native_render/native_postprocess.gd'))),'539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b');
assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const original=old.toString(),needle='\teffect.close();world.free()\n\tawait process_frame\n\tquit(0 if result.success else 1)';
assert(original.includes(needle));
const runs=[];let restored=false;
try {
 for(const [index,variant] of ['immediate','barrier'].entries()){
  const changed=variant==='barrier'
   ? original.replace(needle,'\teffect.close();world.free()\n\tprint("NWN71_CLOSE_CALLED")\n\tRenderingServer.call_on_render_thread(Callable(self,"release_marker"))\n\tawait process_frame\n\tawait process_frame\n\tprint("NWN71_POST_FRAME")\n\tquit(0 if result.success else 1)')+'\nfunc release_marker() -> void:\n\tprint("NWN71_RELEASE_BARRIER")\n'
   : original.replace(needle,'\teffect.close();world.free()\n\tprint("NWN71_CLOSE_CALLED")\n\tawait process_frame\n\tprint("NWN71_POST_FRAME")\n\tquit(0 if result.success else 1)');
  fs.writeFileSync(test,changed);
  for(let n=0;n<6;n++){
   const mode=(n%2===0?'on':'off'),folder=path.join(out,`${variant}-${n}-${mode}`),home=path.join(folder,'userdata');fs.mkdirSync(home,{recursive:true});
   const report=path.join(folder,'report.json'),png=path.join(folder,'pixels.png'),log=path.join(folder,'engine.log');
   const args=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--windowed','--resolution','256x256','--screen','1','--log-file',log,'--script','res://tests/nwn71/gamma_prewarm_pixels.gd','--','--report='+report,'--png='+png];
   const run=spawnSync(engine,args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:45000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN71_GAMMA_PREWARM:'0',NWN71_CPU_MIDPOINT:mode==='on'?'1':'0'}});
   fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
   const value=fs.existsSync(report)?JSON.parse(fs.readFileSync(report,'utf8')):null;
   const row={variant,mode,exit:run.status,error:run.error?.message??'',success:value?.success??false,report:fs.existsSync(report)?hash(fs.readFileSync(report)):null,png:fs.existsSync(png)?hash(fs.readFileSync(png)):null,closeCalled:(run.stdout??'').includes('NWN71_CLOSE_CALLED'),postFrame:(run.stdout??'').includes('NWN71_POST_FRAME'),releaseBarrier:(run.stdout??'').includes('NWN71_RELEASE_BARRIER')};runs.push(row);
   console.log(JSON.stringify({variant,mode,exit:row.exit,success:row.success,closeCalled:row.closeCalled,postFrame:row.postFrame,releaseBarrier:row.releaseBarrier}));
  }
 }
} finally {
 fs.writeFileSync(test,old);restored=hash(fs.readFileSync(test))===hash(old);
 const receipt={issue:'NWN-71',scope:'Small GPU correctness and teardown phase diagnostic, no FPS',source:{testSha256:hash(old),gammaSha256:'8e60a4c334e8c659af10aa4045e811c2f36404541c81d583c18d88b80f4b5468',postSha256:'539878e853a113e59624b9fa33fedb7cba70e192061de4ada4748031abd57b2b',engineSha256:hash(fs.readFileSync(engine))},testRestored:restored,runs};
 receipt.success=restored&&runs.length===12&&runs.every(r=>r.exit===0&&r.success&&r.closeCalled&&r.postFrame&&(r.variant!=='barrier'||r.releaseBarrier))&&runs.every(r=>r.png===runs[0].png);
 fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({success:receipt.success,restored,exits:runs.map(r=>r.exit),pixelAgreement:runs.every(r=>r.png===runs[0].png)}));
 if(!receipt.success)process.exitCode=1;
}
