// Isolated CLI trial. Never registers REA, opens a user Ghidra project, or
// executes the inspected game. REA's transient target snapshots stay in OS temp,
// outside this repository; evidence/logs contain metadata and analysis only.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),trial=path.join(workspace,'backups/rea-trial');
const [name,...args]=process.argv.slice(2);if(!/^[a-z0-9-]+$/.test(name??'')||!args.length)throw Error('Use: rea-trial-run.mjs LOG_NAME CLI_ARGS...');
const admitted=new Set(['--version','doctor\0--provider\0ghidra\0--json','function\0--help','mcp\0doctor\0--help','mcp\0doctor\0--json']);
const functionQuery=args.length===7&&args[0]==='function'&&path.isAbsolute(args[1])&&/^0x[0-9a-f]+$/i.test(args[2])&&args.slice(3).join('\0')==='--provider\0ghidra\0--format\0json';
if(!admitted.has(args.join('\0'))&&!functionQuery)throw Error('Trial permits only version/help, scoped read-only diagnostics, and static function queries; setup/registration/snapshots/execution are refused');
const baselineFile=path.join(trial,'baseline.json'),stateFile=path.join(trial,'environment.json');
const controls=[path.resolve(workspace,'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe'),path.resolve(workspace,'../FullDecomp/ghidra-projects/NWN-EE-8193.37-17.gpr'),path.join(os.userInfo().homedir,'.codex/config.toml'),...['package.json','package-lock.json'].map(n=>path.join(workspace,n))];
async function hashes(){return Promise.all(controls.map(async file=>{try{const bytes=await fs.readFile(file);return{file,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};}catch(error){if(error.code==='ENOENT')return{file,absent:true};throw error;}}));}
let baseline;try{baseline=JSON.parse(await fs.readFile(baselineFile));}catch(error){if(error.code!=='ENOENT')throw error;baseline=await hashes();await fs.writeFile(baselineFile,JSON.stringify(baseline,null,2)+'\n');}
let state;try{state=JSON.parse(await fs.readFile(stateFile));}catch(error){if(error.code!=='ENOENT')throw error;const root=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-rea-trial-'));state={root,created:new Date().toISOString()};await fs.writeFile(stateFile,JSON.stringify(state,null,2)+'\n');}
const profile=path.join(state.root,'profile'),temporary=path.join(state.root,'tmp');for(const p of[profile,temporary,path.join(profile,'AppData/Roaming'),path.join(profile,'AppData/Local')])await fs.mkdir(p,{recursive:true});
const environment={...process.env,USERPROFILE:profile,APPDATA:path.join(profile,'AppData/Roaming'),LOCALAPPDATA:path.join(profile,'AppData/Local'),TEMP:temporary,TMP:temporary,GHIDRA_INSTALL_DIR:path.resolve(workspace,'../FullDecomp/tooling/ghidra_12.1.4_PUBLIC'),JAVA_HOME:'C:/Program Files/BellSoft/LibericaJDK-21-Full',REA_ANALYSIS_PROVIDER:'ghidra',REA_GHIDRA_STARTUP_TIMEOUT_MS:'600000',NO_COLOR:'1'};
const executable=path.join(trial,'runner/node_modules/rea-agents/scripts/rea.mjs');
const out=await fs.open(path.join(trial,`${name}.json`),'w'),err=await fs.open(path.join(trial,`${name}.stderr.txt`),'w'),start=Date.now();let result;
try{
 const child=spawn(process.execPath,[executable,...args],{cwd:trial,env:environment,windowsHide:true,stdio:['ignore',out.fd,err.fd]});
 result=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code,signal)=>resolve({code,signal}));});
}finally{await out.close();await err.close();}
const after=await hashes(),unchanged=JSON.stringify(after)===JSON.stringify(baseline),report={name,args,...result,durationMs:Date.now()-start,controlsUnchanged:unchanged,isolatedRoot:state.root};
await fs.writeFile(path.join(trial,`${name}.run.json`),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
if(!unchanged)throw Error('Protected input/configuration hash changed; inspect baseline and stop');process.exitCode=result.code??1;
