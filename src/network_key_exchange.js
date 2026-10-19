// Native remote-connect path: StartConnect254ed0, BNK2 242320, BNK4 242c60,
// BNK0 241c30 (addresses relative to140000000, pinned EE89.8193.37-17).
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {isNetworkBytes} from './network_bytes.js';
const recordDiagnostic=({code,reason,...context})=>runtimeDiagnostics.record(code,reason,context,code==='network.key-exchange-rejected'?'warning':'error');
const packet=(tag,body=new Uint8Array())=>{const out=new Uint8Array(4+body.length);out.set([...tag].map(c=>c.charCodeAt(0)));out.set(body,4);return out;};
export class NetworkKeyExchange {
 constructor(crypto,{expectedServerPublicKey=null,onDiagnostic=recordDiagnostic}={}){
  if(expectedServerPublicKey!==null&&(!isNetworkBytes(expectedServerPublicKey)||expectedServerPublicKey.length!==32))throw new Error('Invalid expected server public key');
  Object.assign(this,{crypto,onDiagnostic});this.expectedServerPublicKey=expectedServerPublicKey===null?null:Uint8Array.from(expectedServerPublicKey);this.stage=0;this.identity=0;this.haveSessionKeys=false;this.connectionError=0;this.serverPublicKey=null;this.failed=false;
 }
 async begin(){if(this.stage||this.failed)throw new Error('Key exchange has already started');const body=await this.crypto.start();this.stage=1;return packet('BNK1',body);}
 reject(reason,tag){this.onDiagnostic({code:'network.key-exchange-rejected',reason,tag,stage:this.stage});return{accepted:false};}
 async abort(reason){await this.crypto.reset();this.stage=0;this.identity=0;this.haveSessionKeys=false;this.connectionError=0x13;this.serverPublicKey=null;this.failed=true;this.onDiagnostic({code:'network.key-exchange-failed',reason});return{accepted:true,send:packet('BNK0'),failed:true};}
 async receive(bytes){
  if(!isNetworkBytes(bytes)||bytes.length<4)return this.reject('Truncated key-exchange packet','');
  const tag=String.fromCharCode(...bytes.subarray(0,4));
  if(tag==='BNK0'){
   if(this.stage>=3)return this.reject('Key reset after one-sided completion',tag);
   await this.crypto.reset();this.stage=0;this.identity=0;this.haveSessionKeys=false;this.connectionError=0x13;this.serverPublicKey=null;this.failed=true;
   this.onDiagnostic({code:'network.key-exchange-failed',reason:'Server rejected key exchange'});return{accepted:true,failed:true};
  }
  if(tag==='BNK2'){
   if(bytes.length!==84||this.stage>=3||this.failed)return this.reject('Invalid packet2 length or stage',tag);
   let next;try{next=await this.crypto.finish(bytes.subarray(4));}catch{return this.abort('Key exchange authentication failed');}
   if(!isNetworkBytes(next.serverPublicKey)||next.serverPublicKey.length!==32||!isNetworkBytes(next.packet3)||next.packet3.length!==48)throw new Error('Invalid native key-exchange provider output');
   if(this.expectedServerPublicKey&&this.expectedServerPublicKey.some((v,i)=>v!==next.serverPublicKey[i]))return this.abort('Server cryptographic identity mismatch');
   this.stage=3;this.haveSessionKeys=true;this.serverPublicKey=Uint8Array.from(next.serverPublicKey);return{accepted:true,send:packet('BNK3',next.packet3)};
  }
  if(tag==='BNK4'){
   if(bytes.length!==8||!this.haveSessionKeys||this.stage<3||this.identity!==0||this.failed)return this.reject('Invalid completion length or stage',tag);
   this.identity=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength).getUint32(4,true);
   return{accepted:true,readyForLogin:true,identity:this.identity};
  }
  return this.reject('Unsupported key-exchange packet',tag);
 }
}
