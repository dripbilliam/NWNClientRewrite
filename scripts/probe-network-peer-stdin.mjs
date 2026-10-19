import fs from 'node:fs/promises';
import path from 'node:path';
import {NetworkPeer} from '../electron/network_peer.mjs';
import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {installedNetworkBuild} from '../electron/installed_network_build.mjs';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {decodeServerGameMessage,serverStatusRequest,moduleReadyRequest,clientAreaReadyRequest} from '../src/network_game_messages.js';
import {characterBlobRequest} from '../src/network_character.js';
import {NetworkWorld} from '../src/network_world.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {parseGff} from '../src/gff.js';
import {openLocalModule} from './local-module.mjs';

// Private test entry for the persistent peer. The peer itself has no timer
// terminating gameplay; the observation deadline belongs only to this probe.
if(process.stdin.isTTY)throw new Error('Network peer probe requires private stdin');
let size=0;const chunks=[];for await(const chunk of process.stdin){size+=chunk.length;if(size>16384)throw new Error('Private network request is too large');chunks.push(chunk);}
const input=Buffer.concat(chunks);let identity,peer,build,report,output;
try{
 const request=JSON.parse(input.toString('utf8'));identity=new NetworkLoginIdentity(request.credentials);delete request.credentials;
 const o=request.options??{};output=o.output;if(!o.install||!output||!o.characterFile)throw new Error('Network peer probe configuration is unavailable');
 const observationMs=o.transportObservationMs??16000;if(!Number.isInteger(observationMs)||observationMs<1000||observationMs>30000)throw new Error('Invalid peer observation duration');
 report={scope:'Persistent peer and authoritative world-state test; renderer/input not attached',packets:[],diagnostics:[],transport:{applicationFrames:[],messages:[],resources:null,character:null,receivedFrames:0}};
 const diagnose=d=>report.diagnostics.push(d),world=new NetworkWorld({onDiagnostic:diagnose});let objectRules={},delivery=Promise.resolve();
 const resources=installedNetworkResources({install:o.install}),language=await resources.languageId();build=await installedNetworkBuild(o.install);report.clientBuild=build.build;
 const log=await fs.readFile('runtime-logs/local-multiplayer-server/logs/nwengineLog.txt','utf8'),pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw new Error('Local server public identity is unavailable');
 peer=new NetworkPeer({onDiagnostic:diagnose});peer.on('packet',p=>{report.packets.push(p);if(p.direction==='in'&&p.tag==='M')report.transport.receivedFrames++;});peer.on('frame',b=>{if(o.captureApplicationData)report.transport.applicationFrames.push(Buffer.from(b).toString('hex'));});
 peer.on('message',bytes=>{delivery=delivery.then(async()=>{
  let m;
  try{m=decodeServerGameMessage(bytes,{clientBuild:build.build,objectRules:{...objectRules,objectState:id=>world.registry.get(id)?.replicated}});}catch{diagnose({code:'network.game-message-invalid',reason:'Native game-message fields are invalid',length:bytes.length});return;}
  report.transport.messages.push(m);world.apply(m);report.transport.world=world.snapshot();
  if(m.kind==='server-resources'){
   report.transport.resources=await resolveServerResources(m.requirements,{...resources,language,onDiagnostic:diagnose});
   const module=report.transport.resources.resolved.find(r=>r.kind==='nwm');if(module&&report.transport.resources.ready)objectRules=await loadNetworkObjectRules(await openLocalModule(o.install,module.resource));
   if(report.transport.resources.ready&&!report.transport.character){const bic=await fs.readFile(o.characterFile);parseGff(bic,'BIC ');report.transport.character={file:path.basename(o.characterFile),length:bic.length,uploaded:true};await peer.sendGameMessage(characterBlobRequest(bic));}
  }
  if(m.kind==='character-confirmed'&&report.transport.character)report.transport.character.confirmed=true;
  if(m.kind==='character-rejected'&&report.transport.character)report.transport.character.rejection=m.reason;
  if(m.kind==='module-info'&&report.transport.character?.confirmed&&!report.transport.moduleReadyRequested){report.transport.moduleReadyRequested=true;await peer.sendGameMessage(moduleReadyRequest());}
  if(m.kind==='client-area'){(report.transport.areaReadyRequests??=[]).push(m.area.id);await peer.sendGameMessage(clientAreaReadyRequest());}
  if(m.kind==='unsupported')diagnose({code:'network.game-message-unhandled',reason:'Native game-message handler is unavailable',major:m.major,minor:m.minor,length:m.length});
  if(m.kind==='object-updates'&&!m.complete)diagnose({code:'network.object-record-unhandled',...m.unhandled});
 }).catch(()=>{report.failure='Native game-message delivery failed';});});
 report.remote=await peer.connect(identity,{host:'127.0.0.1',port:o.port??5121,expectedServerPublicKey:Buffer.from(pin,'base64'),metadata:{connectionType:16,build:build.build,language,name:o.name??'ReplacementTest',legacyPublicKey:'',platformId:build.platformId,platformIdentifier:crypto=>build.platformIdentifier(crypto)}});report.loginAccepted=true;
 await peer.sendGameMessage(serverStatusRequest());await new Promise(resolve=>setTimeout(resolve,observationMs));await delivery;
 if(!peer.closed){await peer.disconnect();report.disconnectRequested=true;}await delivery;report.peer=peer.snapshot();
 if(report.diagnostics.some(d=>d.code==='network.peer-failed'))report.failure='Native peer failed';
}catch{report??={};report.failure='Private native network peer probe failed';}
finally{
 try{if(peer&&!peer.closed)await peer.disconnect();}catch{}build?.dispose();identity?.dispose();input.fill(0);for(const chunk of chunks)chunk.fill(0);
 if(output)await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report));if(!report?.loginAccepted||report.failure)process.exitCode=2;
}
