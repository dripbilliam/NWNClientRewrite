import {isIP} from 'node:net';
export function serverEndpoint(value){
 if(!value||typeof value.host!=='string'||!Number.isInteger(value.port)||value.port<1||value.port>65535)throw Error('Enter a server address and UDP port from 1 to 65535');
 let host=value.host.trim().toLowerCase().replace(/\.$/,'');if(host==='localhost')host='127.0.0.1';
 if(!host||host.length>253||isIP(host)===6||!isIP(host)&&(!/^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$/.test(host)||host.split('.').some(p=>!p||p.length>63||p.startsWith('-')||p.endsWith('-'))||/^[\d.]+$/.test(host)))throw Error('Enter an IPv4 address or hostname without a URL or port');
 return{host,port:value.port};
}
export const serverKey=value=>{const e=serverEndpoint(value);return e.host+':'+e.port;};
export function parseAllowedServer(value){if(typeof value!=='string'||value.split(':').length!==2)throw Error('Allowed servers must use HOST:PORT');const[host,port]=value.split(':');if(!/^\d+$/.test(port))throw Error('Invalid allowed server port');return serverEndpoint({host,port:Number(port)});}
export class ServerEndpointPolicy{
 constructor({allowed=[],internet=false,allowAny=false}={}){this.allowed=new Set([{host:'127.0.0.1',port:5121},...allowed].map(serverKey));this.internet=internet;this.allowAny=allowAny;}
 permits(value){const key=serverKey(value);return this.allowAny||this.allowed.has(key);}
 require(value){const endpoint=serverEndpoint(value);if(!this.permits(endpoint))throw Error('This server is not enabled for this session. No connection was sent.');return endpoint;}
 get localOnly(){return !this.allowAny&&this.allowed.size===1;}
}
