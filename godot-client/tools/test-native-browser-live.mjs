// Owned-loopback acceptance through the production browser/lobby/session owners.
// UI input and rendering are checked separately by test-native-browser-scope.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {readPrivateKey,connectPrivatePipe} from './private-login.cjs';
import {publicCdKey} from '../../electron/network_login_identity.mjs';
import {createInstalledNetworkSession} from '../../electron/installed_network_session.mjs';
import {NetworkCharacterVault} from '../../electron/network_character_vault.mjs';
import {queryNetworkServer} from '../../electron/server_browser.mjs';
import {parseErf} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {typedGff,writeGff,gffField as F} from '../../src/gff_writer.js';
import {NativeLobby} from './native-lobby.mjs';
import {ServerBrowserService} from './server-browser-service.mjs';
import {ServerBrowserStore} from './server-browser-store.mjs';
import {ServerEndpointPolicy} from './server-endpoint.mjs';
import {discoverLocalCharacterFiles} from './native-local-character-discovery.mjs';
import {localCharacterFile,readCatalogCharacter} from './native-local-character-files.mjs';
import protocol from './local-protocol.cjs';
const arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3),run=arg('run');
if(!/^nwn40-live-[a-z0-9-]+$/.test(run??''))throw Error('Fresh NWN-40 live label required');
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.dirname(project.slice(0,-1)),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
const directory=path.join(project,'.cache/nwn40',run),report=path.join(directory,'result.json'),baseline=path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotFeedback1.mod');
const hash=bytes=>createHash('sha256').update(bytes).digest('hex'),checks=[],owned=[],sessions=[];
let key='',lobby,service,stage='prepare',failure=null,baselineHash;
const sourceFiles=['tools/test-native-browser-live.mjs','tools/test-native-browser-live.ps1','tools/server-browser-service.mjs','tools/server-browser-store.mjs','tools/server-browser-filters.mjs','tools/native-lobby.mjs','tools/native-local-character-files.mjs','tools/native-local-character-discovery.mjs','tools/local-protocol.cjs','../electron/installed_network_session.mjs','../electron/network_game_session.mjs','../electron/network_peer.mjs','../electron/network_character_vault.mjs'];
let sourceHashes={};
function check(value,label){checks.push({label,passed:Boolean(value)});if(!value)throw Error(label);}
async function wait(predicate,timeout=45000){const end=Date.now()+timeout;while(!await predicate()){if(Date.now()>end)throw Error('Timed out at '+stage);await new Promise(resolve=>setTimeout(resolve,30));}}
function pack(entries,signature='MOD V1.0'){
 const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,b)=>n+b.length,0));bytes.write(signature);bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
 for(const [i,[name,value]]of [...entries].entries()){const colon=name.lastIndexOf(':');bytes.write(name.slice(0,colon),keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(Number(name.slice(colon+1)),keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
 assert.equal(parseErf(bytes).entries.size,count);return bytes;
}
async function server({port,name,vault=false,missingHak=false,maxLevel=40}){
 const home=path.join(directory,name),client=path.join(home,'client');await fs.mkdir(path.join(home,'modules'),{recursive:true});await fs.mkdir(path.join(client,'nwm'),{recursive:true});
 const entries=new Map(parseErf(await fs.readFile(baseline)).entries),ifo=typedGff(parseGff(entries.get('module:2014')).root);
 ifo.fields.Mod_IsNWMFile=F(0,1);ifo.fields.Mod_NWMResName=F(10,name);ifo.fields.Mod_Tag=F(10,name);ifo.fields.Mod_Name=F(12,name);
 if(missingHak){ifo.fields.Mod_HakList=F(15,[{type:0,fields:{Mod_Hak:F(10,'nwn40_only')}}]);await fs.mkdir(path.join(home,'hak'));await fs.writeFile(path.join(home,'hak/nwn40_only.hak'),pack(new Map([['nwn40marker:10',Buffer.from('Owned NWN-40 server-only HAK fixture')]]),'HAK V1.0'),{flag:'wx'});}
 entries.set('module:2014',writeGff('IFO ',ifo));const module=pack(entries);await fs.writeFile(path.join(home,'modules',name+'.mod'),module,{flag:'wx'});await fs.writeFile(path.join(client,'nwm',name+'.nwm'),module,{flag:'wx'});
 if(vault){const account=publicCdKey(key).toLowerCase();assert.match(account,/^[a-z0-9]{8}$/);await fs.mkdir(path.join(home,'servervault',account),{recursive:true});await fs.copyFile(path.join(install,'data/lcv/wizard.bic'),path.join(home,'servervault',account,'nwn40pc.bic'));}
 const executable=path.join(install,'bin/win32/nwserver.exe');check(hash(await fs.readFile(executable))==='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6','Original server executable is unchanged');
 const child=spawn(executable,['-userdirectory',home,'-port',String(port),'-publicserver','0','-servername',name,'-maxclients','2','-maxlevel',String(maxLevel),'-servervault',vault?'1':'0','-autosaveinterval','0','-playerpassword','nwn40-fixture','-module',name],{cwd:path.dirname(executable),windowsHide:true,stdio:'ignore',env:{...process.env,NWN_DO_NOT_NAT_PUNCH:'1'}});
 const row={child,home,client,endpoint:{host:'127.0.0.1',port},name,pin:null,stopping:false,unexpectedExit:false};owned.push(row);child.once('error',error=>row.error=error.message);child.once('exit',()=>{if(!row.stopping)row.unexpectedExit=true;});
 await wait(async()=>{if(row.error)throw Error(row.error);try{row.pin=(await fs.readFile(path.join(home,'logs/nwengineLog.txt'),'utf8')).match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];return Boolean(row.pin);}catch{return false;}});
 await wait(async()=>{try{row.info=await queryNetworkServer({...row.endpoint,extended:true,timeout:1000});return Boolean(row.info.moduleName);}catch{return false;}});return row;
}
async function configure(row){
 const catalog=new Map(),vault=new NetworkCharacterVault(path.join(row.client,'saved')),messages=[];
 const listLocal=async()=>{const found=await discoverLocalCharacterFiles({install,profileDirectory:row.client,modsDirectory:path.join(row.client,'workshop')});const rows=found.rows;for(const entry of await vault.list())rows.push({key:'vault:'+entry.id,label:entry.name,source:'vault',vaultId:entry.id,file:path.join(vault.directory,'blobs',entry.sha256+'.bic')});catalog.clear();for(const item of rows){item.nativeFile=await localCharacterFile(item.file);catalog.set(item.key,item);}return rows;};
 lobby=new NativeLobby({listLocal,readLocal:async(id,expectedFile)=>readCatalogCharacter(catalog.get(id),{vault,expectedFile}),publish:value=>messages.push(value),
  connect:async(connection,details,{signal})=>{
   const created=await createInstalledNetworkSession({install,userDirectory:row.client,cacheDirectory:path.join(row.client,'content'),...row.endpoint,name:details.name,credentials:{...details.credentials},signal,persistCharacter:message=>vault.save(message)});sessions.push(created.session);
   if(signal.aborted||connection!==lobby.connection){await created.session.disconnect();return;}
   lobby.endpoint=row.endpoint;lobby.attach(created.session,connection);await created.session.connect({...row.endpoint,metadata:created.metadata,expectedServerPublicKey:Buffer.from(row.pin,'base64'),timeout:20000});
  },disconnect:async({saveCharacter,targetSession})=>{try{if(saveCharacter&&targetSession&&!targetSession.closed&&targetSession.characterConfirmed)await targetSession.exportCharacter();}finally{await targetSession?.disconnect();}},save:()=>lobby.session.exportCharacter()});
 const store=new ServerBrowserStore(path.join(row.client,'browser.json'));
 service=new ServerBrowserService({lobby,store,policy:new ServerEndpointPolicy({allowed:[row.endpoint],internet:true}),query:queryNetworkServer,discover:async()=>[await queryNetworkServer({...row.endpoint,extended:true})],settings:async()=>({hasSavedCdKey:true}),send:value=>messages.push(value)});
 const command=async(operation,fields={})=>{const message={kind:'browser-input',connection:lobby.connection,viewId:service.view?.id,operation,...fields};protocol.validateCommand(message,lobby);return service.command(message);};
 const join=async password=>{await command('open');await command('join',{direct:true,values:{...row.endpoint,name:'NWN40Acceptance',password,cdKey:key}});};
 return{catalog,vault,store,messages,command,join};
}
async function enter(keyName){
 await wait(()=>lobby.selectable()&&lobby.session.resourceResult?.ready);await lobby.choose({connection:lobby.connection,key:keyName});await wait(()=>Boolean(lobby.preview));check(Boolean(lobby.preview),'Authoritative selection produces a character preview');
 await lobby.play({connection:lobby.connection,key:keyName});await wait(()=>lobby.session.phase==='area-loading'||lobby.session.phase==='character-rejected'||lobby.session.closed);
 check(lobby.session.phase==='area-loading'&&lobby.session.characterConfirmed,'Original server admits the selected character');
 await lobby.session.areaReady(lobby.session.areaGeneration);await wait(()=>lobby.session.phase==='playing'&&lobby.session.world.registry.get(lobby.session.world.localObjectId)?.objectType===5);
 check(lobby.session.phase==='playing','Original server reaches playing with its controlled creature');
}
async function leave(){await lobby.leave({connection:lobby.connection,saveCharacter:false});check(lobby.snapshot().canJoin&&!lobby.session,'Disconnect releases the session before retry');await service.retire();service=null;await new Promise(resolve=>setTimeout(resolve,750));}
try{
 await fs.mkdir(directory);baselineHash=hash(await fs.readFile(baseline));sourceHashes=Object.fromEntries(await Promise.all(sourceFiles.map(async file=>[file,hash(await fs.readFile(path.join(project,file)))])));key=await readPrivateKey(connectPrivatePipe(arg('private-login-pipe')));
 stage='local-server';const local=await server({port:5127,name:'Nwn40Local'});
 check(Boolean(local.info.passwordRequired)&&Boolean(local.info.allowLocalVaultCharacters)&&local.info.extendedReceived&&Number.isInteger(local.info.gameType),'Original extended query supplies password, vault and game-type metadata');
 const localPath=path.join(local.client,'localvault','Éowyn #2.bic');await fs.mkdir(path.dirname(localPath),{recursive:true});await fs.copyFile(path.join(install,'data/lcv/wizard.bic'),localPath);
 let f=await configure(local);stage='details-and-filters';await f.command('open');await f.command('tab',{tab:'Internet',sourcePage:true});await f.command('select',{entryId:0});await f.command('inspect',{direct:false,entryId:0});
 check(service.details.extendedReceived&&service.details.passwordRequired&&service.details.gameType===local.info.gameType,'Production Details uses original extended server metadata');
 await f.command('game-type',{gameType:local.info.gameType});check(service.view.entries.size===1,'Actual game-type metadata matches its browser filter');await f.command('game-type',{gameType:local.info.gameType+1});check(service.view.entries.size===0,'Other game types are hidden without changing the discovery cache');await f.command('game-type',{gameType:null});
 await f.command('favorite',{direct:false,entryId:0,on:true});check((await f.store.load()).favorites.length===1,'Production Favorite commits its selected server');
 stage='wrong-password';await f.join('wrong');check(Boolean(lobby.error)&&lobby.snapshot().canJoin,'Original password rejection returns a usable retry browser');
 stage='correct-password';await f.join('nwn40-fixture');await wait(()=>lobby.selectable());check(lobby.snapshot().localAllowed,'Local-vault policy exposes local catalog rows');
 stage='local-admission';await enter('local:Éowyn #2.bic');
 stage='export';const saved=await lobby.export({connection:lobby.connection});check(Boolean(saved.id)&&saved.sha256.length===64,'Original export is saved in the isolated application vault');
 await f.store.favorite({...local.endpoint,...local.info},true);const stored=JSON.stringify(await f.store.load());check(!stored.includes('nwn40-fixture')&&!stored.includes(key),'Browser persistence excludes passwords and CD keys');
 await leave();
 stage='saved-reconnect';f=await configure(local);await f.join('nwn40-fixture');await enter('vault:'+saved.id);check(lobby.session.characterUploaded,'Saved-character reconnect uses the original local upload route');await leave();
 stage='server-vault';const remote=await server({port:5128,name:'Nwn40Vault',vault:true});f=await configure(remote);await f.join('nwn40-fixture');await wait(()=>lobby.selectable()&&!lobby.session.serverCharacterListPending);
 check(!lobby.snapshot().localAllowed&&lobby.snapshot().choices.every(item=>item.source==='server'),'Server-vault policy hides all local and Workshop choices');
 let refused=false;try{await lobby.choose({connection:lobby.connection,key:'installed:wizard.bic'});}catch{refused=true;}check(refused,'Server-vault admission refuses a local catalog key');
 const selected=lobby.snapshot().choices.find(item=>item.key.endsWith(':nwn40pc'));check(Boolean(selected),'Original server advertises its seeded saved character');await enter(selected.key);check(!lobby.session.characterUploaded,'Server-vault admission never uploads a replacement local BIC');await leave();
 stage='character-rejection';const reject=await server({port:5130,name:'Nwn40Reject',maxLevel:1});f=await configure(reject);check(reject.info.maximumLevel===1,'Original rejection fixture advertises its level limit');await f.join('nwn40-fixture');await wait(()=>lobby.selectable());await lobby.choose({connection:lobby.connection,key:'installed:wizard.bic'});await lobby.play({connection:lobby.connection,key:'installed:wizard.bic'});await wait(()=>lobby.session.phase==='character-rejected'||lobby.session.closed);check(lobby.session.phase==='character-rejected'&&!lobby.session.characterConfirmed,'Original server rejects a character outside its level limit');check(Boolean(lobby.error)&&lobby.snapshot().canSelect,'Character rejection exposes a reason and restores selection');await leave();
 stage='missing-content';const missing=await server({port:5129,name:'Nwn40Missing',missingHak:true});f=await configure(missing);await f.join('nwn40-fixture');await wait(()=>lobby.session?.phase==='resources-unavailable'||lobby.session?.closed);if(lobby.session?.closed)throw Error(lobby.error||'Missing-content connection closed before requirements');
 check(Boolean(lobby.error)&&lobby.snapshot().canCancelJoin,'Missing original required content reports a cancellable resource failure');await lobby.cancelJoin({connection:lobby.connection});check(lobby.snapshot().canJoin&&!lobby.session,'Cancelling missing content restores the clean connection menu');await service.retire();service=null;
}catch(error){failure={stage,message:String(error.message).slice(0,512),phase:lobby?.session?.phase??null};}
finally{
 key='';await service?.retire().catch(()=>{});for(const session of sessions)await session.disconnect().catch(()=>{});
 for(const row of owned){row.stopping=true;if(row.child.exitCode===null&&row.child.signalCode===null){const ended=new Promise(resolve=>row.child.once('close',resolve));row.child.kill();await ended;}}
 const closed=owned.every(row=>row.child.exitCode!==null||row.child.signalCode!==null),unchanged=baselineHash&&hash(await fs.readFile(baseline))===baselineHash;
 const sourcesUnchanged=Object.keys(sourceHashes).length===sourceFiles.length&&(await Promise.all(Object.entries(sourceHashes).map(async([file,digest])=>hash(await fs.readFile(path.join(project,file)))===digest))).every(Boolean);
 const result={success:!failure&&checks.every(item=>item.passed)&&closed&&unchanged&&sourcesUnchanged&&!owned.some(row=>row.unexpectedExit),checks,checkCount:checks.length,failure,serversStopped:closed,unexpectedServerExit:owned.some(row=>row.unexpectedExit),sourceModuleUnchanged:Boolean(unchanged),sourcesUnchanged,sourceHashes,publicConnections:0,nativeBuilds:0,scope:'Production browser/lobby/session classes and unchanged original server binary on owned loopback profiles. Native UI input/artwork are verified separately; no world rendering acceptance.'};
 await fs.mkdir(directory,{recursive:true});await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));process.exitCode=result.success?0:1;
}
