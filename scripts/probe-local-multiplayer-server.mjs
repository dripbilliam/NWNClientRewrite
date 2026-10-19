import dgram from 'node:dgram';
import fs from 'node:fs/promises';
import path from 'node:path';
import {serverDiscoveryRequest,serverInfoRequest,readServerQueryResponse} from '../src/server_discovery.js';

const host=process.argv[2]??'127.0.0.1',port=Number(process.argv[3]??5121),output=process.argv[4]??'backups/animations/local-server-query-v1.json';
// Restrict this research probe to the explicitly owned local test server.
if(host!=='127.0.0.1')throw new Error('This probe targets the local test server only');
if(!Number.isInteger(port)||port<1||port>65535)throw new Error('Invalid server port');
const socket=dgram.createSocket('udp4'),report={endpoint:{host,port},requests:[],responses:[]};let bound=false;
const writeReport=async()=>{await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');};
try{
 await new Promise((resolve,reject)=>{socket.once('error',reject);socket.bind(0,host,()=>{socket.removeListener('error',reject);resolve();});});
 bound=true;
 const response=new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>{cleanup();reject(new Error('Native server discovery/info timed out'));},5000);
  const cleanup=()=>{clearTimeout(timer);socket.removeListener('message',message);socket.removeListener('error',error);};
  const error=e=>{cleanup();reject(e);};
  const message=(bytes,peer)=>{
   if(peer.address!==host||peer.port!==port)return;
   try{
    const parsed=readServerQueryResponse(bytes);
    report.responses.push({hex:bytes.toString('hex'),...parsed,...(parsed.advertisement?{advertisement:Buffer.from(parsed.advertisement).toString('hex')}:{})});
    if(report.responses.some(r=>r.type==='discovery')&&report.responses.some(r=>r.type==='info')){cleanup();resolve();}
   }catch(e){cleanup();reject(e);}
  };
  socket.on('error',error);socket.on('message',message);
 });
 for(const bytes of [serverDiscoveryRequest(socket.address().port),serverInfoRequest(socket.address().port)]){
  report.requests.push(Buffer.from(bytes).toString('hex'));
  socket.send(bytes,port,host,error=>{if(error)socket.emit('error',error);});
 }
 await response;
 await writeReport();
 console.log(JSON.stringify({ok:true,endpoint:report.endpoint,responses:report.responses.map(({hex,advertisement,...rest})=>rest),output}));
}catch(error){report.failure=error.message;await writeReport();throw error;}
finally{if(bound)socket.close();}
