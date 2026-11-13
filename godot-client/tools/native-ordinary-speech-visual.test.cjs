const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const mode=require('./native-ordinary-speech-visual-mode.cjs');
const base=['--script-floating-visual','--run=native-script-floating-visual-v1','--native-runtime=editor','--script-floating-directory=C:/owned/server','--private-login-pipe=private-test-name'];
test('visual launch is explicit, bounded and independent from headless checks',()=>{
 assert.deepEqual(mode.options([]),{enabled:false,seconds:120});
 assert.deepEqual(mode.options(base),{enabled:true,seconds:120});
 for(const seconds of [30,120,180])assert.equal(mode.options([...base,'--visual-seconds='+seconds]).seconds,seconds);
 for(const seconds of ['0','29','181','120.0','00120','NaN','Infinity','-1'])assert.throws(()=>mode.options([...base,'--visual-seconds='+seconds]));
 assert.throws(()=>mode.options(['--visual-seconds=120']));
 for(const flag of ['--script-floating-check','--ordinary-speech-check','--native-headless','--public-servers','--native-profile','--record-loading','--action-check','--creation-check','--local-check','--native-debugger','--server=example.com'])assert.throws(()=>mode.options([...base,flag]));
 for(const prefix of ['--native-runtime=','--script-floating-directory=','--private-login-pipe=','--run='])assert.throws(()=>mode.options(base.filter(v=>!v.startsWith(prefix))));
 assert.throws(()=>mode.options(base.map(v=>v==='--native-runtime=editor'?'--native-runtime=release':v)));
 assert.throws(()=>mode.options([...base,'--native-screen=-1']));
 assert.equal(mode.options([...base,'--native-screen=1']).enabled,true);
 assert.throws(()=>mode.options([...base,'--visual-seconds=120','--visual-seconds=180']));
});
test('visual observations require exact actual connection/generation/area',()=>{
 const session={closed:false,phase:'playing',areaGeneration:7,world:{areaId:91}};
 const message={kind:'ordinary-speech-visual-ready',connection:3,scope:{connection:3,generation:7,areaId:91},window:{screen:1},speech:[{font:'ttf fnt_default_hr 16'}]};
 assert.equal(mode.scopeMatches(message,session,3),true);
 const detached=mode.payload(message,session,3);message.speech[0].font='changed';assert.equal(detached.speech[0].font,'ttf fnt_default_hr 16');
 for(const key of ['connection','generation','areaId'])assert.throws(()=>mode.payload({...message,scope:{...message.scope,[key]:-1}},session,3));
 assert.throws(()=>mode.payload({...message,connection:4},session,3));
 assert.throws(()=>mode.payload(message,{...session,closed:true},3));
 assert.throws(()=>mode.payload(message,{...session,phase:'connecting'},3));
 assert.throws(()=>mode.payload({...message,kind:'script-floating-finished'},session,3));
 assert.throws(()=>mode.payload({...message,oversized:'x'.repeat(65536)},session,3));
});
test('old strict headless guard and proof statements remain byte-identical',()=>{
 const project=path.resolve(__dirname,'..'),before=path.join(project,'.cache/ordinary-speech-visual/before-v1');
 const current=fs.readFileSync(path.join(project,'tools/native-session-host.cjs'),'utf8');
 const old=fs.readFileSync(path.join(before,'tools/native-session-host.cjs'),'utf8');
 for(const prefix of ["if(scriptFloatingCheck&&(!headless", "if(ordinarySpeechCheck&&!scriptFloatingCheck)", "if(scriptFloatingCheck&&!report.scriptFloatingProof?.success)"]){
  const line=old.split(/\r?\n/).find(v=>v.includes(prefix));assert.ok(line,prefix);assert.ok(current.includes(line),prefix);
 }
 const join=fs.readFileSync(path.join(project,'join-native.ps1'),'utf8'),oldJoin=fs.readFileSync(path.join(before,'join-native.ps1'),'utf8');
 for(const prefix of [" $floatingAllowedParameters=", " if(-not$Headless-or-not$LocalOnly", "if($OrdinarySpeechCheck-and-not$ScriptFloatingCheck)"]){const line=oldJoin.split(/\r?\n/).find(v=>v.startsWith(prefix));assert.ok(line);assert.ok(join.includes(line));}
 const headless=fs.readFileSync(path.join(project,'tools/test-native-ordinary-speech-live.ps1'),'utf8');assert.ok(headless.includes('-ScriptFloatingCheck -OrdinarySpeechCheck'));assert.ok(headless.includes('-Headless -EngineRuntime editor'));
});
test('separate graphical route keeps no-build, ephemeral key and owned endpoint',()=>{
 const project=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(project,f),'utf8');
 const join=read('join-native.ps1'),host=read('tools/native-session-host.cjs'),broker=read('tools/native-session-bootstrap.cjs'),wrapper=read('tools/test-native-ordinary-speech-visual.ps1');
 assert.ok(join.includes('if($LevelUpSourceCheck-or$ScriptFloatingCheck-or$ScriptFloatingVisual){'));
 assert.ok(join.includes("'ScriptFloatingVisual','ScriptFloatingDirectory','VisualSeconds','LocalOnly','ProtectedKeyFile','EngineRuntime','Run'"));
 assert.ok(broker.includes("'--script-floating-check','--script-floating-visual'].some(flag=>process.argv.includes(flag)))privateTestKey=await privateLogin.readPrivateKey(input)"));
 assert.ok(host.includes('localPort=scriptFloatingOwned||levelSourceCheck||creationDirectory?5129'));
 assert.ok(host.includes("if(scriptFloatingOwned)policy.allowed.delete('127.0.0.1:5121')"));
 assert.ok(host.indexOf('if(scriptFloatingVisual){\r\n    if(!localCycleEnding')<host.indexOf('// Dedicated received-script validation'));
 assert.ok(host.includes('interactive:!localCheck||recordLoading||scriptFloatingVisual'));
 assert.ok(host.includes("localCheck&&!scriptFloatingOwned?['--settings-check=true']"));
 assert.ok(host.includes("if(scriptFloatingOwned){if(key!=='installed:wizard.bic'"));
 assert.ok(wrapper.includes('-ScriptFloatingVisual -VisualSeconds $Seconds'));assert.ok(!wrapper.includes('-Headless -EngineRuntime'));
 for(const token of ['ProcessId-eq7568','ProcessId -eq 25060','FileShare]::None','NWN_DO_NOT_NAT_PUNCH',"'-port','5129','-publicserver','0'",'protectedProcesses=$floatingProcessGuards','encryptedProfiles=$floatingProfileGuards','nativeOutputs=$floatingOutputGuards','-ProtectedKeyFile $floatingAlt'])assert.ok(wrapper.includes(token),token);
 assert.ok(read('project.godot').includes('window/size/no_focus=true'));
 const probe=read('tests/native_ordinary_speech_visual_probe.gd');
 for(const forbidden of ['chat.submit','grab_focus','warp_mouse','MOUSE_MODE_CAPTURED','camera.position=','remaining=','frame_advance('])assert.ok(!probe.includes(forbidden),forbidden);
 assert.ok(probe.includes('probeAutomaticStimulus":false'));
 const entry=read('tests/native_ordinary_speech_visual_world.gd');
 assert.ok(entry.includes('if not visual_probe_started:return\n\tsuper.activate_window_from_click(event)'));
});
test('visual metadata distinguishes probe stimulus, automated admission and unknown input origin',()=>{
 const project=path.resolve(__dirname,'..');
 const probe=fs.readFileSync(path.join(project,'tests/native_ordinary_speech_visual_probe.gd'),'utf8');
 const wrapper=fs.readFileSync(path.join(project,'tools/test-native-ordinary-speech-visual.ps1'),'utf8');
 for(const [source,tokens]of [[probe,['"probeAutomaticStimulus":false','"automaticAdmission":true','"sessionInputOrigin":"unproven"']],[wrapper,['probeAutomaticStimulus=$false','automaticAdmission=$true',"sessionInputOrigin='unproven'"]]]){
  for(const token of tokens)assert.equal(source.split(token).length-1,1,token+' must be declared exactly once');
  for(const oldClaim of ['"automaticStimulus":false','automaticStimulus=$false','Root types real Chat','Root alone operates','no automatic input',', automatic input,'])assert.ok(!source.includes(oldClaim),'Removed session-wide claim: '+oldClaim);
 }
 assert.ok(wrapper.includes('admission is automated and session input origin is unproven'));
 assert.ok(probe.includes('Inherited admission is automated; session input origin remains unproven'));
});
