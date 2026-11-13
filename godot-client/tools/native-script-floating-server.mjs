// Authored module only. Original executable/API are read-only; this helper
// never launches a process, reads a key, or prints a server secret.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {typedGff,gffField as field,writeGff} from '../../src/gff_writer.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),prefix=path.join(project,'.cache/script-floating-authority');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const SERVER='98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6';
export const SCRIPT_FLOATING_CASES=Object.freeze([
 Object.freeze({type:93,strRef:57779,showChat:0,broadcast:0}),
 Object.freeze({type:93,strRef:57779,showChat:1,broadcast:0}),
 Object.freeze({type:94,text:'NATIVE_SCRIPT94_NO_ECHO',showChat:0,broadcast:0}),
 Object.freeze({type:94,text:'NATIVE_SCRIPT94_ECHO',showChat:1,broadcast:0}),
]);
export function owned(directory){const home=path.resolve(directory);if(!home.startsWith(prefix+path.sep)||path.basename(home)!=='server'||!/^native-script-floating-[a-z0-9-]+$/.test(path.basename(path.dirname(home))))throw Error('Explicit unused ScriptFloating fixture directory required');return home;}
export function scriptFloatingScript(api){
 const code=[],integer=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},string=value=>{const b=Buffer.from(value,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(value=>value.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 string('-native-script-floating');action('GetPCChatMessage',0);code.push(0x0b,0x23);const branch=code.length;code.push(0x1f,0,0,0,0,0);
 // NCS ACTION arguments are pushed in reverse formal-parameter order.
 for(const name of ['FloatingTextStrRefOnCreature','FloatingTextStringOnCreature'])assert.deepEqual(api.find(value=>value.name===name)?.args.map(value=>value.name),[name==='FloatingTextStrRefOnCreature'?'nStrRefToDisplay':'sStringToDisplay','oCreatureToFloatAbove','bBroadcastToFaction','bChatWindow'],'Installed original script parameter order');
 for(const row of SCRIPT_FLOATING_CASES){integer(row.showChat);integer(row.broadcast);action('GetPCChatSpeaker',0);if(row.type===93)integer(row.strRef);else string(row.text);action(row.type===93?'FloatingTextStrRefOnCreature':'FloatingTextStringOnCreature',4);}
 string('NATIVE_SCRIPT_FLOATING_DONE');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);
 const tail=code.length;code.push(0x20,0);const body=Buffer.from(code);body.writeInt32BE(tail-branch,branch+2);
 const bytes=Buffer.alloc(13+body.length);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(body,13);parseNcs(bytes);return bytes;
}
function moduleBytes(entries){
 const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,value)=>n+value.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
 for(const [index,[key,value]]of [...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
 assert.equal(parseErf(bytes).entries.size,count);return bytes;
}
export async function prepare(directory){
 const home=owned(directory),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall'),serverPath=path.join(install,'bin/win32/nwserver.exe'),baselinePath=path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotFeedback1.mod');
 assert.equal(digest(await fs.readFile(serverPath)),SERVER,'Original server hash');
 const baseline=await fs.readFile(baselinePath),prior=JSON.parse(await fs.readFile(path.join(project,'reports/feedback-server-fixture-v1.json')));assert.equal(digest(baseline),prior.sha256,'Existing authored feedback module hash');
 const resolver=await openServerResourceContext({install}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),entries=new Map(parseErf(baseline).entries),ifo=typedGff(parseGff(entries.get('module:2014')).root);
 assert.equal(ifo.fields.Mod_OnPlrChat.value,'godot_chat','Actual authored module OnChat owner');
 entries.set('godot_chat:2010',scriptFloatingScript(api));ifo.fields.Mod_Name=field(12,'ScriptFloat1');ifo.fields.Mod_Tag=field(10,'ScriptFloat1');entries.set('module:2014',writeGff('IFO ',ifo));const bytes=moduleBytes(entries);
 await fs.mkdir(path.dirname(home),{recursive:true});await fs.mkdir(home);for(const directory of ['modules','client/nwm'])await fs.mkdir(path.join(home,directory),{recursive:true});
 for(const relative of ['modules/ScriptFloat1.mod','client/nwm/ScriptFloat1.nwm'])await fs.writeFile(path.join(home,relative),bytes,{flag:'wx'});
 await fs.writeFile(path.join(home,'settings.tml'),'[ruleset]\nenforce-legal-characters = true\n[server.identity]\nname = "Owned Native Script Floating"\npublic = false\n[server.net]\naccept-relayed-connections = false\n[server.login.player-dm]\nenabled = false\n',{flag:'wx'});
 const value={version:1,kind:'owned-native-script-floating',nonce:crypto.randomUUID(),directory:home,port:5129,module:'ScriptFloat1',moduleSha256:digest(bytes),baselinePath,baselineSha256:digest(baseline),serverPath,serverSha256:SERVER,serverVault:false,public:false,maxClients:1,enforceLegal:true,command:'-native-script-floating',completion:'NATIVE_SCRIPT_FLOATING_DONE',cases:SCRIPT_FLOATING_CASES,createdAtUtc:new Date().toISOString()};
 await fs.writeFile(path.join(home,'fixture.json'),JSON.stringify(value,null,2)+'\n',{flag:'wx'});return {...value};
}
export async function read(directory){
 const home=owned(directory),bytes=await fs.readFile(path.join(home,'fixture.json'));if(bytes.length>16384)throw Error('ScriptFloating descriptor exceeds bound');const value=JSON.parse(bytes),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
 if(value.version!==1||value.kind!=='owned-native-script-floating'||value.directory!==home||value.port!==5129||value.module!=='ScriptFloat1'||value.serverVault!==false||value.public!==false||value.maxClients!==1||value.enforceLegal!==true||value.serverSha256!==SERVER||value.serverPath!==path.join(install,'bin/win32/nwserver.exe')||value.baselinePath!==path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotFeedback1.mod')||value.command!=='-native-script-floating'||value.completion!=='NATIVE_SCRIPT_FLOATING_DONE'||JSON.stringify(value.cases)!==JSON.stringify(SCRIPT_FLOATING_CASES))throw Error('Owned ScriptFloating fixture identity/rules differ');
 const baselineProof=JSON.parse(await fs.readFile(path.join(project,'reports/feedback-server-fixture-v1.json')));if(value.baselineSha256!==baselineProof.sha256)throw Error('Authored baseline module proof differs');
 if(digest(await fs.readFile(value.serverPath))!==SERVER||digest(await fs.readFile(value.baselinePath))!==value.baselineSha256)throw Error('Original ScriptFloating fixture inputs changed');
 for(const relative of ['modules/ScriptFloat1.mod','client/nwm/ScriptFloat1.nwm'])if(digest(await fs.readFile(path.join(home,relative)))!==value.moduleSha256)throw Error('Owned original-server/native catalog module differs');
 return {...value,descriptorSha256:digest(bytes)};
}
export async function pin(directory){
 const fixture=await read(directory),sourcePath=path.join(fixture.directory,'logs/nwengineLog.txt'),handle=await fs.open(sourcePath,'r');let bytes;
 try{const buffer=Buffer.alloc(16*1024*1024+1);let used=0;while(used<buffer.length){const next=await handle.read(buffer,used,Math.min(65536,buffer.length-used),null);if(!next.bytesRead)break;used+=next.bytesRead;}if(used>16*1024*1024)throw Error('Owned ScriptFloating log exceeds16MiB');bytes=buffer.subarray(0,used);}finally{await handle.close();}
 const value=[...bytes.toString().matchAll(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/g)].at(-1)?.[1];if(!value)throw Error('Fresh owned ScriptFloating identity unavailable');return {pin:value,sourcePath,fileSha256:digest(bytes),identitySha256:digest(value),descriptorSha256:fixture.descriptorSha256};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))prepare(process.argv[2]).then(value=>console.log(JSON.stringify(value))).catch(error=>{console.error(error.message);process.exitCode=1;});
