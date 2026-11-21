import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2];if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(workspace,'godot-client/.cache/level-up-gui-tests',label);if(fs.existsSync(directory))throw Error('Existing evidence preserved');fs.mkdirSync(directory,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Source escapes workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(/\.m?js$/.test(file))for(const match of bytes.toString().matchAll(/(?:from|import)\s*["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(file),match[1]));
}
for(const file of ['test/native-level-up-gui.test.js','test/network-level-up.test.js','backups/animations/native-levelup-wire-v1.json'])include(path.join(workspace,file));include(fileURLToPath(import.meta.url));
for(const [file,row]of inputs){const target=path.join(directory,'inputs',row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed while copied');}
const child=spawnSync(process.execPath,['--test','test/native-level-up-gui.test.js','test/network-level-up.test.js'],{cwd:workspace,encoding:'utf8',windowsHide:true,timeout:45000});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const stdout=child.stdout??'',tests=Number(stdout.match(/^# tests (\d+)$/m)?.[1]??0),passed=Number(stdout.match(/^# pass (\d+)$/m)?.[1]??0),failed=Number(stdout.match(/^# fail (\d+)$/m)?.[1]??0);
const proof={success:child.status===0&&!child.error&&tests===16&&passed===16&&failed===0&&changed.length===0,tests,passed,failed,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs:changed,directory,nodeVersion:process.version,scope:'Actual Session begin/cancel private transaction and original GUI16 writer/decoder plus existing original48-case level-up wire regression. No original-server or full-flow/pixel acceptance.',serverConnections:0,nativeBuilds:0,gpu:false};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:proof.inputs.length}));process.exitCode=proof.success?0:1;
