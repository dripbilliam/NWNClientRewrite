'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const project=path.resolve(__dirname,'..');
test('actual bootstrap isolates new private test key and preserves normal saved-login branch',async()=>{
 const source=fs.readFileSync(path.join(project,'tools/native-session-bootstrap.cjs'),'utf8'),line=source.split(/\r?\n/).find(value=>value.includes("if(['--action-check','--local-check','--creation-check'"));assert.ok(line);
 const run=new Function('process','privateLogin','input','settings','return(async()=>{let privateTestKey="";'+line+'\nelse await privateLogin.savePrivateLogin(input,settings);return privateTestKey;})();');
 for(const flag of ['--script-floating-check','--action-check','--creation-check','--local-check',null]){const calls=[],result=await run({argv:flag?[flag]:[]},{readPrivateKey:async()=>{calls.push('private-read');return 'AUTHORED_UNIT_SENTINEL';},savePrivateLogin:async()=>calls.push('save')},{},{});assert.deepEqual(calls,flag?['private-read']:['save']);assert.equal(result,flag?'AUTHORED_UNIT_SENTINEL':'');}
});
test('new join parameters parse and missing private/isolation arguments reject before any build/key/process',()=>{
 const join=path.join(project,'join-native.ps1'),command='$e=$null;$t=$null;[Management.Automation.Language.Parser]::ParseFile($args[0],[ref]$t,[ref]$e)|Out-Null;if($e.Count){exit 8};$p=(Get-Command $args[0]).Parameters;if(-not$p.ContainsKey("ScriptFloatingCheck")-or-not$p.ContainsKey("ScriptFloatingDirectory")){exit 9};try{& $args[0] -ScriptFloatingCheck -Headless -LocalOnly;exit 10}catch{if($_.Exception.Message-ne"ScriptFloating requires its exclusive protected headless original-local editor check"){exit 11}}';
 const encoded=Buffer.from('& { '+command+' } '+"'"+join.replaceAll("'","''")+"'",'utf16le').toString('base64'),result=spawnSync('pwsh',['-NoProfile','-EncodedCommand',encoded],{encoding:'utf8',windowsHide:true,timeout:10000});assert.equal(result.status,0,result.stderr||result.error?.message);
});
