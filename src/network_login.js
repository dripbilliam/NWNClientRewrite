import {NetworkKeyExchange} from './network_key_exchange.js';
import {connectRequest,validationResponse,readConnectResponse,readValidationResponse} from './network_login_packets.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {isNetworkBytes} from './network_bytes.js';

const diagnose=({code,reason,...context})=>runtimeDiagnostics.record(code,reason,context,'warning');
// Remote connection's authenticated login boundary. UDP retry scheduling and
// post-admission reliable transport have separate owners. Identity is injected
// by the main process; never attach credentials or response bodies to telemetry.
export class NetworkLogin{
 #identity;#metadata;
 constructor(crypto,identity,metadata,{expectedServerPublicKey=null,onDiagnostic=diagnose}={}){
  this.#identity=identity;this.#metadata={...metadata,build:{...metadata.build}};
  this.onDiagnostic=onDiagnostic;this.exchange=new NetworkKeyExchange(crypto,{expectedServerPublicKey,onDiagnostic});
  this.phase='new';this.connectionError=0;this.remote=null;
 }
 async begin(){if(this.phase!=='new')throw new Error('Native login has already started');const send=await this.exchange.begin();this.phase='key-exchange';return{send};}
 unsupported(reason,tag){this.onDiagnostic({code:'network.login-unhandled',reason,tag,phase:this.phase});return{accepted:false};}
 async receive(bytes){
  if(!isNetworkBytes(bytes)||bytes.length<4)return this.unsupported('Truncated login packet','');
  const tag=String.fromCharCode(...bytes.subarray(0,4));
  if(this.phase==='key-exchange'){
   if(!['BNK0','BNK2','BNK4'].includes(tag))return this.unsupported('Unexpected packet during key exchange',tag);
   const result=await this.exchange.receive(bytes);
   if(result.failed){this.phase='rejected';this.connectionError=this.exchange.connectionError;return result;}
   if(result.readyForLogin){
    const send=connectRequest({...this.#metadata,publicKey:this.#identity.publicKey});
    this.phase='connect';return{accepted:true,send};
   }
   return result;
  }
  try{
   if(tag==='BNCR'&&['connect','validate'].includes(this.phase)){
    const response=readConnectResponse(bytes);
    if(response.kind==='rejected')return this.reject(response.connectionError,tag);
    if(response.trailingBytes)this.onDiagnostic({code:'network.login-trailing-bytes',reason:'Native connection response has trailing bytes',tag,count:response.trailingBytes});
    const proof=this.#identity.respond(response),send=validationResponse(proof);this.connectionError=proof.connectionError;
    this.phase='validate';return{accepted:true,send,passwordRequired:response.passwordRequired};
   }
   if(tag==='BNVR'&&this.phase==='validate'){
    const response=readValidationResponse(bytes);
    if(response.kind==='rejected')return this.reject(response.connectionError,tag);
    this.remote=Object.freeze({applicationId:response.applicationId,build:Object.freeze(response.build)});
    this.phase='admitted';this.connectionError=0;return{accepted:true,admitted:true,remote:this.remote};
   }
  }catch{
   // Codec/credential errors must never include wire bodies or secret text.
   return this.unsupported('Invalid native login response or identity operation',tag);
  }
  return this.unsupported('Packet is outside the current login phase',tag);
 }
 reject(connectionError,tag){this.phase='rejected';this.connectionError=connectionError;this.onDiagnostic({code:'network.login-rejected',reason:'Native server rejected login',tag,connectionError});return{accepted:true,failed:true,connectionError};}
}
