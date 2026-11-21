import fs from 'node:fs/promises';
import path from 'node:path';
import {NetworkPeer} from '../electron/network_peer.mjs';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {installedNetworkBuild} from '../electron/installed_network_build.mjs';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {openLocalModule} from './local-module.mjs';

// Headless admission/lifecycle integration test. This explicitly acknowledges
// parsed areas; it does not claim that an app renderer loaded the assets.
if(process.stdin.isTTY)throw new Error('Network session probe requires private stdin');
let size=0;const chunks=[];
for await(const chunk of process.stdin){size+=chunk.length;if(size>16384)throw new Error('Private network request is too large');chunks.push(chunk);}
const input=Buffer.concat(chunks);let identity,build,session,peer,output,report;
try{
 const request=JSON.parse(input.toString('utf8'));identity=new NetworkLoginIdentity(request.credentials);delete request.credentials;
 const options=request.options??{};output=options.output;
 if(!options.install||!output||!options.characterFile)throw new Error('Network session probe configuration is unavailable');
 const duration=options.transportObservationMs??16000;
 if(!Number.isInteger(duration)||duration<1000||duration>30000)throw new Error('Invalid session observation duration');
 report={scope:'Headless application-session admission, authoritative state and clean disconnect; no renderer or gameplay input',messages:[],states:[],diagnostics:[],packets:[]};
 const diagnose=d=>report.diagnostics.push(d),resources=installedNetworkResources({install:options.install}),language=await resources.languageId();
 build=await installedNetworkBuild(options.install);report.clientBuild=build.build;
 const log=await fs.readFile('runtime-logs/local-multiplayer-server/logs/nwengineLog.txt','utf8'),pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];
 if(!pin)throw new Error('Local server public identity is unavailable');
 peer=new NetworkPeer({onDiagnostic:diagnose});peer.on('packet',p=>report.packets.push(p));
 session=new NetworkGameSession({peer,identity,build,resources,language,openModule:module=>openLocalModule(options.install,module),onDiagnostic:diagnose});
 session.on('state',state=>report.states.push(state));
 const acknowledgements=[];
 session.on('message',event=>{
  report.messages.push(event.message);
  if(event.message.kind==='client-area')acknowledgements.push(session.areaReady(event.areaGeneration).catch(()=>{report.failure='Headless area acknowledgement failed';}));
 });
 const bic=await fs.readFile(options.characterFile);
 try{await session.selectCharacter(bic);report.character={file:path.basename(options.characterFile),length:bic.length};}finally{bic.fill(0);}
 await session.connect({host:'127.0.0.1',port:options.port??5121,expectedServerPublicKey:Buffer.from(pin,'base64'),metadata:{connectionType:16,build:build.build,language,name:options.name??'ReplacementTest',legacyPublicKey:'',platformId:build.platformId,platformIdentifier:crypto=>build.platformIdentifier(crypto)}});
 report.loginAccepted=true;await new Promise(resolve=>setTimeout(resolve,duration));await session.delivery;await Promise.all(acknowledgements);
 report.beforeDisconnect=session.state();const player=session.world.registry.get(session.world.localObjectId);report.playerState=structuredClone(player?.playerState??null);
 await session.disconnect();report.afterDisconnect=session.state();report.peer=peer.snapshot();
 if(report.diagnostics.some(d=>d.code==='network.peer-failed'||d.code==='network.game-session-failed'))report.failure='Native application session failed';
}catch{report??={};report.failure='Private native application session probe failed';}
finally{
 try{if(session)await session.disconnect();else{if(peer)await peer.disconnect();identity?.dispose();build?.dispose();}}catch{}
 input.fill(0);for(const chunk of chunks)chunk.fill(0);
 if(output)await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report));if(!report.loginAccepted||report.failure)process.exitCode=2;
}
