// Only explicitly owned loopback fixtures; no authentication or public query.
import fs from 'node:fs/promises';
import dgram from 'node:dgram';
import {pathToFileURL} from 'node:url';
import {serverInfoRequest,readServerQueryResponse} from '../../src/server_discovery.js';
import {read} from './native-direct-handoff-fixture.mjs';
export function ready(info,server){return Boolean(info&&info.type==='info'&&info.moduleName===server.module&&info.playerCount===0&&info.enforceLegalCharacters===1&&info.maximumPlayers===1&&info.allowLocalVaultCharacters===1);}
export async function query(directory,label,output){
 const fixture=await read(directory),server=fixture.servers.find(s=>s.label===label);if(!server)throw Error('Owned A/B label required');
 const info=await new Promise((resolve,reject)=>{const socket=dgram.createSocket('udp4');let done=false;const finish=(error,value)=>{if(done)return;done=true;clearTimeout(timer);socket.close();error?reject(error):resolve(value);};const timer=setTimeout(()=>finish(Error('Owned direct-handoff query timed out')),2500);socket.on('error',e=>finish(e));socket.on('message',(bytes,remote)=>{if(remote.address!=='127.0.0.1'||remote.port!==server.port)return;try{const value=readServerQueryResponse(bytes);if(value.type==='info')finish(null,value);}catch(error){finish(error);}});socket.bind(0,'127.0.0.1',()=>socket.send(serverInfoRequest(server.port),server.port,'127.0.0.1'));});
 const success=ready(info,server);await fs.writeFile(output,JSON.stringify({success,label,endpoint:{host:server.host,port:server.port},fixtureSha256:fixture.descriptorSha256,info,authentication:false},null,2)+'\n',{flag:'wx'});return success;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)query(process.argv[2],process.argv[3],process.argv[4]).then(success=>{console.log(JSON.stringify({success,authentication:false}));process.exitCode=success?0:1;}).catch(error=>{console.error(error.message);process.exitCode=1;});
