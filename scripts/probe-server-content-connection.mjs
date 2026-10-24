// Real initial server connection and fresh NWSync downloads. No character is
// uploaded and no gameplay/chat is sent. Credentials arrive only through the
// existing one-use encrypted in-memory bridge; no raw wire packets are saved.
import fs from 'node:fs/promises';
import path from 'node:path';
import net from 'node:net';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {NetworkPeer} from '../electron/network_peer.mjs';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {installedNetworkBuild} from '../electron/installed_network_build.mjs';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {decodeServerGameMessage,serverStatusRequest} from '../src/network_game_messages.js';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {serverCharacterListRequest} from '../src/network_character_selection.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const digest=data=>crypto.createHash('sha1').update(data).digest('hex');
async function privateInput(){
 const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3),port=Number(option('private-input-port')),token=option('private-input-token');
 if(!Number.isInteger(port)||port<1||port>65535||!/^[0-9a-f]{64}$/.test(token??''))throw new Error('Private content-test input is unavailable');
 const pair=crypto.generateKeyPairSync('x25519'),stream=net.connect({host:'127.0.0.1',port}),chunks=[];let size=0;stream.setTimeout(10000,()=>stream.destroy(new Error('Private input timed out')));
 stream.write(JSON.stringify({token,publicKey:pair.publicKey.export({format:'der',type:'spki'}).toString('base64')})+'\n');
 for await(const chunk of stream){size+=chunk.length;if(size>32768){stream.destroy();throw new Error('Private input exceeds the supported size');}chunks.push(chunk);}
 const envelope=JSON.parse(Buffer.concat(chunks).toString('utf8')),publicKey=crypto.createPublicKey({key:Buffer.from(envelope.publicKey,'base64'),format:'der',type:'spki'}),shared=crypto.diffieHellman({privateKey:pair.privateKey,publicKey}),key=Buffer.from(crypto.hkdfSync('sha256',shared,Buffer.from(token),'nwn-renderer-probe-input',32));shared.fill(0);let bytes;
 try{const decipher=crypto.createDecipheriv('aes-256-gcm',key,Buffer.from(envelope.iv,'base64'));decipher.setAuthTag(Buffer.from(envelope.tag,'base64'));bytes=Buffer.concat([decipher.update(Buffer.from(envelope.ciphertext,'base64')),decipher.final()]);return JSON.parse(bytes.toString('utf8'));}
 finally{key.fill(0);bytes?.fill(0);for(const chunk of chunks)chunk.fill(0);}
}
let request,session,resources,peer,identity,build,timer,timeout,output,saveQueue=Promise.resolve(),finishWait;
const report={scope:'Initial remote server connection, new isolated cache, native NWSync reuse disabled, no character upload',startedAt:new Date().toISOString(),stage:'private-input',states:[],diagnostics:[],diagnosticCounts:{},packets:{in:0,out:0},downloads:{requests:0,completed:0,bytes:0,statuses:{},manifests:[],objectsRequested:0},reads:[]},requestedObjects=new Set(),completedObjects=new Set(),manifestSummaries=new Map();
const save=()=>{if(!output)return Promise.resolve();report.elapsedSeconds=Number(((Date.now()-Date.parse(report.startedAt))/1000).toFixed(1));report.downloads.distinctObjectsRequested=requestedObjects.size;report.downloads.distinctObjectsCompleted=completedObjects.size;report.downloads.manifests=[...manifestSummaries.values()];const snapshot=JSON.stringify(report,null,2)+'\n';saveQueue=saveQueue.then(async()=>{const temporary=output+'.tmp';await fs.writeFile(temporary,snapshot);await fs.rename(temporary,output);});return saveQueue;};
function diagnostic(d){report.diagnosticCounts[d.code]=(report.diagnosticCounts[d.code]??0)+1;if(report.diagnostics.length<200)report.diagnostics.push({...d});}
async function auditedFetch(url,options){
 const parsed=new URL(url),parts=parsed.pathname.split('/'),hash=parts.at(-1),kind=parsed.pathname.includes('/manifests/')?'manifest':'object';report.downloads.requests++;if(kind==='object'){report.downloads.objectsRequested++;requestedObjects.add(hash);}
 const response=await fetch(url,options);report.downloads.statuses[response.status]=(report.downloads.statuses[response.status]??0)+1;if(!response.body)return response;
 const chunks=[];let bytes=0;const body=response.body.pipeThrough(new TransformStream({transform(chunk,controller){bytes+=chunk.length;report.downloads.bytes+=chunk.length;if(kind==='manifest'&&bytes<=64*1024*1024)chunks.push(chunk);controller.enqueue(chunk);},flush(){
  report.downloads.completed++;if(response.ok&&kind==='object')completedObjects.add(hash);
  if(kind==='manifest'&&response.ok){try{const raw=Buffer.concat(chunks,bytes),manifest=parseNWSyncManifest(raw),unique=[...new Map(manifest.entries.map(entry=>[entry.hash,entry])).values()];manifestSummaries.set(hash,{hash,downloadHashMatches:digest(raw)===hash,bytes,version:manifest.version,resources:manifest.entries.length,uniqueObjects:unique.length,uncompressedBytes:unique.reduce((sum,entry)=>sum+entry.size,0),twoDATables:manifest.entries.filter(entry=>entry.type===2017).length});}catch(error){manifestSummaries.set(hash,{hash,bytes,error:error.message});}}
 }}));return new Response(body,{status:response.status,statusText:response.statusText,headers:response.headers});
}
try{
 request=await privateInput();const options=request.options;output=path.resolve(options.output);if(!output.startsWith(path.join(workspace,'backups','animations')+path.sep))throw new Error('Content-test report must remain inside the workspace evidence directory');
 const runDirectory=path.resolve(options.directory);if(runDirectory.startsWith(workspace+path.sep))throw new Error('Downloaded game resources must remain outside the research workspace');
 if(!Number.isInteger(options.port)||!options.host||!Number.isInteger(options.timeoutMs)||options.timeoutMs<1000||options.timeoutMs>7200000)throw new Error('Invalid content-test connection settings');
 await fs.mkdir(path.dirname(runDirectory),{recursive:true});await fs.mkdir(runDirectory,{recursive:false});const cacheDirectory=path.join(runDirectory,'cache'),profile=path.join(runDirectory,'profile');await fs.mkdir(cacheDirectory);await fs.mkdir(profile);report.cache={directory:cacheDirectory,initialEntries:(await fs.readdir(cacheDirectory)).length,reuseInstalledNWSync:false};if(report.cache.initialEntries!==0)throw new Error('The cold content cache is not empty');report.endpoint={host:options.host,port:options.port};report.stage='initial-connection';await save();
 identity=new NetworkLoginIdentity(request.credentials);for(const name of Object.keys(request.credentials))request.credentials[name]='';delete request.credentials;
 build=await installedNetworkBuild(options.install);resources=installedNetworkResources({install:options.install,userDirectory:profile,cacheDirectory,reuseInstalledNWSync:false,onDiagnostic:diagnostic,contentOptions:{fetch:auditedFetch}});if(resources.sourcePolicy.reuseInstalledNWSync!==false)throw new Error('Installed NWSync reuse was not disabled');
 const language=await resources.languageId();peer=new NetworkPeer({onDiagnostic:diagnostic});peer.on('packet',packet=>report.packets[packet.direction]++);
 if(options.loginOnly){
  report.scope='Encrypted initial login only; no resource, character or gameplay request';
  report.remote=await peer.connect(identity,{host:options.host,port:options.port,timeout:20000,metadata:{connectionType:16,build:build.build,language,name:options.name??'ReplacementTest',legacyPublicKey:'',platformId:build.platformId,platformIdentifier:crypto=>build.platformIdentifier(crypto)}});
  report.loginAccepted=true;report.endpoint.address=peer.host;report.success=true;report.stage='completed-before-resource-negotiation';
  if(options.requestRequirements){
   report.scope='Encrypted initial login and server resource advertisement only; no character or gameplay request';
   let resolveRequirements;const requirements=new Promise((resolve,reject)=>{resolveRequirements=resolve;timeout=setTimeout(()=>reject(new Error('Server resource advertisement timed out')),15000);});
   peer.on('message',bytes=>{try{const message=decodeServerGameMessage(bytes,{clientBuild:build.build,objectRules:{}});if(message.kind==='server-resources'){report.requirements=message.requirements;resolveRequirements();}}catch{report.advertisementDecodeFailures=(report.advertisementDecodeFailures??0)+1;}});
   await peer.sendGameMessage(serverStatusRequest());await requirements;clearTimeout(timeout);report.stage='completed-after-resource-advertisement';
   if(options.requestCharacterList){let resolveList;const listed=new Promise((resolve,reject)=>{resolveList=resolve;timeout=setTimeout(()=>reject(new Error('Server character list timed out')),15000);});peer.on('message',bytes=>{try{const message=decodeServerGameMessage(bytes,{clientBuild:build.build,objectRules:{}});if(message.kind==='server-character-list'){report.serverCharacters=message.characters;resolveList();}}catch{report.characterListDecodeFailures=(report.characterListDecodeFailures??0)+1;}});await peer.sendGameMessage(serverCharacterListRequest());await listed;clearTimeout(timeout);report.stage='completed-after-server-character-list';}
  }
 }else{
 session=new NetworkGameSession({peer,identity,build,resources,language,onDiagnostic:diagnostic,openModule:(...args)=>resources.openModule(...args),decodeMessage:(bytes,context)=>{
  const message=decodeServerGameMessage(bytes,context);if(message.kind==='server-resources'){report.requirements=message.requirements;report.stage='downloading-server-content';void save();}return message;
 }});
 session.on('state',state=>{report.phase=state.phase;report.progress=state.resourceProgress;report.resourcesReady=state.resourcesReady;report.characterUploaded=state.characterUploaded;if(report.states.at(-1)?.phase!==state.phase)report.states.push({phase:state.phase,at:new Date().toISOString()});if(['character-selection','resources-unavailable','closed'].includes(state.phase))finishWait?.();});
 timer=setInterval(()=>{void save().catch(()=>{});console.log(JSON.stringify({stage:report.stage,phase:report.phase,progress:report.progress,downloadedMiB:Number((report.downloads.bytes/1048576).toFixed(1)),objects:completedObjects.size,elapsedSeconds:report.elapsedSeconds}));},15000);
 const terminal=new Promise((resolve,reject)=>{finishWait=resolve;timeout=setTimeout(()=>{report.timedOut=true;reject(new Error('Initial server content test timed out'));void session.disconnect();},options.timeoutMs);});terminal.catch(()=>{});
 await session.connect({host:options.host,port:options.port,timeout:20000,metadata:{connectionType:16,build:build.build,language,name:options.name??'ReplacementTest',legacyPublicKey:'',platformId:build.platformId,platformIdentifier:crypto=>build.platformIdentifier(crypto)}});report.loginAccepted=true;report.serverBuild=session.serverBuild;report.endpoint.address=peer.host;await terminal;
 if(session.phase!=='character-selection'||!session.resolver)throw new Error('Server content did not reach the character-selection boundary');
 report.stage='reading-downloaded-rules';await save();const selected=[...new Map(session.resourceResult.resolved.filter(entry=>entry.kind==='nwsync').map(entry=>[entry.name,entry.resource])).values()].reverse();
 for(const name of ['classes','racialtypes','skills','feat','spells','baseitems','appearance','domains','metamagic','iprp_spells']){
  const provider=selected.find(layer=>layer.hasResource(name,RESOURCE_TYPE.TWO_DA));if(!provider){report.reads.push({name,serverOverride:false});continue;}
  const expected=provider.catalog.get(`${name}:${RESOURCE_TYPE.TWO_DA}`),bytes=await session.getResource(name,RESOURCE_TYPE.TWO_DA),table=parse2da(decodeResourceText(bytes));if(digest(Buffer.from(bytes))!==expected.hash||!completedObjects.has(expected.hash))throw new Error('Rule data was not read from a verified fresh download');
  report.reads.push({name,serverOverride:true,manifest:provider.name,sha1:expected.hash,downloadedThisRun:true,bytes:bytes.byteLength,rows:table.orderedRows.length,columns:table.columns});
 }
 const custom=session.resourceResult.resolved.find(entry=>entry.kind==='tlk');if(custom){const primary=typeof custom.resource==='string'?null:custom.resource;if(!primary)throw new Error('Custom TLK resolved to a pre-existing physical file');const bytes=Buffer.from(await primary.arrayBuffer()),hash=digest(bytes);if(!completedObjects.has(hash))throw new Error('Custom TLK was not freshly downloaded');report.customTlk={name:custom.name,sha1:hash,bytes:bytes.length,downloadedThisRun:true};}
 const entries=await fs.readdir(path.join(cacheDirectory,'objects'));report.cache.objects=entries.length;report.cache.compressedBytes=(await Promise.all(entries.map(async name=>(await fs.stat(path.join(cacheDirectory,'objects',name))).size))).reduce((sum,n)=>sum+n,0);report.success=true;report.stage='completed-before-character-upload';report.characterUploaded=Boolean(session.characterUploaded);await save();
 }
}catch(error){report.failure=error.message;report.failureCode=error.code??null;report.failedStage=report.stage;report.stage='failed';}
finally{
 clearInterval(timer);clearTimeout(timeout);if(request?.credentials)for(const name of Object.keys(request.credentials))request.credentials[name]='';
 try{await session?.disconnect();await session?.delivery;}catch{report.cleanupFailure=true;}resources?.close();if(!session){identity?.dispose();build?.dispose();await peer?.disconnect();}report.finishedAt=new Date().toISOString();await save().catch(()=>{});console.log(JSON.stringify({success:report.success??false,stage:report.stage,failure:report.failure,downloadedMiB:Number((report.downloads.bytes/1048576).toFixed(1)),objects:completedObjects.size,reads:report.reads.map(row=>({name:row.name,rows:row.rows,downloadedThisRun:row.downloadedThisRun})),characterUploaded:report.characterUploaded??false}));if(!report.success)process.exitCode=1;
}
