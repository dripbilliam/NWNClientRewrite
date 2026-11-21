const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const id=process.argv.find(x=>x.startsWith('--id='))?.slice(5)??`light-guarded-${Date.now()}`;
if(!/^[a-z0-9-]+$/i.test(id))throw Error('Invalid run identifier');
const directory=path.join(project,'.cache/native-render-gap/scene',id);
if(fs.existsSync(directory))throw Error('Refusing to reuse evidence directory');
const renderer=path.join(directory,'renderer');fs.mkdirSync(renderer,{recursive:true});
const inputs=new Map(),copies=new Map();
function read(relative){const bytes=fs.readFileSync(path.join(project,relative));const digest=sha(bytes);if(inputs.has(relative)&&inputs.get(relative)!==digest)throw Error('Source changed during preparation: '+relative);inputs.set(relative,digest);return bytes;}
function put(relative,bytes){const target=path.join(renderer,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});copies.set(relative,sha(bytes));}
const original=read('systems/native_render/model_point_light.gd');
if(sha(original)!=='e803135ef951ea13d3d83267f0d671d2072e2df4d676bdf320a98fd9b4d1b9f6')throw Error('Original light changed');
const palette=read('systems/native_render/native_light_palette.gd');
if(sha(palette)!=='6d4fac94284f6f68fce745be1221ff48a6958f41ffb203bc84d37c8688d09e6f')throw Error('Accepted immutable palette changed');
const candidate=read('tools/native-render-gap/scene/model_point_light_candidate.gd');
const pending=['systems/native_render/native_light_policy.gd','systems/native_render/native_light_palette.gd'];
while(pending.length){const relative=pending.shift();if(copies.has(relative))continue;const bytes=read(relative);put(relative,bytes);for(const m of bytes.toString().matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)/g))if(!copies.has(m[1]))pending.push(m[1]);}
put('baseline/model_point_light.gd',original);put('candidate/model_point_light.gd',candidate);
function trace(bytes){return Buffer.from(bytes.toString().replace(/\b(light_color|light_energy|omni_range|omni_attenuation|light_specular|visible|shadow_enabled)=(?!=)([^;\r\n]+)/g,(_m,name,value)=>`traced_set("${name}",${value})`)+`\nvar publication_trace: Array=[]\nfunc traced_set(property: String,value: Variant)->void:\n\tpublication_trace.append([property,get(property),value])\n\tset(property,value)\n`);}
put('baseline/traced_model_point_light.gd',trace(original));put('candidate/traced_model_point_light.gd',trace(candidate));
for(const side of ['baseline','candidate'])put(`${side}/subclass.gd`,Buffer.from(`extends "res://${side}/model_point_light.gd"\nvar configure_calls:=0\nvar override_trace: Array=[]\nfunc _can_publish_final(_properties: Dictionary)->bool: return true\nfunc configure(properties: Dictionary)->void:\n\tconfigure_calls+=1\n\tsuper.configure(properties)\n\toverride_trace.append([properties.duplicate(true),light_color,light_energy,omni_range,visible,shadow_enabled])\n`));
const extra=read('tools/native-render-gap/scene/light_extended_cases.gd').toString();
let test=read('tests/native_perf140_render_light_publication_test.gd').toString();
const seam='run_case(false);run_case(true);fallback_case();trace_case(false);trace_case(true)';
if(!test.includes(seam))throw Error('Original broad fixture changed');
test=test.replace('func run()->void:',extra+'\nfunc run()->void:').replace(seam,seam+';guarded_observer_cases();guarded_subclass_case();guarded_domain_cases()');
put('tests/functional.gd',Buffer.from(test));
put('tests/partial.gd',read('tools/native-render-gap/scene/light_partial_cases.gd'));
put('project.godot',Buffer.from('config_version=5\n\n[application]\nconfig/name="Guarded light source equivalence"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');
const manifest={version:1,createdAtUtc:new Date().toISOString(),directory,renderer,engine,engineSha256:sha(fs.readFileSync(engine)),inputs:Object.fromEntries(inputs),copies:Object.fromEntries(copies),scope:'Isolated headless component equivalence; no GPU/FPS/server/main-source changes'};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2),{flag:'wx'});
if(!process.argv.includes('--run')){console.log(JSON.stringify({directory,prepared:true}));process.exit(0);}
const results=[];
for(const kind of ['functional','partial']){
 const log=path.join(directory,kind+'.engine.log'),native=path.join(directory,kind+'.native.json');
 const args=['--headless','--path',renderer,'--log-file',log,'--script',`res://tests/${kind}.gd`,'--',`--report=${native}`];
 const run=spawnSync(engine,args,{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:8*1024*1024});
 fs.writeFileSync(path.join(directory,kind+'.stdout.log'),run.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(directory,kind+'.stderr.log'),run.stderr??'',{flag:'wx'});
 const report=fs.existsSync(native)?JSON.parse(fs.readFileSync(native,'utf8')):null;
 const logText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const merged=(run.stdout??'')+'\n'+(run.stderr??'')+'\n'+logText;
 const ca=/ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:2582\)/g;
 const cleanText=merged.replace(ca,'');
 let expectedErrors=null;
 if(kind==='partial'){
  const sections=[...logText.matchAll(/PARTIAL_BEGIN (baseline|candidate) (\d+)\r?\n([\s\S]*?)PARTIAL_END \1 \2/g)];
  const pairs=new Map();for(const s of sections){const row=pairs.get(s[2])??{};row[s[1]]=[...s[3].matchAll(/^SCRIPT ERROR: (.*)$/gm)].map(m=>m[1].trim());pairs.set(s[2],row);}
  const rows=[...pairs].map(([index,row])=>({index,...row,same:JSON.stringify(row.baseline)===JSON.stringify(row.candidate)}));
  expectedErrors={sections:sections.length,rows,allPaired:rows.length===7&&rows.every(x=>Array.isArray(x.baseline)&&Array.isArray(x.candidate)&&x.same),scriptErrorPairs:rows.reduce((n,x)=>n+(x.baseline?.length??0),0)};
 }
 const clean=kind==='functional'?!/SCRIPT ERROR|ERROR:|leaked|still in use|crash/i.test(cleanText):expectedErrors?.allPaired&&expectedErrors.scriptErrorPairs>0&&!/Parse Error|Compile Error|leaked|still in use|crash|^ERROR:/im.test(cleanText);
 const result={kind,success:run.status===0&&report?.success===true&&!!clean,exitCode:run.status,error:run.error?.message??null,checks:report?.checks??0,failures:report?.failures??null,engineErrorsExpectedAndMatched:expectedErrors};
 results.push(result);
}
const changedInputs=[...inputs].filter(([p,d])=>sha(fs.readFileSync(path.join(project,p)))!==d).map(([p])=>p);
const changedCopies=[...copies].filter(([p,d])=>sha(fs.readFileSync(path.join(renderer,p)))!==d).map(([p])=>p);
const receipt={success:results.every(x=>x.success)&&!changedInputs.length&&!changedCopies.length,results,changedInputs,changedCopies,gpu:false,fpsClaim:false,serverConnections:0,manifest:'manifest.json'};
fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(receipt,null,2),{flag:'wx'});
console.log(JSON.stringify({directory,...receipt},null,2));process.exitCode=receipt.success?0:1;
