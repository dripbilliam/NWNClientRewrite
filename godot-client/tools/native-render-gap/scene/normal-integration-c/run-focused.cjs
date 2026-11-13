'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../../../..'),label=process.argv[2]??'normal-integration-c',m=JSON.parse(fs.readFileSync(path.join(project,'.cache/native-render-gap/scene',label,'manifest.json'))),output=path.join(m.directory,'focused-a');if(fs.existsSync(output))throw Error('Existing focused evidence remains frozen');fs.mkdirSync(output);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),testProject=path.join(project,'.cache/native-render-gap/particles/hot-parameters-c/test-project');
const cases=[
 {name:'setup-sampler-off',engine:path.join(m.candidate,m.artifact.relative),script:'res://tests/bound_native_render_gap_scene_boundary_callbacks_test.gd'},
 {name:'official-all-flags-absent',engine:path.join(m.candidate,'.tools/Godot_v4.7.2-stable_win64.exe'),script:'res://tests/native_render_gap_direct_scene_test.gd'}
],results=[];
for(const c of cases){
 const folder=path.join(output,c.name);fs.mkdirSync(folder);for(const sub of ['appdata','localappdata'])fs.mkdirSync(path.join(folder,sub));const report=path.join(folder,'report.json');
 const args=['--headless','--path',testProject,'--script',c.script,'--','--report='+report];
 const r=spawnSync(c.engine,args,{windowsHide:true,encoding:'utf8',timeout:60000,maxBuffer:8*1024*1024,env:{...process.env,APPDATA:path.join(folder,'appdata'),LOCALAPPDATA:path.join(folder,'localappdata')}});
 fs.writeFileSync(path.join(folder,'stdout.log'),r.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(folder,'stderr.log'),r.stderr??'',{flag:'wx'});
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,clean=!/SCRIPT ERROR|Parse Error|Compile Error|leaked|still in use|CrashHandler|crashed|fatal error|^ERROR:/im.test((r.stdout??'')+(r.stderr??''));
 const result={...c,args,exit:r.status,error:r.error?.message??null,clean,native,success:r.status===0&&clean&&native?.success===true};results.push(result);console.log(JSON.stringify({name:c.name,success:result.success,exit:r.status,clean,checks:native?.checks?.length??native?.checks??null}));
}
const success=results.every(r=>r.success);const receipt={success,version:1,created:new Date().toISOString(),production:false,results,engine:m.artifact.sha256,kernel:m.nativeKernel.sha256,mainSourceUnchanged:true,scope:'Frozen actual HotC sampler-disabled bound callback/state checks and official-engine all-new-flags-absent direct legacy fixture. No GPU/FPS/local-authority claim.'};fs.writeFileSync(path.join(output,'acceptance.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});if(!success)process.exitCode=1;
