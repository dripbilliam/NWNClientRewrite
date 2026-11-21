import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a fresh pause-protocol evidence label');
const directory=path.join(project,'.cache/native-client-pause-protocol',label);if(fs.existsSync(directory))throw Error('Existing evidence retained');fs.mkdirSync(directory,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Source escapes workspace');
 const source=fs.readFileSync(file,'utf8');inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(file)});
 for(const match of source.matchAll(/(?:from\s*|require\(\s*|import\s*)['"](\.[^'"]+)['"]/g)){
  let target=path.resolve(path.dirname(file),match[1]);if(!fs.existsSync(target)&&fs.existsSync(target+'.js'))target+='.js';
  if(fs.existsSync(target)&&fs.statSync(target).isFile())include(target);
 }
}
const tests=['test/native-client-pause-message.test.js','test/native-client-pause-session.test.js','test/network-game-session.test.js'];
for(const file of tests)include(path.join(workspace,file));include(fileURLToPath(import.meta.url));
const oracle=path.join(workspace,'backups/animations/native-client-pause-observations.json');inputs.set(oracle,{path:path.relative(workspace,oracle).replaceAll('\\','/'),sha256:hash(oracle)});
const result=spawnSync(process.execPath,['--test','--test-timeout=5000',...tests],{cwd:workspace,windowsHide:true,encoding:'utf8',timeout:20000,maxBuffer:2*1024*1024});
fs.writeFileSync(path.join(directory,'stdout.log'),result.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),result.stderr??'');
const changedInputs=[...inputs].filter(([file,row])=>hash(file)!==row.sha256).map(([,row])=>row.path);
const checks=Number(/# tests (\d+)/.exec(result.stdout??'')?.[1]??0),failed=Number(/# fail (\d+)/.exec(result.stdout??'')?.[1]??0);
const proof={success:result.status===0&&!result.error&&!changedInputs.length&&checks>0&&failed===0,checks,failed,exitCode:result.status,error:result.error?.message??null,signal:result.signal,inputs:[...inputs.values()],changedInputs,engineRuns:0,serverConnections:0,keyReads:0,nativeBuilds:0,userProcessActions:0,gpu:false,scope:'Actual module3/9 wire decoder, NetworkGameSession ordered receipt and decoded scene-capture admission with authored packets. Pure native receiver trace comparisons and existing session regressions. No client-clock/Host/Godot timing, live server, native process, profile/key access, renderer or pixels.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,directory}));process.exitCode=proof.success?0:1;
