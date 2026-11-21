// Owned in-memory protocol tests only. Captured original bytes are read locally.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const workspace=fileURLToPath(new URL('../../',import.meta.url));
const run=process.argv.find(v=>v.startsWith('--run='))?.slice(6)??'native-players-frame-protocol-v1';
if(!/^native-players-[a-z0-9-]+$/.test(run))throw Error('Invalid owned report name');
const report=path.join(workspace,'godot-client/reports',run+'.json'),tap=report.replace(/\.json$/,'.tap');
for(const file of [report,tap]){try{await fs.access(file);}catch{continue;}throw Error('Evidence already exists');}
const tests=['godot-client/tools/native-party-input.test.mjs','godot-client/tools/native-map-input.test.mjs','test/network-game-session.test.js','test/network-party-list-native.test.js','test/network-party-command-native.test.js','test/network-hud-buttons.test.js'];
const sha=b=>createHash('sha256').update(b).digest('hex');
const files=[...tests,'godot-client/tools/test-native-players-protocol.mjs'];
for(const folder of ['src','electron'])for(const entry of await fs.readdir(path.join(workspace,folder),{withFileTypes:true}))if(entry.isFile()&&/\.(?:js|mjs|cjs)$/.test(entry.name))files.push(folder+'/'+entry.name);
const sourceSha256={};for(const file of new Set(files))sourceSha256[file]=sha(await fs.readFile(path.join(workspace,file)));
const result=spawnSync(process.execPath,['--test','--test-reporter=tap',...tests],{cwd:workspace,encoding:'utf8',maxBuffer:8*1024*1024,timeout:120000});
const text=(result.stdout??'')+(result.stderr??'');await fs.writeFile(tap,text,{flag:'wx'});
const checks=Number(text.match(/^# tests (\d+)$/m)?.[1]??0),failures=Number(text.match(/^# fail (\d+)$/m)?.[1]??-1);
let sourceUnchanged=true;for(const[file,digest]of Object.entries(sourceSha256))if(sha(await fs.readFile(path.join(workspace,file)))!==digest)sourceUnchanged=false;
const proof={success:result.status===0&&!result.error&&checks>0&&failures===0&&sourceUnchanged,checks,failures,exit:result.status,error:result.error?.message??null,sourceUnchanged,sourceSha256,tapSha256:sha(text),tests,publicConnections:0,fullPlayersParity:false,scope:'In-memory party/map/HUD packet/session and original captured party/command policy tests only; no clients or servers launched.'};
await fs.writeFile(report,JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:proof.success,checks,failures,sourceUnchanged,report}));if(!proof.success)process.exitCode=1;
