import dgram from 'node:dgram';
import {lookup} from 'node:dns/promises';
import {abortable} from './network_abort.mjs';
import {serverDiscoveryRequest,serverInfoRequest,serverDetailsRequest,readServerQueryResponse,readServerInfoAdvertisement} from '../src/server_discovery.js';
// Endpoint displayed by the original Internet browser; never server-specific.
export async function fetchNetworkServerList({signal}={}){
 const response=await fetch('https://api.nwn.beamdog.net/v1/servers',{signal:signal?AbortSignal.any([signal,AbortSignal.timeout(20000)]):AbortSignal.timeout(20000)});if(!response.ok)throw new Error('Internet server list returned HTTP '+response.status);let size=0;const chunks=[];
 for await(const chunk of response.body){size+=chunk.length;if(size>8*1024*1024)throw new Error('Internet server list exceeds the supported size');chunks.push(chunk);}const rows=JSON.parse(Buffer.concat(chunks,size).toString('utf8'));if(!Array.isArray(rows)||rows.length>10000)throw new Error('Invalid Internet server list');
 return rows.filter(row=>typeof row.host==='string'&&row.host.length<=255&&Number.isInteger(row.port)&&row.port>0&&row.port<=65535).map(row=>({host:row.host,port:row.port,serverName:String(row.session_name??'').slice(0,256),moduleName:String(row.module_name??'').slice(0,256),description:String(row.module_description??'').slice(0,8192),playerCount:row.current_players,maximumPlayers:row.max_players,minimumLevel:row.min_level,maximumLevel:row.max_level,pvpSetting:row.pvp,gameType:row.game_type,allowLocalVaultCharacters:!row.servervault,passwordRequired:Boolean(row.passworded),latency:row.latency}));
}
export async function queryNetworkServer({host,port,timeout=3500,signal,extended=false}){
 if(typeof host!=='string'||!host.trim()||host.length>255||!Number.isInteger(port)||port<1||port>65535)throw new Error('Invalid server endpoint');
 signal?.throwIfAborted();
 const address=(await abortable(lookup(host.trim(),{family:4}),signal)).address,socket=dgram.createSocket('udp4');let timer,info,serverName,details,expired=false;
 try{
  await new Promise((resolve,reject)=>{socket.once('error',reject);socket.bind(0,'0.0.0.0',resolve);});
  signal?.throwIfAborted();
  return await abortable(new Promise((resolve,reject)=>{const done=()=>{if(info&&serverName!==undefined&&(!extended||details||expired)){try{const {advertisement,...fields}=info;resolve({host:host.trim(),address,port,serverName,...fields,...details,...(details?{description:details.moduleDescription||details.gameDetails||''}:{}),extendedReceived:Boolean(details),advertisement:readServerInfoAdvertisement(advertisement)});}catch{reject(new Error('Invalid server information advertisement'));}}};
   timer=setTimeout(()=>{expired=true;if(info){serverName??=host;done();}else reject(new Error('Server information request timed out'));},timeout);socket.once('error',()=>reject(new Error('Server information request failed')));
   socket.on('message',(bytes,peer)=>{if(peer.address!==address||peer.port!==port)return;try{const response=readServerQueryResponse(bytes);if(response.type==='info')info=response;else if(response.type==='details')details=response;else if(response.section===0)serverName=response.serverName;done();}catch{}});
   const local=socket.address().port;for(const bytes of [serverInfoRequest(local),serverDiscoveryRequest(local),...(extended?[serverDetailsRequest(local)]:[])])socket.send(bytes,port,address,error=>{if(error)reject(new Error('Server information request failed'));});
  }),signal);
 }finally{clearTimeout(timer);socket.close();}
}
