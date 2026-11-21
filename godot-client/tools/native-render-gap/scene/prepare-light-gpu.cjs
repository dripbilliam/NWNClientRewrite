const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const id=process.argv.find(x=>x.startsWith('--id='))?.slice(5)??'light-gpu-a';
if(!/^[a-z0-9-]+$/.test(id))throw Error('Invalid stage identifier');
const directory=path.join(project,'.cache/native-render-gap/scene',id),renderer=path.join(directory,'renderer');
if(fs.existsSync(directory))throw Error('Frozen stage already exists');
fs.mkdirSync(renderer,{recursive:true});const inputs=[],copies=[];
function read(relative){const b=fs.readFileSync(path.join(project,relative));inputs.push({relative,sha256:sha(b)});return b;}
function put(relative,bytes){const p=path.join(renderer,relative);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,bytes,{flag:'wx'});copies.push({relative,sha256:sha(bytes)});}
const pending=['systems/native_render/native_light_policy.gd','systems/native_render/native_light_palette.gd'];
while(pending.length){const p=pending.shift();if(copies.some(x=>x.relative===p))continue;const b=read(p);put(p,b);for(const m of b.toString().matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)/g))pending.push(m[1]);}
put('baseline/model_point_light.gd',read('systems/native_render/model_point_light.gd'));
put('candidate/model_point_light.gd',read('tools/native-render-gap/scene/model_point_light_candidate.gd'));
put('tests/light_gpu.gd',read('tools/native-render-gap/scene/light_gpu_test.gd'));
put('fixture-ca.crt',read('.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source/thirdparty/certs/ca-bundle.crt'));
put('.godot/global_script_class_cache.cfg',Buffer.from('list=[]\n'));
put('project.godot',Buffer.from('config_version=5\n\n[application]\nconfig/name="Private light validity fixture"\n\n[display]\nwindow/size/viewport_width=480\nwindow/size/viewport_height=320\nwindow/size/resizable=false\nwindow/size/no_focus=true\n\n[network]\ntls/certificate_bundle_override="res://fixture-ca.crt"\n\n[rendering]\nrenderer/rendering_method="forward_plus"\nrenderer/rendering_method.mobile="forward_plus"\ntextures/default_filters/use_nearest_mipmap_filter=false\n'));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');
const manifest={version:1,createdAtUtc:new Date().toISOString(),directory,renderer,inputs,copies,launches:0,installed:false,scope:'Prepared GPU validity fixture. Root chooses common verified current engine, stable display, no other GPU workload; no FPS claim. Official engine check-only below parses without executing scene.'};
if(process.argv.includes('--check')){
 const args=['--headless','--path',renderer,'--script','res://tests/light_gpu.gd','--check-only'];
 const r=spawnSync(engine,args,{encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:1024*1024});
 fs.writeFileSync(path.join(directory,'check.stdout.log'),r.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(directory,'check.stderr.log'),r.stderr??'',{flag:'wx'});
 const check={exitCode:r.status,error:r.error?.message??null,engineSha256:sha(fs.readFileSync(engine)),command:[engine,...args],success:r.status===0&&!/SCRIPT ERROR|Parse Error|Compile Error/.test((r.stdout??'')+(r.stderr??'')),gpuExecuted:false};
 fs.writeFileSync(path.join(directory,'check.json'),JSON.stringify(check,null,2),{flag:'wx'});manifest.check=check;
}
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
console.log(JSON.stringify({directory,check:manifest.check??null},null,2));process.exitCode=manifest.check&&!manifest.check.success?1:0;
