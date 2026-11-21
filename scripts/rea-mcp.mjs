// Version-pinned MCP launcher. Temporary target snapshots remain outside the
// research repository. No existing Ghidra project is opened by this launcher.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),packageRoot=path.join(workspace,'tooling/rea/node_modules/rea-agents');
const pkg=JSON.parse(await fs.readFile(path.join(packageRoot,'package.json')));
if(pkg.version!=='6.5.0')throw Error('REA package differs from the verified6.5.0 pin');
const native=await fs.readFile(path.join(packageRoot,'native/windows/build/rea-windows-x64.node'));
if(crypto.createHash('sha256').update(native).digest('hex')!=='665c57ab90aef0712a6aafc423c7992a88bf608bea63b370cb30c695900f9aed')throw Error('REA Windows native artifact differs from verified pin');
const root=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-rea-mcp-')),profile=path.join(root,'profile'),temporary=path.join(root,'tmp');
for(const p of[profile,temporary,path.join(profile,'AppData/Roaming'),path.join(profile,'AppData/Local')])await fs.mkdir(p,{recursive:true});
const environment={...process.env,USERPROFILE:profile,APPDATA:path.join(profile,'AppData/Roaming'),LOCALAPPDATA:path.join(profile,'AppData/Local'),TEMP:temporary,TMP:temporary,GHIDRA_INSTALL_DIR:path.resolve(workspace,'../FullDecomp/tooling/ghidra_12.1.4_PUBLIC'),JAVA_HOME:'C:/Program Files/BellSoft/LibericaJDK-21-Full',REA_ANALYSIS_PROVIDER:'ghidra',REA_GHIDRA_STARTUP_TIMEOUT_MS:'900000',NO_COLOR:'1'};
const mode=process.argv.slice(2);let command;
if(mode.length===0)command=['mcp'];
else if(mode.length===1&&mode[0]==='--doctor')command=['mcp','doctor','--json'];
else throw Error('REA launcher accepts only MCP stdio or --doctor');
const child=spawn(process.execPath,[path.join(packageRoot,'scripts/rea.mjs'),...command],{cwd:workspace,env:environment,stdio:'inherit',windowsHide:true});
for(const signal of['SIGINT','SIGTERM'])process.on(signal,()=>child.kill(signal));
const result=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code,signal)=>resolve({code,signal}));});
process.exitCode=result.code??1;
// REA owns deletion of its private projects/handles. Retain only the enclosing
// temporary profile; never weaken its ACLs or delete an active provider tree.
