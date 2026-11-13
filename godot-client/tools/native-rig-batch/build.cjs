'use strict';
// The coordinator reviews a source-only plan before explicitly executing it.
// No installed binaries, global extension lists, shared DLLs or engine files.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const root=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3);
const pins={compiler:['.cache/native-text-build/compiler/w64devkit/bin/x86_64-w64-mingw32-g++.exe','03e15580dda29518716dc6f6840d5ea055f526ddc8f59f14192b8d3e3eeea622'],header:['.tools/extension-api/gdextension_interface.h','640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'],api:['.tools/extension-api/extension_api.json','d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986'],core:['.tools/native-core/Godot_native_core_e_win64.exe','753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b'],rig:['systems/model_rigs.gd','864c13017c41618a038c18ad59787b7be236a36a1a15632148caacc78a96824a']};
function read(file){return fs.readFileSync(path.join(root,file));}
function check(pin){if(sha(read(pin[0]))!==pin[1])throw Error('Pinned input differs: '+pin[0]);}
function within(file){const result=path.resolve(root,file);if(!result.startsWith(path.join(root,'.cache')+path.sep))throw Error('Output must stay inside project .cache');return result;}
function write(file,data){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,data,{flag:'wx'});}
if(arg('execute-plan')){
  const planPath=within(arg('execute-plan')),plan=JSON.parse(fs.readFileSync(planPath));
  if(plan.schema!=='nwn65-private-rig-batch-plan-v1')throw Error('Unknown build plan');
  for(const pin of Object.values(pins).slice(0,4))check(pin);
  const output=path.dirname(planPath);
  for(const row of plan.frozenInputs){const actual=path.resolve(output,row.frozen);if(!actual.startsWith(output+path.sep)||sha(fs.readFileSync(actual))!==row.sha256)throw Error('Frozen source differs: '+row.frozen);}
  if(fs.existsSync(path.join(output,'build-receipt.json')))throw Error('Build already attempted; preserve evidence and choose a new plan');
  const started=new Date().toISOString();
  const result=cp.spawnSync(path.join(root,pins.compiler[0]),plan.arguments,{cwd:output,encoding:'utf8',windowsHide:true,shell:false,timeout:60000,maxBuffer:4*1024*1024});
  write(path.join(output,'compiler.log'),(result.stdout??'')+(result.stderr??'')+(result.error?'\n'+String(result.error):''));
  const receipt={schema:plan.schema,startedUtc:started,endedUtc:new Date().toISOString(),success:result.status===0&&!result.error,exit:result.status,signal:result.signal,plan:{file:path.relative(root,planPath).replaceAll('\\','/'),sha256:sha(fs.readFileSync(planPath))},compiler:plan.pins.compiler,arguments:plan.arguments,accepted:false,registration:'private-view-only'};
  const binary=path.join(output,'nwn-rig-animation-batch.dll');if(receipt.success)receipt.binary={file:path.relative(root,binary).replaceAll('\\','/'),sha256:sha(fs.readFileSync(binary)),bytes:fs.statSync(binary).size};
  write(path.join(output,'build-receipt.json'),JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify(receipt));if(!receipt.success)process.exitCode=1;
}else{
  const label=arg('label');if(!label||!/^[a-z0-9-]+$/.test(label))throw Error('Provide fresh --label=... for source-only planning');
  for(const pin of Object.values(pins))check(pin);
  const driver=arg('driver')??'.cache/nwn65/native-batch-source-a/candidate_rigs.gd';
  const output=within('.cache/nwn65/native-rig-batch-build-'+label);if(fs.existsSync(output))throw Error('Preserve existing build plan');
  const files=['tools/native-rig-batch/abi.hpp','tools/native-rig-batch/rig_animation_batch.cpp','tools/native-rig-batch/build.cjs','tools/native-rig-batch/prepare-view.cjs','tools/native-rig-batch/prepare-driver.cjs','tools/native-rig-batch/driver-prefix.gd.inc','tests/nwn65_native_batch_test.gd','tests/nwn65_native_batch_player.gd','tests/nwn65_active_event_test.gd',pins.header[0],pins.api[0],driver];
  const runtime=new Set();function dependency(file){if(runtime.has(file))return;if(file.includes('..')||!file.startsWith('systems/'))throw Error('Unexpected runtime closure '+file);runtime.add(file);files.push(file);for(const match of read(file).toString().matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))dependency(match[1]);}dependency(pins.rig[0]);
  for(const name of ['a_ba','c_goblina','fx_light_clr'])files.push('.cache/nwn65/original-census-a/'+name+'-original-events.json');
  const frozenInputs=[];
  for(const file of files){const bytes=read(file),name=file===driver?'driver/candidate_rigs.gd':file===pins.header[0]?'api/gdextension_interface.h':file===pins.api[0]?'api/extension_api.json':'source/'+file;write(path.join(output,name),bytes);frozenInputs.push({file,frozen:name,sha256:sha(bytes),bytes:bytes.length});}
  const arguments_=['-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-shared','-static-libgcc','-static-libstdc++','-MMD','-MF','dependencies.d','-I','api','source/tools/native-rig-batch/rig_animation_batch.cpp','-o','nwn-rig-animation-batch.dll'];
  const plan={schema:'nwn65-private-rig-batch-plan-v1',compiled:false,defaultOff:true,mainThreadOnly:true,pins:Object.fromEntries(Object.entries(pins).map(([key,[file,sha256]])=>[key,{file,sha256}])),frozenInputs,arguments:arguments_,scope:'One optional isolated GDExtension DLL, ordinary AnimationPlayer clocks/events on main thread; no installed/shared artifact or extension-list writes.'};
  write(path.join(output,'build-plan.json'),JSON.stringify(plan,null,2)+'\n');console.log(JSON.stringify({plan:path.relative(root,path.join(output,'build-plan.json')).replaceAll('\\','/'),sha256:sha(fs.readFileSync(path.join(output,'build-plan.json'))),inputs:frozenInputs.length,compiled:false}));
}
