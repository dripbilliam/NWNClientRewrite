import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);
if(fs.existsSync(stage))throw Error('Preserve previous constructor proof');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const fileHash=f=>hash(fs.readFileSync(f));
const descriptorFile=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/engine-descriptor.json');
const descriptor=JSON.parse(fs.readFileSync(descriptorFile)),engine=descriptor.engines.candidate;
if(fileHash(engine.path)!==engine.sha256)throw Error('Archived engine drift');
const parentFile=path.join(project,'.cache/native-140fps/root/builtin-light-fenced-v1/manifest.json');
const parent=JSON.parse(fs.readFileSync(parentFile));
const app=path.join(stage,'project');fs.mkdirSync(app,{recursive:true});
const pins=[];
for(const pin of parent.pins){const b=fs.readFileSync(path.join(parent.project,pin.relative));if(hash(b)!==pin.sha256)throw Error('Runtime source drift '+pin.relative);const target=path.join(app,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,b);pins.push({...pin});}
const fixture='tests/native_perf140_render_builtin_light_constructor_test.gd';
const fixtureBytes=fs.readFileSync(path.join(project,fixture));fs.writeFileSync(path.join(app,fixture),fixtureBytes);pins.push({relative:fixture,sha256:hash(fixtureBytes)});
const config=path.join(app,'project.godot');fs.writeFileSync(config,fs.readFileSync(config,'utf8').replace(/\[autoload\][\s\S]*?(?=\n\[|$)/,''));
pins.find(p=>p.relative==='project.godot').sha256=fileHash(config);
const adapter=path.join(app,'systems/native_render/focus_lighting_builtin_input_candidate.gd');
const original=fs.readFileSync(adapter,'utf8');
const fixed=original.replace('func _init() -> void:\n','func _init() -> void:\n\tsuper()\n');
if(original===fixed)throw Error('Expected one explicit constructor boundary');
const results=[];
for(const [name,source,args]of [['negative-default',original,['--expect-missing-registry']],['fixed-extension',fixed,[]],['fixed-builtin',fixed,['--light-input-registry=builtin']]]){
 fs.writeFileSync(adapter,source);
 const dir=path.join(stage,name);fs.mkdirSync(dir);
 const report=path.join(dir,'native.json'),log=path.join(dir,'engine.log');
 const command=['--headless','--path',app,'--log-file',log,'--script','res://'+fixture,'--','--report='+report,...args];
 const result=spawnSync(engine.path,command,{windowsHide:true,encoding:'utf8',timeout:45000,maxBuffer:2*1024*1024});
 fs.writeFileSync(path.join(dir,'stdout.log'),result.stdout??'');fs.writeFileSync(path.join(dir,'stderr.log'),result.stderr??'');
 const native=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null;
 const text=[result.stdout,result.stderr,fs.existsSync(log)?fs.readFileSync(log,'utf8'):''].join('\n');
 const record={name,success:result.status===0&&!result.error&&native?.success===true&&!/SCRIPT ERROR|ERROR:|leaked|still in use/i.test(text),exitCode:result.status,error:result.error?.message??null,native,adapterSha256:hash(source),command};
 fs.writeFileSync(path.join(dir,'receipt.json'),JSON.stringify(record,null,2));results.push(record);
 if(!record.success)break;
}
fs.writeFileSync(path.join(stage,'failed-adapter.gd'),original);fs.writeFileSync(path.join(stage,'corrected-adapter.gd'),fixed);
const receipt={success:results.length===3&&results.every(r=>r.success),results,parentFile,parentSha256:fileHash(parentFile),descriptorFile,descriptorSha256:fileHash(descriptorFile),engine,pins,fixtureSha256:hash(fixtureBytes),originalAdapterSha256:hash(original),correctedAdapterSha256:hash(fixed),gpu:false,serverConnections:0};
fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2));
console.log(JSON.stringify({success:receipt.success,stage,results:results.map(r=>({name:r.name,success:r.success,exitCode:r.exitCode,native:r.native}))},null,2));
if(!receipt.success)process.exitCode=1;
