import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2]??'static-leaf-census-'+Date.now();
if(!/^[a-z0-9-]+$/.test(label))throw Error('Private label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);
if(fs.existsSync(stage))throw Error('Existing capsule preserved');
const app=path.join(stage,'project');fs.mkdirSync(path.join(app,'.godot'),{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const pins=[];
for(const relative of ['tools/perf140/render/static_leaf_census.gd','tests/native_perf140_render_static_leaf_census_test.gd']){
 const bytes=fs.readFileSync(path.join(project,relative)),target=path.join(app,relative);
 fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.push({relative,sha256:hash(bytes)});
}
fs.writeFileSync(path.join(app,'project.godot'),'config_version=5\n[application]\nconfig/name="Private static leaf census functional gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.writeFileSync(path.join(app,'.godot/global_script_class_cache.cfg'),'list=Array[Dictionary]([])\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),log=path.join(stage,'engine.log');
const args=['--headless','--path',app,'--log-file',log,'--script','res://tests/native_perf140_render_static_leaf_census_test.gd'];
const invocation={engine,engineSha256:hash(fs.readFileSync(engine)),args,pins,gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'invocation.json'),JSON.stringify(invocation,null,2));
const result=spawnSync(engine,args,{windowsHide:true,encoding:'utf8',timeout:30000,maxBuffer:2*1024*1024});
fs.writeFileSync(path.join(stage,'stdout.log'),result.stdout??'');fs.writeFileSync(path.join(stage,'stderr.log'),result.stderr??'');
const all=(result.stdout??'')+'\n'+(result.stderr??'')+'\n'+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
const changed=pins.filter(pin=>hash(fs.readFileSync(path.join(app,pin.relative)))!==pin.sha256||hash(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256);
const receipt={success:result.status===0&&!result.error&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(all)&&!changed.length,exitCode:result.status,error:result.error?.message??null,changed,stage,stdout:result.stdout,stderr:result.stderr,gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt,null,2));if(!receipt.success)process.exitCode=1;
