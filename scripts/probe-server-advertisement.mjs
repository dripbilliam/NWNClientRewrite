// Public BNXI discovery only: no identity, login or character upload.
import dgram from 'node:dgram';
import {lookup} from 'node:dns/promises';
import fs from 'node:fs/promises';
import {serverInfoRequest,readServerQueryResponse} from '../src/server_discovery.js';
const [host,portText,output]=process.argv.slice(2),port=Number(portText);if(!host||!Number.isInteger(port)||port<1||port>65535||!output)throw new Error('Host, port and report path are required');
const address=(await lookup(host,{family:4})).address,socket=dgram.createSocket('udp4');let timer;
try{await new Promise((resolve,reject)=>{socket.once('error',reject);socket.bind(0,'0.0.0.0',resolve);});const reply=await new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('Public server discovery timed out')),12000);socket.once('error',reject);socket.on('message',(bytes,peer)=>{if(peer.address!==address||peer.port!==port)return;try{const result=readServerQueryResponse(bytes);if(result.type==='info')resolve(result);}catch{}});socket.send(serverInfoRequest(socket.address().port),port,address,error=>{if(error)reject(error);});});const {advertisement,...info}=reply,report={endpoint:{host,address,port},...info,advertisementBytes:advertisement.length,advertisementHex:Buffer.from(advertisement).toString('hex')};await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}finally{clearTimeout(timer);socket.close();}
