'use strict';
// Bounded metadata/syntax gates. Does not launch Godot, WMI, a game or a replay.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'../../../..'),[baselineLabel,candidateLabel,outputLabel]=process.argv.slice(2);
for(const value of [baselineLabel,candidateLabel,outputLabel])if(!/^[a-z0-9-]+$/.test(value??''))throw Error('Two prepared labels and a fresh output label are required');
const output=path.join(project,'.cache/native-render-gap/scene',outputLabel);if(fs.existsSync(output))throw Error('Existing checks remain frozen');fs.mkdirSync(output);
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),adapter=require('./replay-adapter.cjs'),checks=[];
function check(label,action){action();checks.push(label);}
async function main(){
 for(const label of [baselineLabel,candidateLabel]){
  const folder=path.join(project,'.cache/native-render-gap/replays',label),preparation=JSON.parse(fs.readFileSync(path.join(folder,'preparation.json')));
  const selection=await adapter.readSelection(preparation.selection.file,preparation.selection.sha256);checks.push('Exact prepared route '+selection.normalIntegration.route);
  const syntax=spawnSync(process.execPath,['--check',preparation.driver.file],{windowsHide:true,encoding:'utf8',timeout:10000});assert.equal(syntax.status,0,syntax.stderr);checks.push('Generated replay driver syntax '+label);
  const mutations=[
   ['production-claim',s=>{s.production=true;}],['wrong-kind',s=>{s.kind='production-replay-selection';}],
   ['wrong-route',s=>{s.normalIntegration.route='unknown';}],['source-escape',s=>{s.sourceProject=path.dirname(s.sourceProject);}],
   ['changed-flags',s=>{s.flags.push('--motion-facing=native');}],['wrong-profile',s=>{s.profiling='true';}],
   ['wrong-thread',s=>{s.engineArguments=[];s.renderThread='safe';}],['wrong-module',s=>{s.particleLoop.module.file=path.join(folder,'not-loaded.dll');}]
  ];
  for(const [name,mutate]of mutations){
   const changed=structuredClone(selection);delete changed.evidence;mutate(changed);const file=path.join(folder,'rejected-'+outputLabel+'-'+name+'.json'),bytes=Buffer.from(JSON.stringify(changed));fs.writeFileSync(file,bytes,{flag:'wx'});
   await assert.rejects(adapter.readSelection(file,sha(bytes)),undefined,'Negative selection admitted: '+name);checks.push('Rejected '+selection.normalIntegration.route+' '+name);
  }
  await assert.rejects(adapter.readSelection(preparation.selection.file,'0'.repeat(64)));checks.push('Rejected changed selection hash '+label);
  const missing=adapter.verifyNative(selection,{});assert.equal(missing.status,'rejected');checks.push('Missing native executable/thread/owner evidence rejects '+label);
  const policy=require('./audit-policy.cjs').normalPolicyChecks;
  const expected={world:{drive_collision_configuration:{effective:selection.featureSelection['drive-collision'].value},focus_lighting:{light_input_registry:{effective:selection.featureSelection['light-input-registry'].value}}},runtime_features:{rendering:{render_thread_requirement:selection.renderThread==='default'?'not-requested':'matched',render_thread:{observed:true,main_thread_id:1,thread_id:selection.renderThread==='separate'?5:1,separate:selection.renderThread==='separate'}}}};
  check('Normal audit requires the actual declared owner and observed thread IDs '+label,()=>assert.deepEqual(policy(selection,expected),{owners:true,thread:true}));
  for(const [name,mutate]of [['missing-ids',x=>{delete x.runtime_features.rendering.render_thread.thread_id;}],['unobserved-thread',x=>{x.runtime_features.rendering.render_thread.observed=false;}],['wrong-thread-relation',x=>{x.runtime_features.rendering.render_thread.separate=!x.runtime_features.rendering.render_thread.separate;}],['wrong-requirement',x=>{x.runtime_features.rendering.render_thread_requirement='pending';}]]){const value=structuredClone(expected);mutate(value);check('Normal audit rejects '+name+' '+label,()=>assert.equal(policy(selection,value).thread,false));}
  const wrongOwner=structuredClone(expected);wrongOwner.world.focus_lighting.light_input_registry.effective='unknown';check('Normal audit rejects wrong actual owner '+label,()=>assert.equal(policy(selection,wrongOwner).owners,false));
  if(selection.normalIntegration.route==='candidate'){assert(missing.errors.some(message=>message.includes('bundle evidence is missing')));checks.push('Missing full12-route cold evidence rejects');}
 }
 const original=fs.readFileSync(path.join(project,'tools/native-render-gap/watch-module-v3.ps1'),'utf8');
 const expected=original.replace("(Join-Path $PSScriptRoot '../..')","(Join-Path $PSScriptRoot '../../../..')").replace('$particleExpected=$particleSelection.particleLoop.module',()=>"$particleExpected=$particleSelection.particleLoop.module\n$particleEngineName=[IO.Path]::GetFileName([string]$particleSelection.engine)\nif($particleEngineName-notmatch'^[A-Za-z0-9_.-]+\\.exe$'){throw 'Selected executable basename is invalid'}").replace("Name = 'godot.windows.template_release.x86_64.exe'","Name = '$particleEngineName'");
 const observer=path.join(__dirname,'watch-module-v4.ps1');check('Observer preserves every V3 provenance/lifetime gate apart from dynamic basename and own directory',()=>assert.equal(fs.readFileSync(observer,'utf8'),expected));
 const originalAudit=fs.readFileSync(path.join(project,'.cache/native-presentation-parity/root/fps-max-v1/audit-case.cjs'),'utf8');
 const expectedAudit=originalAudit.replace("const project=path.resolve('godot-client'),folder=__dirname,hash=file=>","const project=path.resolve(__dirname,'../../../..'),folder=path.join(project,'.cache/native-render-gap/scene/normal-replay-audits'),hash=file=>").replace("owners:w.drive_collision_configuration.effective==='indexed'&&w.focus_lighting.light_input_registry.effective==='builtin',thread:n.runtime_features.rendering.render_thread_requirement==='matched'&&n.runtime_features.rendering.render_thread.separate===true","...require('./audit-policy.cjs').normalPolicyChecks(s,n)").replace(" const out=path.join(folder,run+'.audit.json');"," fs.mkdirSync(folder,{recursive:true});const out=path.join(folder,run+'.audit.json');");
 check('Private normal audit preserves every existing camera/quality/movement/lifetime/source gate',()=>assert.equal(fs.readFileSync(path.join(__dirname,'audit-case.cjs'),'utf8'),expectedAudit));
 for(const basename of ['godot.windows.template_release.x86_64.exe','Godot_v4.7.2-stable_win64.exe','Godot_native_core_v4_1_win64.exe'])check('Observer valid selected basename '+basename,()=>assert.match(basename,/^[A-Za-z0-9_.-]+\.exe$/));
 for(const basename of ["x.exe' OR Name LIKE '%'",'../wrong.exe','no extension','x.exe;Remove-Item'])check('Observer invalid basename rejects '+basename,()=>assert.doesNotMatch(basename,/^[A-Za-z0-9_.-]+\.exe$/));
 const syntax=spawnSync('pwsh.exe',['-NoProfile','-NonInteractive','-File',path.join(__dirname,'parse-observer.ps1'),'-FileToParse',observer],{windowsHide:true,encoding:'utf8',timeout:10000});
 fs.writeFileSync(path.join(output,'observer-parser.stdout.log'),syntax.stdout??'',{flag:'wx'});fs.writeFileSync(path.join(output,'observer-parser.stderr.log'),syntax.stderr??'',{flag:'wx'});assert.equal(syntax.status,0,syntax.stderr);checks.push('Dynamic observer full PowerShell syntax');
 const receipt={version:1,success:true,production:false,installed:false,created:new Date().toISOString(),baselineLabel,candidateLabel,checks,observer:{file:observer,sha256:sha(fs.readFileSync(observer))},scope:'Private normal replay source/runtime selection, negative metadata gates, generated driver syntax and dynamic-basename observer preservation only. No WMI/process or GPU/FPS/local-authority evidence.'};
 fs.writeFileSync(path.join(output,'acceptance.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,success:true,checks:checks.length}));
}
main().catch(error=>{fs.writeFileSync(path.join(output,'failure.json'),JSON.stringify({success:false,error:error.stack,checks},null,2),{flag:'wx'});console.error(error.stack);process.exitCode=1;});
