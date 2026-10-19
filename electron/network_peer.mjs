import dgram from 'node:dgram';
import {lookup} from 'node:dns/promises';
import {EventEmitter} from 'node:events';
import {NetworkCrypto} from './network_crypto.mjs';
import {NetworkPacketCipher,requiresSessionEncryption} from './network_packet_cipher.mjs';
import {NetworkMessageInflater} from './network_message_inflater.mjs';
import {NetworkLogin} from '../src/network_login.js';
import {NetworkWindow} from '../src/network_window.js';
import {NetworkMessageAssembler,packetizeUncompressedMessage} from '../src/network_messages.js';
import {disconnectRequest} from '../src/network_login_packets.js';
import {readReliableFrame} from '../src/network_frames.js';
import {isNetworkBytes} from '../src/network_bytes.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';

// Main-process connection owner. It has no observation-duration limit and no
// resource, character, renderer or local simulation policy. Game messages are
// delivered to the session owner, which controls admission/area readiness.
// Credentials and native crypto state never appear in emitted packet metadata.
export class NetworkPeer extends EventEmitter {
 constructor({crypto=new NetworkCrypto(),onDiagnostic=d=>runtimeDiagnostics.record(d.code,d.reason,d)}={}){
  super();this.crypto=crypto;this.onDiagnostic=onDiagnostic;this.inflater=new NetworkMessageInflater();this.queue=Promise.resolve();this.started=false;this.closed=false;this.disconnecting=false;
 }
 diagnose(d){this.onDiagnostic(d);this.emit('diagnostic',d);}
 enqueue(task){const result=this.queue.then(()=>{if(this.closed)throw new Error('Native network peer is closed');return task();});this.queue=result.catch(()=>{this.finish(new Error('Native network peer operation failed'));});return result;}
 async connect(identity,{host,port=5121,metadata,expectedServerPublicKey=null,timeout=12000}={}){
  if(this.started||this.closed)throw new Error('Native network peer has already started');this.started=true;
  if(typeof host!=='string'||!host.length||!Number.isInteger(port)||port<1||port>65535||!metadata||!Number.isInteger(timeout)||timeout<1||timeout>120000){this.finish();throw new Error('Invalid native network connection settings');}
  this.port=port;
  try{
   this.host=(await lookup(host,{family:4})).address;
   if(this.closed)throw new Error('Native network connection closed');
   this.socket=dgram.createSocket('udp4');
   this.socket.on('error',()=>this.finish(new Error('Native network socket failed')));
   await new Promise((resolve,reject)=>{
    this.socket.once('error',reject);this.socket.bind(0,'0.0.0.0',()=>{this.bound=true;this.socket.removeListener('error',reject);if(this.closed){this.socket.close();this.bound=false;}resolve();});
   });
   if(this.closed)throw new Error('Native network connection closed');
   const nativeMetadata={...metadata,port:this.socket.address().port,applicationId:metadata.applicationId??await this.crypto.applicationId()};
   if(typeof nativeMetadata.platformIdentifier==='function')nativeMetadata.platformIdentifier=await nativeMetadata.platformIdentifier(this.crypto);
   if(this.closed)throw new Error('Native network connection closed');
   this.login=new NetworkLogin(this.crypto,identity,nativeMetadata,{expectedServerPublicKey,onDiagnostic:d=>this.diagnose(d)});
   this.socket.on('message',(bytes,peer)=>{
    if(this.closed||peer.address!==this.host||peer.port!==this.port)return;
    void this.enqueue(()=>this.receive(Uint8Array.from(bytes)));
   });
   const admitted=new Promise((resolve,reject)=>{this.resolveConnect=resolve;this.rejectConnect=reject;});
   this.connectTimer=setTimeout(()=>this.finish(new Error('Native network login timed out')),timeout);
   void this.enqueue(async()=>{const next=await this.login.begin();await this.send(next.send);});
   return await admitted;
  }catch(error){this.finish();throw new Error(error?.message==='Native network login timed out'?error.message:'Native network connection failed');}
 }
 packet(direction,plain,wire){
  const p={direction,tag:plain[0]===77?'M':Buffer.from(plain.subarray(0,4)).toString('ascii').replace(/[^A-Za-z0-9]/g,'?'),length:plain.length,wireLength:wire.length,encrypted:wire[0]===73};
  if(plain[0]===77){const f=readReliableFrame(plain);p.frame={kind:f.kind,sequence:f.sequence,acknowledgement:f.acknowledgement};}this.emit('packet',p);
 }
 async send(plain){
  const wire=this.cipher?await this.cipher.encode(plain):plain;if(this.closed)throw new Error('Native network peer is closed');
  this.packet('out',plain,wire);await new Promise((resolve,reject)=>this.socket.send(wire,this.port,this.host,e=>e?reject(new Error('Native network send failed')):resolve()));
 }
 async receive(bytes){
  if(this.cipher&&bytes[0]!==73&&requiresSessionEncryption(bytes))throw new Error('Unencrypted native session packet');
  const plain=this.cipher&&bytes[0]===73?await this.cipher.decode(bytes):bytes;this.packet('in',plain,bytes);
  if(this.window&&plain[0]===77){
   const result=this.window.receive(plain,performance.now());for(const response of result.send)await this.send(response);
   for(const frame of result.delivered){this.emit('frame',Uint8Array.from(frame.bytes));this.assembler.push(frame.bytes);}
   for(const message of this.assembler.drain()){
    let payload;
    try{payload=await this.inflater.decode(message.bytes);}catch{this.diagnose({code:'network.message-decompression-failed',reason:'Native message decompression failed',length:message.bytes.length});this.finish(new Error('Native message stream failed'));return;}
    this.emit('message',payload);
   }
   return;
  }
  const tag=String.fromCharCode(...plain.subarray(0,4));
  if(this.window&&tag==='BNDP'){this.diagnose({code:'network.server-disconnected',reason:'Native server closed the connection'});this.finish();return;}
  const next=await this.login.receive(plain);
  if(this.login.exchange.identity&&!this.cipher)this.cipher=new NetworkPacketCipher(this.crypto,this.login.exchange.identity);
  if(next.send)await this.send(next.send);
  if(next.failed){this.finish(new Error('Native server rejected login'));return;}
  if(next.admitted){
   this.window=new NetworkWindow({now:performance.now(),onDiagnostic:d=>this.diagnose(d)});this.assembler=new NetworkMessageAssembler({onDiagnostic:d=>this.diagnose(d)});
   this.pollTimer=setInterval(()=>{if(!this.closed&&!this.disconnecting)void this.enqueue(async()=>{for(const response of this.window.poll(performance.now()))await this.send(response);});},100);
   clearTimeout(this.connectTimer);this.resolveConnect?.(next.remote);this.resolveConnect=this.rejectConnect=null;this.emit('admitted',next.remote);
  }
 }
 sendGameMessage(bytes){
  if(!isNetworkBytes(bytes)||bytes.length<3||bytes[0]!==112)throw new Error('Invalid native player request');
  if(this.closed||this.disconnecting||this.login?.phase!=='admitted'||!this.window)return Promise.reject(new Error('Native game connection is not ready'));
  const frames=packetizeUncompressedMessage(Uint8Array.from(bytes));
  return this.enqueue(async()=>{
   if(this.disconnecting||this.login?.phase!=='admitted'||!this.window)throw new Error('Native game connection is not ready');
   for(const frame of frames)for(const response of this.window.enqueue(frame,performance.now()))await this.send(response);
  });
 }
 disconnect(){
  if(this.closed)return Promise.resolve();if(this.disconnectPromise)return this.disconnectPromise;
  this.disconnecting=true;clearInterval(this.pollTimer);
  this.disconnectPromise=this.enqueue(async()=>{try{if(this.login?.phase==='admitted'){await this.send(disconnectRequest());await this.crypto.reset();}}finally{this.finish();}});return this.disconnectPromise;
 }
 finish(error=null){
  if(this.closed)return;this.closed=true;clearTimeout(this.connectTimer);clearInterval(this.pollTimer);this.inflater.close();this.crypto.close();
  if(this.bound){try{this.socket.close();}catch{}}
  if(this.rejectConnect)this.rejectConnect(error??new Error('Native network connection closed'));this.resolveConnect=this.rejectConnect=null;
  if(error)this.diagnose({code:'network.peer-failed',reason:error.message});this.emit('closed',{failed:Boolean(error)});
 }
 snapshot(){return{phase:this.closed?'closed':this.login?.phase??'new',loginPhase:this.login?.phase??'new',closed:this.closed,admitted:this.login?.phase==='admitted'&&!this.closed};}
}
