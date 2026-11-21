// Authorized project-scoped registration. Preserve the user's global config.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {reaResearchTools} from './rea-tool-policy.mjs';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),require=createRequire(path.join(workspace,'tooling/rea/package.json')),{parse}=await import(pathToFileURL(require.resolve('smol-toml')).href);
const file=path.join(workspace,'.codex/config.toml'),hash=value=>crypto.createHash('sha256').update(value).digest('hex');
let before='';try{before=await fs.readFile(file,'utf8');}catch(error){if(error.code!=='ENOENT')throw error;}
const section={command:process.execPath,args:[path.join(workspace,'scripts/rea-mcp.mjs')],cwd:workspace,startup_timeout_sec:30,tool_timeout_sec:1200,required:true,enabled_tools:[...reaResearchTools]};
const existing=before?parse(before):{};
if(existing.mcp_servers?.rea_nwn){if(JSON.stringify(existing.mcp_servers.rea_nwn)!==JSON.stringify(section))throw Error('Different rea_nwn configuration exists; preserve and reconcile it explicitly');console.log('REA registration already matches');process.exit(0);}
const encode=value=>JSON.stringify(value),block='\n[mcp_servers.rea_nwn]\n'+Object.entries(section).map(([key,value])=>`${key} = ${encode(value)}`).join('\n')+'\n',after=before+block;
const check=parse(after);if(JSON.stringify(check.mcp_servers.rea_nwn)!==JSON.stringify(section))throw Error('Registration parse/readback failed');
await fs.mkdir(path.dirname(file),{recursive:true});let backup=null;
if(before){backup=file+'.rea-before-'+hash(before).slice(0,12);await fs.writeFile(backup,before,{flag:'wx'});if(await fs.readFile(backup,'utf8')!==before)throw Error('Configuration backup failed');}
await fs.writeFile(file+'.rea-pending',after,{flag:'wx'});await fs.rename(file+'.rea-pending',file);
if(await fs.readFile(file,'utf8')!==after)throw Error('Written configuration differs');
await fs.writeFile(path.join(workspace,'backups/animations/rea-integration-registration.json'),JSON.stringify({file,backup,scope:'project',beforeSha256:hash(before),afterSha256:hash(after),server:section,originalPrefixPreserved:after.startsWith(before)},null,2)+'\n');
console.log(JSON.stringify({registered:true,file,scope:'project',tools:reaResearchTools.length,startupTimeout:30,toolTimeout:1200,backup}));
