import dgram from 'node:dgram';
import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {serverInfoRequest,readServerQueryResponse} from '../../src/server_discovery.js';
export function scriptFloatingServerReady(info){return Boolean(info&&info.type==='info'&&info.moduleName==='ScriptFloat1'&&info.playerCount===0&&info.enforceLegalCharacters===1&&info.maximumPlayers===1&&info.allowLocalVaultCharacters===1);}
export async function queryScriptFloatingServer(output){
 const port=5129,info=await new Promise((resolve,reject)=>{const socket=dgram.createSocket('udp4');let complete=false;const finish=(error,value)=>{if(complete)return;complete=true;clearTimeout(timer);socket.close();error?reject(error):resolve(value);};const timer=setTimeout(()=>finish(Error('Owned ScriptFloating query timed out')),2500);socket.on('error',error=>finish(error));socket.on('message',(bytes,remote)=>{if(remote.address!=='127.0.0.1'||remote.port!==port)return;try{const value=readServerQueryResponse(bytes);if(value.type==='info')finish(null,value);}catch(error){finish(error);}});socket.bind(0,'127.0.0.1',()=>socket.send(serverInfoRequest(port),port,'127.0.0.1'));});
 const success=scriptFloatingServerReady(info);await fs.writeFile(output,JSON.stringify({success,endpoint:{host:'127.0.0.1',port:5129},testedAtUtc:new Date().toISOString(),info,authentication:false},null,2)+'\n',{flag:'wx'});return success;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const output=process.argv.find(value=>value.startsWith('--output='))?.slice(9);if(!output)throw Error('New explicit query receipt required');queryScriptFloatingServer(output).then(success=>{console.log(JSON.stringify({success,port:5129,authentication:false}));process.exitCode=success?0:1;}).catch(error=>{console.error(error.message);process.exitCode=1;});}
