import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {isNetworkBytes} from '../src/network_bytes.js';

// One helper owns a peer's transient crypto state. Session/static private keys
// stay in that helper; do not route credential material through renderer IPC/logs.
export class NetworkCrypto {
 constructor(executable=fileURLToPath(new URL('../tooling/native/nwn-network-crypto.exe',import.meta.url))){
  this.child=spawn(executable,[],{windowsHide:true,stdio:['pipe','pipe','pipe']});this.buffer=Buffer.alloc(0);this.pending=null;this.closed=false;
  this.child.stdout.on('data',data=>this.read(data));
  this.child.on('error',()=>this.fail(new Error('Native network crypto helper is unavailable')));
  this.child.stdin.on('error',()=>this.fail(new Error('Native network crypto helper input failed')));
  this.child.on('close',()=>{this.closed=true;this.exited=true;clearTimeout(this.killTimer);this.fail(new Error('Native network crypto helper stopped'));});
  // The helper's binary protocol is on stdout. It does not emit diagnostic key
  // material; discard stderr rather than attach it to game/user logs.
  this.child.stderr.resume();
 }
 fail(error){if(this.pending){clearTimeout(this.pending.timer);this.pending.reject(error);this.pending=null;}}
 read(data){
  this.buffer=Buffer.concat([this.buffer,data]);
  if(this.buffer.length<4)return;const size=this.buffer.readUInt32LE(0);
  if(size<1||size>65537){this.fail(new Error('Invalid native network crypto response'));this.close();return;}
  if(this.buffer.length<size+4)return;
  const value=this.buffer.subarray(5,size+4),status=this.buffer[4],pending=this.pending;this.buffer=this.buffer.subarray(size+4);
  if(!pending||this.buffer.length){this.fail(new Error('Unexpected native network crypto response'));this.close();return;}
  this.pending=null;clearTimeout(pending.timer);
  if(status)pending.reject(new Error(status===2?'Native network cryptographic authentication failed':'Invalid native crypto operation'));
  else pending.resolve(Buffer.from(value));
 }
 request(op,payload=Buffer.alloc(0)){
  if(this.closed)return Promise.reject(new Error('Native network crypto helper is closed'));
  if(this.pending)return Promise.reject(new Error('Concurrent native crypto operations are unavailable'));
  if(!isNetworkBytes(payload)||payload.length>65535)return Promise.reject(new Error('Invalid native crypto request size'));
  return new Promise((resolve,reject)=>{
   const timer=setTimeout(()=>{this.fail(new Error('Native network crypto helper timed out'));this.close();},5000);
   this.pending={resolve,reject,timer};const frame=Buffer.alloc(payload.length+5);frame.writeUInt32LE(payload.length+1);frame[4]=op;frame.set(payload,5);this.child.stdin.write(frame,()=>frame.fill(0));
  });
 }
 async start(){const result=await this.request(1);if(result.length!==32)throw new Error('Invalid native key-exchange packet1');return result;}
 async finish(packet){
  if(!isNetworkBytes(packet)||packet.length!==80)throw new Error('Invalid native key-exchange packet2');
  const result=await this.request(2,packet);if(result.length!==80)throw new Error('Invalid native key-exchange packet3');
  return{packet3:result.subarray(0,48),serverPublicKey:result.subarray(48)};
 }
 async reset(){await this.request(3);}
 async applicationId(){const result=await this.request(7);if(result.length!==4)throw new Error('Invalid native application identity output');return result.readUInt32LE(0);}
 async platformIdentity(platformId,key){
  if(!Number.isInteger(platformId)||platformId<0||platformId>255||!isNetworkBytes(key)||key.length!==32)throw new Error('Invalid native platform identity input');
  const payload=Buffer.alloc(33);payload[0]=platformId;payload.set(key,1);
  try{const result=await this.request(4,payload);if(result.length!==36)throw new Error('Invalid native platform identity output');return result.toString('hex');}
  finally{payload.fill(0);}
 }
 async seal(bytes){
  if(!isNetworkBytes(bytes)||bytes.length>65466)throw new Error('Invalid native session plaintext length');
  const result=await this.request(5,bytes);if(result.length!==bytes.length+36)throw new Error('Invalid native session ciphertext length');return result;
 }
 async open(bytes){
  if(!isNetworkBytes(bytes)||bytes.length<36||bytes.length>65502)throw new Error('Invalid native session ciphertext length');
  const result=await this.request(6,bytes);if(result.length!==bytes.length-36)throw new Error('Invalid native session plaintext length');return result;
 }
 close(){
  if(this.closing)return;this.closing=true;this.closed=true;this.fail(new Error('Native network crypto helper closed'));
  if(this.exited)return;this.child.stdin.end();
  // EOF lets the C owner zero its state before exit; terminate only a stuck helper.
  this.killTimer=setTimeout(()=>this.child.kill(),500);this.killTimer.unref();
 }
}
