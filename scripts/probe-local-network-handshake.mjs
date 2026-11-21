import dgram from 'node:dgram';
import fs from 'node:fs/promises';
import path from 'node:path';
import {NetworkCrypto} from '../electron/network_crypto.mjs';
import {NetworkKeyExchange} from '../src/network_key_exchange.js';

const host='127.0.0.1',port=Number(process.argv[2]??5121),output=process.argv[3]??'backups/animations/local-network-handshake-v1.json';
if(!Number.isInteger(port)||port<1||port>65535)throw new Error('Invalid local server port');
const log=await fs.readFile('runtime-logs/local-multiplayer-server/logs/nwengineLog.txt','utf8');
const expected=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];
if(!expected)throw new Error('Local server cryptographic public identity is unavailable');
const report={endpoint:{host,port},serverPublicKey:expected,packets:[],diagnostics:[]},crypto=new NetworkCrypto();
const exchange=new NetworkKeyExchange(crypto,{expectedServerPublicKey:Uint8Array.from(Buffer.from(expected,'base64')),onDiagnostic:d=>report.diagnostics.push(d)}),socket=dgram.createSocket('udp4');
let bound=false;
const save=async()=>{await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');};
try{
 await new Promise((resolve,reject)=>{socket.once('error',reject);socket.bind(0,host,()=>{socket.removeListener('error',reject);bound=true;resolve();});});
 const start=await exchange.begin();
 await new Promise((resolve,reject)=>{
  let queue=Promise.resolve();const timer=setTimeout(()=>finish(new Error('Native encrypted handshake timed out')),7000);
  const finish=error=>{clearTimeout(timer);socket.removeAllListeners('message');socket.removeAllListeners('error');if(error)reject(error);else resolve();};
  const send=bytes=>{report.packets.push({direction:'out',tag:Buffer.from(bytes.subarray(0,4)).toString('ascii'),length:bytes.length});socket.send(bytes,port,host,error=>{if(error)finish(error);});};
  socket.on('error',finish);socket.on('message',(bytes,peer)=>{
   if(peer.address!==host||peer.port!==port)return;
   queue=queue.then(async()=>{
    report.packets.push({direction:'in',tag:bytes.subarray(0,4).toString('ascii'),length:bytes.length});
    const result=await exchange.receive(bytes);
    if(result.send)send(result.send);
    if(result.failed)throw new Error('Native server key exchange failed');
    if(result.readyForLogin){report.identity=result.identity;report.stage=exchange.stage;report.serverIdentityVerified=true;finish();}
   }).catch(finish);
  });
  send(start);
 });
 await save();console.log(JSON.stringify({ok:true,...report,output}));
}catch(error){report.failure=error.message;await save();throw error;}
finally{crypto.close();if(bound)socket.close();}
