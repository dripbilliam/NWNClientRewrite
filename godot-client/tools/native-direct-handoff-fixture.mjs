// NEW test-only direct-route fixture. No process launch or private-key access.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {typedGff,gffField as F,writeGff} from '../../src/gff_writer.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),prefix=path.join(project,'.cache/native-direct-handoff');
const install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
const SERVER='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6';
const BASELINE='0923e003ef612d80e5b1423661b05ab6492cbc4ff95edf7e9857751b3fe2a237';
export const COMMAND='-native-direct-handoff';
export const SERVERS=Object.freeze([
 Object.freeze({label:'A',module:'NativeHandA1',port:5129,destination:5130,entry:'dense_a',waypoint:'NativeArrivalA'}),
 Object.freeze({label:'B',module:'NativeHandB1',port:5130,destination:5129,entry:'dense_b',waypoint:'NativeArrivalB'}),
]);
const hash=bytes=>crypto.createHash('sha256').update(bytes instanceof ArrayBuffer?new Uint8Array(bytes):bytes).digest('hex');
export function owned(directory){const value=path.resolve(directory);if(path.dirname(value)!==prefix||!/^native-direct-handoff-[a-z0-9-]+$/.test(path.basename(value)))throw Error('Fresh owned direct-handoff directory required');return value;}
function pack(entries){
 const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
 for(const[i,[key,value]]of[...entries].entries()){const at=key.lastIndexOf(':');bytes.write(key.slice(0,at),keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(Number(key.slice(at+1)),keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
 assert.equal(parseErf(bytes).entries.size,count);return bytes;
}
export function portalScript(api,label,old){
 const target=SERVERS.find(s=>s.label!==label),code=[];
 assert.deepEqual(api.find(a=>a.name==='ActivatePortal')?.args.map(a=>a.name),['oTarget','sIPaddress','sPassword','sWaypointTag','bSeemless'],'Original ActivatePortal signature');
 const integer=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},string=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(a=>a.name===name);assert.equal(row?.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 string(COMMAND);action('GetPCChatMessage',0);code.push(0x0b,0x23);const branch=code.length;code.push(0x1f,0,0,0,0,0);
 integer(1);string(target.waypoint);string('');string('127.0.0.1:'+target.port);action('GetPCChatSpeaker',0);action('ActivatePortal',5);code.push(0x20,0);
 const tail=code.length;code.push(...old.subarray(13));const body=Buffer.from(code);body.writeInt32BE(tail-branch,branch+2);const result=Buffer.alloc(13+body.length);result.write('NCS V1.0');result[8]=0x42;result.writeUInt32BE(result.length,9);result.set(body,13);parseNcs(result);return result;
}
export function buildModules(source,api){
 assert.equal(hash(source),BASELINE);const baseline=parseErf(source).entries;
 return SERVERS.map(server=>{
  const entries=new Map(baseline),ifo=typedGff(parseGff(entries.get('module:2014')).root);
  ifo.fields.Mod_Name=F(12,server.module);ifo.fields.Mod_Tag=F(10,server.module);ifo.fields.Mod_Entry_Area=F(11,server.entry);
  // Original LoadModuleStart47f03a..085 gates the name on BYTE BOOL==1.
  // SaveModule48629c..2d4 writes BOOL then CExoString, not inferred filename.
  ifo.fields.Mod_IsNWMFile=F(0,1);ifo.fields.Mod_NWMResName=F(10,server.module);
  entries.set('module:2014',writeGff('IFO ',ifo));
  const git=typedGff(parseGff(entries.get(server.entry+':2023')).root);assert.ok(git.fields.WaypointList?.value.length>0,'Authored arrival waypoint template required');
  const arrival=structuredClone(git.fields.WaypointList.value[0]);Object.assign(arrival.fields,{Tag:F(10,server.waypoint),XPosition:F(8,52),YPosition:F(8,40),ZPosition:F(8,0)});git.fields.WaypointList.value.push(arrival);entries.set(server.entry+':2023',writeGff('GIT ',git));
  entries.set('godot_chat:2010',portalScript(api,server.label,entries.get('godot_chat:2010')));
  const bytes=pack(entries),decoded=parseErf(bytes).entries,allowed=new Set(['module:2014','godot_chat:2010',server.entry+':2023']);
  for(const[key,value]of baseline)if(!allowed.has(key))assert.deepEqual(decoded.get(key),value,'Unexpected module resource change: '+key);
  const after=parseGff(decoded.get(server.entry+':2023')).root,original=parseGff(baseline.get(server.entry+':2023')).root;assert.deepEqual(after.WaypointList.slice(0,-1),original.WaypointList);
  const afterWithoutArrival={...after,WaypointList:original.WaypointList};assert.deepEqual(afterWithoutArrival,{...original},'Other GIT objects/spawns must survive');
  return{...server,bytes,sha256:hash(bytes),arrival:{waypoint:server.waypoint,position:[52,40,0]},changedResources:[...allowed],preservedResources:baseline.size-allowed.size};
 });
}
async function inputs(){
 const serverPath=path.join(install,'bin/win32/nwserver.exe'),baselinePath=path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotFeedback1.mod');assert.equal(hash(await fs.readFile(serverPath)),SERVER);
 const source=await fs.readFile(baselinePath);assert.equal(hash(source),BASELINE);const resolver=await openServerResourceContext({install}),raw=await resolver.getResource('nwscript',2009),api=parseScriptApi(decodeResourceText(raw));
 return{serverPath,baselinePath,source,api,apiSha256:hash(raw)};
}
export async function prepare(directory){
 const home=owned(directory);try{await fs.access(home);throw Error('Existing direct-handoff evidence retained');}catch(error){if(error.code!=='ENOENT')throw error;}
 const input=await inputs(),modules=buildModules(input.source,input.api),servers=modules.map(({bytes,...s})=>({...s,host:'127.0.0.1',profile:path.join(home,'server-'+s.label.toLowerCase()),modulePath:path.join(home,'server-'+s.label.toLowerCase(),'modules',s.module+'.mod'),clientModule:path.join(home,'client/nwm',s.module+'.nwm')}));
 const descriptor={version:1,kind:'owned-native-direct-handoff',directory:home,nonce:crypto.randomUUID(),route:'native-session-host',serverPath:input.serverPath,serverSha256:SERVER,baselinePath:input.baselinePath,baselineSha256:BASELINE,apiSha256:input.apiSha256,clientDirectory:path.join(home,'client'),command:COMMAND,servers,public:false,maxClients:1,serverVault:false,enforceLegal:true,arrivalTolerance:1,scope:'Authored private A/B ActivatePortal modules and distinct native catalogs. Legacy local-host evidence is not current direct-route acceptance.'};
 await fs.mkdir(home,{recursive:true});await fs.mkdir(path.join(home,'client/nwm'),{recursive:true});
 for(const[i,s]of servers.entries()){
  await fs.mkdir(path.dirname(s.modulePath),{recursive:true});for(const output of[s.modulePath,s.clientModule])await fs.writeFile(output,modules[i].bytes,{flag:'wx'});
  await fs.writeFile(path.join(s.profile,'settings.tml'),'[ruleset]\nenforce-legal-characters = true\n[server.identity]\nname = "Owned Native Direct '+s.label+'"\npublic = false\n[server.net]\naccept-relayed-connections = false\n[server.login.player-dm]\nenabled = false\n',{flag:'wx'});
 }
 await fs.writeFile(path.join(home,'fixture.json'),JSON.stringify(descriptor,null,2)+'\n',{flag:'wx'});return read(home);
}
export async function read(directory){
 const home=owned(directory),raw=await fs.readFile(path.join(home,'fixture.json'));assert.ok(raw.length<16384);const value=JSON.parse(raw),input=await inputs(),expected=buildModules(input.source,input.api);
 assert.equal(value.version,1);assert.equal(value.kind,'owned-native-direct-handoff');assert.equal(value.route,'native-session-host');assert.equal(value.directory,home);assert.equal(value.serverPath,input.serverPath);assert.equal(value.serverSha256,SERVER);assert.equal(value.baselinePath,input.baselinePath);assert.equal(value.baselineSha256,BASELINE);assert.equal(value.apiSha256,input.apiSha256);assert.equal(value.clientDirectory,path.join(home,'client'));assert.equal(value.command,COMMAND);assert.equal(value.public,false);assert.equal(value.maxClients,1);assert.equal(value.serverVault,false);assert.equal(value.enforceLegal,true);assert.equal(value.arrivalTolerance,1);assert.equal(value.servers.length,2);
 for(const[i,s]of value.servers.entries()){
  const{bytes,...record}=expected[i];assert.deepEqual(s,{...record,host:'127.0.0.1',profile:path.join(home,'server-'+record.label.toLowerCase()),modulePath:path.join(home,'server-'+record.label.toLowerCase(),'modules',record.module+'.mod'),clientModule:path.join(home,'client/nwm',record.module+'.nwm')});
  for(const file of[s.modulePath,s.clientModule])assert.deepEqual(await fs.readFile(file),bytes,'Private fixture bytes differ');
 }
 return{...value,descriptorSha256:hash(raw)};
}
export async function identityPin(directory,endpoint){
 const fixture=await read(directory),server=fixture.servers.find(s=>s.host===endpoint.host&&s.port===endpoint.port);if(!server)throw Error('Unowned direct-handoff endpoint');
 const log=await fs.readFile(path.join(server.profile,'logs/nwengineLog.txt'));if(log.length>4*1024*1024)throw Error('Owned identity log exceeds4MiB');
 const pin=[...log.toString().matchAll(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/g)].at(-1)?.[1];if(!pin)throw Error('Fresh owned server identity is unavailable');
 return{pin,fileSha256:hash(log),identitySha256:hash(Buffer.from(pin)),descriptorSha256:fixture.descriptorSha256};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const verify=process.argv[2]==='--verify';(verify?read(process.argv[3]):prepare(process.argv[2])).then(value=>console.log(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exitCode=1;});
}
