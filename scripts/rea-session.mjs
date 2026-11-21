// Persistent local MCP client for the current shell session. Codex's configured
// catalog is picked up after reload; this client can use the same launcher now.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createInterface} from 'node:readline';
import {reaResearchTools} from './rea-tool-policy.mjs';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),require=createRequire(path.join(workspace,'tooling/rea/package.json'));
const {Client}=await import(pathToFileURL(require.resolve('@modelcontextprotocol/client')).href),{StdioClientTransport}=await import(pathToFileURL(require.resolve('@modelcontextprotocol/client/stdio')).href);
const transport=new StdioClientTransport({command:process.execPath,args:[path.join(workspace,'scripts/rea-mcp.mjs')],cwd:workspace,stderr:'pipe'}),client=new Client({name:'nwn-native-research',version:'1.0.0'},{capabilities:{}});
transport.stderr?.on('data',data=>{void fs.appendFile(path.join(workspace,'runtime-logs/rea-session-stderr.txt'),data);});
await client.connect(transport);const listing=await client.listTools(),available=listing.tools.filter(t=>reaResearchTools.includes(t.name)),directory=path.join(workspace,'backups/animations');
await fs.writeFile(path.join(directory,'rea-native-tool-catalog.json'),JSON.stringify(available,null,2)+'\n');
console.log(JSON.stringify({ready:true,tools:available.map(t=>t.name),unavailablePolicyNames:reaResearchTools.filter(n=>!available.some(t=>t.name===n))}));
const lines=createInterface({input:process.stdin,terminal:false});
try{for await(const line of lines){
 if(!line.trim())continue;let request;
 try{
  request=JSON.parse(line);if(request.close){console.log(JSON.stringify({closing:true}));break;}
  if(!/^[a-z0-9-]+$/.test(request.id??''))throw Error('A lowercase evidence ID is required');
  const tool=available.find(t=>t.name===(request.schema??request.name));if(!tool)throw Error('Tool is outside the native research policy');
  // MCP SDK2 passes request options as argument2 (SDK1 used argument3).
  const result=request.schema?tool:await client.callTool({name:request.name,arguments:request.arguments??{}},{timeout:1200000});
  const target=path.join(directory,`rea-${request.id}.json`);await fs.writeFile(target,JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify({id:request.id,saved:target,isError:result.isError??false}));
 }catch(error){console.log(JSON.stringify({id:request?.id,error:error.message}));}
}}finally{await client.close();}
