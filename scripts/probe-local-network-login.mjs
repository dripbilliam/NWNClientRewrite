import dgram from 'node:dgram';
import fs from 'node:fs/promises';
import {NetworkCrypto} from '../electron/network_crypto.mjs';
import {installedNetworkBuild} from '../electron/installed_network_build.mjs';
import {NetworkLogin} from '../src/network_login.js';
import {NetworkPacketCipher,requiresSessionEncryption} from '../electron/network_packet_cipher.mjs';
import {NetworkWindow} from '../src/network_window.js';
import {readReliableFrame} from '../src/network_frames.js';
import {disconnectRequest} from '../src/network_login_packets.js';
import {NetworkMessageAssembler,packetizeUncompressedMessage} from '../src/network_messages.js';
import {decodeServerGameMessage,serverStatusRequest,moduleReadyRequest,clientAreaReadyRequest} from '../src/network_game_messages.js';
import {resolveServerResources} from '../src/network_resources.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {characterBlobRequest} from '../src/network_character.js';
import {parseGff} from '../src/gff.js';
import path from 'node:path';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
import {NetworkWorld} from '../src/network_world.js';
import {openLocalModule} from './local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';

// Importable only: credentials are supplied by a private in-memory owner, never
// CLI arguments/environment/files. Captures deliberately omit raw auth packets.
export async function probeLocalNetworkLogin(identity,{install,output,port=5121,name='ReplacementTest',applicationId=null,timeout=12000,transportObservationMs=0,captureApplicationData=false,requestServerStatus=false,characterFile=null,enterModule=false}={}){
 if(!install||!output||!Number.isInteger(port)||port<1||port>65535)throw new Error('Local login probe settings are unavailable');
 if(!Number.isInteger(transportObservationMs)||transportObservationMs<0||transportObservationMs>30000)throw new Error('Invalid local transport observation duration');
 const resources=installedNetworkResources({install});
 const languageId=await resources.languageId();
 const host='127.0.0.1',build=await installedNetworkBuild(install),crypto=new NetworkCrypto(),socket=dgram.createSocket('udp4');
 const inflater=new NetworkMessageInflater();
 const world=new NetworkWorld({onDiagnostic:d=>report.diagnostics.push(d)});
 const report={endpoint:{host,port},clientBuild:build.build,packets:[],diagnostics:[],scope:'Local protocol probe; no renderer or player control'};
 let bound=false,login,cipher,objectRules={};
 try{
  const log=await fs.readFile('runtime-logs/local-multiplayer-server/logs/nwengineLog.txt','utf8');
  const pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw new Error('Local server public identity is unavailable');
  await new Promise((resolve,reject)=>{socket.once('error',reject);socket.bind(0,host,()=>{bound=true;socket.removeListener('error',reject);resolve();});});
  login=new NetworkLogin(crypto,identity,{port:socket.address().port,connectionType:16,build:build.build,language:languageId,applicationId:applicationId??await crypto.applicationId(),name,legacyPublicKey:'',platformId:build.platformId,platformIdentifier:await build.platformIdentifier(crypto)},
   {expectedServerPublicKey:Buffer.from(pin,'base64'),onDiagnostic:d=>report.diagnostics.push(d)});
  await new Promise((resolve,reject)=>{
   let finished=false,queue=Promise.resolve(),window,assembler,pollTimer;let timer=setTimeout(()=>finish(new Error('Native server login timed out')),timeout);
   function finish(error){if(finished)return;finished=true;clearTimeout(timer);clearInterval(pollTimer);socket.removeAllListeners('message');socket.removeAllListeners('error');if(error)reject(error);else resolve();}
   function record(direction,bytes,wire){
    const packet={direction,tag:bytes[0]===77?'M':Buffer.from(bytes.subarray(0,4)).toString('ascii').replace(/[^A-Za-z0-9]/g,'?'),length:bytes.length,wireLength:wire.length,encrypted:wire[0]===73};
    if(bytes[0]===77){const frame=readReliableFrame(bytes);packet.frame={kind:frame.kind,sequence:frame.sequence,acknowledgement:frame.acknowledgement};}
    report.packets.push(packet);
   }
   async function send(bytes){if(finished)return;const wire=cipher?await cipher.encode(bytes):bytes;if(finished)return;record('out',bytes,wire);await new Promise((resolve,reject)=>socket.send(wire,port,host,error=>error?reject(new Error('Native login send failed')):resolve()));}
   async function disconnect(){if(finished)return;clearInterval(pollTimer);await send(disconnectRequest());await crypto.reset();report.disconnectRequested=true;finish();}
   socket.on('error',()=>finish(new Error('Native login socket failed')));
   socket.on('message',(bytes,peer)=>{
    if(finished||peer.address!==host||peer.port!==port)return;
    queue=queue.then(async()=>{
     if(finished)return;
     if(cipher&&bytes[0]!==73&&requiresSessionEncryption(bytes))throw new Error('Unencrypted native session packet');
     const plain=cipher&&bytes[0]===73?await cipher.decode(bytes):bytes;
     record('in',plain,bytes);
     if(window&&plain[0]===77){
      const result=window.receive(plain,performance.now());for(const response of result.send)await send(response);
      for(const frame of result.delivered){report.transport.deliveredFrames++;if(captureApplicationData)report.transport.applicationFrames.push(Buffer.from(frame.bytes).toString('hex'));assembler.push(frame.bytes);}
      for(const message of assembler.drain()){
       let payload;try{payload=await inflater.decode(message.bytes);}catch{report.diagnostics.push({code:'network.message-decompression-failed',reason:'Native message decompression failed',length:message.bytes.length});continue;}
       try{const decoded=decodeServerGameMessage(payload,{clientBuild:build.build,objectRules:{...objectRules,objectState:id=>world.registry.get(id)?.replicated}});report.transport.messages.push(decoded);
        if(world.apply(decoded))report.transport.world=world.snapshot();
        if(decoded.kind==='server-resources'){
         report.transport.resources=await resolveServerResources(decoded.requirements,{...resources,language:languageId,onDiagnostic:d=>report.diagnostics.push(d)});
         const module=report.transport.resources.resolved.find(r=>r.kind==='nwm');
         if(report.transport.resources.ready&&module){try{objectRules=await loadNetworkObjectRules(await openLocalModule(install,module.resource));}catch{report.diagnostics.push({code:'network.object-rules-unavailable',reason:'Server module object-message rules could not be loaded'});}}
         if(characterFile&&report.transport.resources.ready&&!report.transport.character){
          report.transport.character={file:path.basename(characterFile),uploaded:false};
          try{
           // Check file structure only. Singleplayer import limitations (saved
           // effects, polymorph, local stat rules) must not override the server.
           const bytes=await fs.readFile(characterFile);parseGff(bytes,'BIC ');
           const request=characterBlobRequest(bytes);Object.assign(report.transport.character,{length:bytes.length,uploaded:true});
           for(const frame of packetizeUncompressedMessage(request))for(const response of window.enqueue(frame,performance.now()))await send(response);
          }catch{report.diagnostics.push({code:'network.character-load-failed',reason:'Selected character could not be read, validated or sent',file:path.basename(characterFile)});}
         }
        }
        if(decoded.kind==='character-confirmed'&&report.transport.character)report.transport.character.confirmed=true;
        if(decoded.kind==='character-rejected'&&report.transport.character)report.transport.character.rejection=decoded.reason;
        if(decoded.kind==='module-info'){
         report.transport.module=decoded.module;
         if(enterModule&&report.transport.resources?.ready&&report.transport.character?.confirmed&&!report.transport.moduleReadyRequested){
          report.transport.moduleReadyRequested=true;for(const frame of packetizeUncompressedMessage(moduleReadyRequest()))for(const response of window.enqueue(frame,performance.now()))await send(response);
         }
        }
        if(decoded.kind==='client-area'&&enterModule){
         (report.transport.areaReadyRequests??=[]).push(decoded.area.id);
         for(const frame of packetizeUncompressedMessage(clientAreaReadyRequest()))for(const response of window.enqueue(frame,performance.now()))await send(response);
        }
        if(decoded.kind==='object-updates'&&!decoded.complete)report.diagnostics.push({code:'network.object-record-unhandled',reason:decoded.unhandled.reason,...decoded.unhandled});
        if(decoded.kind==='unsupported')report.diagnostics.push({code:'network.game-message-unhandled',reason:'Native game-message handler is unavailable',major:decoded.major,minor:decoded.minor,length:decoded.length});
       }catch{report.diagnostics.push({code:'network.game-message-invalid',reason:'Native game-message envelope or fields are invalid',length:message.bytes.length});}
      }
      report.transport.receivedFrames++;return;
     }
     const next=await login.receive(plain);
     if(login.exchange.identity&&!cipher)cipher=new NetworkPacketCipher(crypto,login.exchange.identity);
     if(next.send)await send(next.send);
     if(next.failed){report.connectionError=login.connectionError;finish(new Error('Native server rejected login'));}
     if(next.admitted){
      report.remote=next.remote;report.loginAccepted=true;
      if(!transportObservationMs){await disconnect();return;}
      report.transport={observationMs:transportObservationMs,receivedFrames:0,deliveredFrames:0,applicationFrames:[],messages:[]};
      window=new NetworkWindow({now:performance.now(),onDiagnostic:d=>report.diagnostics.push(d)});
      assembler=new NetworkMessageAssembler({onDiagnostic:d=>report.diagnostics.push(d)});
      // HandlePlayerToServerMessage458b90 -> status45d140 accepts major1/minor0
      // with no body. This probes a verified server branch, not a claim that the
      // original client's complete starting sequence has been reconstructed.
      if(requestServerStatus){for(const frame of packetizeUncompressedMessage(serverStatusRequest()))for(const response of window.enqueue(frame,performance.now()))await send(response);report.transport.serverStatusRequested=true;}
      clearTimeout(timer);timer=setTimeout(()=>{clearInterval(pollTimer);queue=queue.then(disconnect).catch(()=>finish(new Error('Native disconnect failed')));},transportObservationMs);
      pollTimer=setInterval(()=>{queue=queue.then(async()=>{if(finished)return;for(const response of window.poll(performance.now()))await send(response);}).catch(()=>finish(new Error('Native transport poll failed')));},100);
     }
    }).catch(()=>finish(new Error('Native login processing failed')));
   });
   login.begin().then(next=>send(next.send)).catch(()=>finish(new Error('Native login start failed')));
  });
 }catch(error){report.failure=error.message;}
 finally{
  report.phase=login?.phase??'setup';inflater.close();crypto.close();build.dispose();if(bound)socket.close();
  await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');
 }
 return report;
}
