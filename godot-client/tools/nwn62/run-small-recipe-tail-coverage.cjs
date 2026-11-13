'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn62/small-recipe-b'),source=JSON.parse(fs.readFileSync(path.join(stage,'source-receipt.json')));
const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
for(const pin of [source.template,source.recipe]){assert.equal(sha(path.join(root,pin.relative)),pin.beforeSha256);assert.equal(sha(path.join(stage,pin.relative)),pin.afterSha256);}
const out=path.join(stage,'tail-coverage-f');assert(!fs.existsSync(out));fs.mkdirSync(out,{recursive:true});
const engine=path.join(root,'.tools/Godot_v4.7.2-stable_win64.exe'),fixture=path.join(root,'tools/nwn62/small-recipe-tail-coverage.gd'),report=path.join(out,'report.json'),home=path.join(out,'user');fs.mkdirSync(home,{recursive:true});
const install=path.resolve(root,'../../FullDecomp/NwnRootInstall');assert(fs.existsSync(install));
const args=['--headless','--path',root,'--script','res://tools/nwn62/small-recipe-tail-coverage.gd','--','--model-template=recipe-small','--publication-template-diagnose','--install='+install,'--report='+report];
const run=spawnSync(engine,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:90000,maxBuffer:4*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
fs.writeFileSync(path.join(out,'engine.log'),(run.stdout||'')+(run.stderr||''));
const value=fs.existsSync(report)?JSON.parse(fs.readFileSync(report,'utf8')):null;
const receipt={issue:'NWN-62',sourcePins:source,engineSha256:sha(engine),fixtureSha256:sha(fixture),exit:run.status,error:run.error?.message||'',reportSha256:value?sha(report):null,report:value,scope:'Read-only installed original tail-model eligibility and component cost; no FPS.'};
receipt.success=run.status===0&&value?.success===true&&[source.template,source.recipe].every(pin=>sha(path.join(root,pin.relative))===pin.beforeSha256);
fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({success:receipt.success,exit:run.status,error:receipt.error,rows:value?.rows,failures:value?.failures,tail:fs.readFileSync(path.join(out,'engine.log'),'utf8').slice(-800)}));
if(!receipt.success)process.exitCode=1;
