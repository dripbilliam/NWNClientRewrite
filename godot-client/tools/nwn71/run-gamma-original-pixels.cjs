'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),source=path.join(root,'.cache/nwn71/scene-cull-entry-d/input'),out=path.join(root,'.cache/nwn71/gamma-original-pixels-a'),project=path.join(out,'project');
const originalEngine=path.join(source,'.tools/native-tracy/Godot_native_d_tracy_win64.exe');
const originalInstall='C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall';
const relative='systems/native_render/native_gamma_effect.gd';
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const disk=fs.statfsSync(root,{bigint:true});assert(disk.bavail*disk.bsize>10n*1024n*1024n*1024n,'Insufficient disk for isolated original-data view');
assert(fs.existsSync(originalEngine)&&fs.existsSync(originalInstall));assert(!fs.existsSync(out),'Preserve previous run');
const priorHash=sha(path.join(source,relative)),candidateHash=sha(path.join(root,relative));
fs.mkdirSync(out,{recursive:true});fs.cpSync(source,project,{recursive:true,errorOnExist:true,force:false});
fs.copyFileSync(path.join(root,relative),path.join(project,relative));
assert.equal(sha(path.join(project,relative)),candidateHash);
const runs=[];
for(const mode of ['off','on']){
  const folder=path.join(out,mode),home=path.join(folder,'userdata');fs.mkdirSync(home,{recursive:true});
  const report=path.join(folder,'pixels.json'),log=path.join(folder,'engine.log');
  const args=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--render-thread','separate','--windowed','--resolution','256x256','--screen','1','--log-file',log,'--script','res://tests/native_postprocess_pixels_test.gd','--','--report='+report,'--install='+originalInstall];
  const run=spawnSync(originalEngine,args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home,NWN71_GAMMA_PREWARM:mode==='on'?'1':'0'}});
  fs.writeFileSync(path.join(folder,'stdout.log'),run.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),run.stderr??'');
  const value={mode,exit:run.status,signal:run.signal,error:run.error?.message??'',report:fs.existsSync(report)?{file:report,sha256:sha(report),value:JSON.parse(fs.readFileSync(report,'utf8'))}:null};runs.push(value);
  if(run.status!==0||!value.report?.value.success)break;
}
let pixelAgreement=false,maxSampleDelta=null;
if(runs.length===2&&runs.every(r=>r.report?.value.success)){
  const a=runs[0].report.value.samples,b=runs[1].report.value.samples;
  assert.equal(a.length,b.length);let max=0;
  for(let i=0;i<a.length;i++)for(let j=0;j<3;j++)max=Math.max(max,Math.abs(a[i].actual[j]-b[i].actual[j]));
  maxSampleDelta=max;pixelAgreement=max<=1/255;
}
const result={schema:'nwn71-gamma-original-pixels-v1',sourceProject:source,privateProject:project,engine:{file:originalEngine,sha256:sha(originalEngine)},install:originalInstall,
  gammaSource:{originalSha256:priorHash,candidateSha256:candidateHash},runs,pixelAgreement,maxSampleDelta,
  scope:'Original shader pixel oracle in private project; no FPS or original area-entry timing.'};
result.success=runs.length===2&&runs.every(r=>r.exit===0&&r.report?.value.success)&&pixelAgreement;
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:result.success,maxSampleDelta,runs:runs.map(r=>({mode:r.mode,exit:r.exit,error:r.error,checks:r.report?.value.checks,failures:r.report?.value.failures?.slice(0,5),prewarm:r.report?.value.gamma?.prewarm}))}));
if(!result.success)process.exitCode=1;
