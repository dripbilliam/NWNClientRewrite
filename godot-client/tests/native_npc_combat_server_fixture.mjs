// New owned NPC-vs-NPC encounter. No original module/BIC/user data is edited.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {createActionsFixture,actionsHome} from '../tools/native-actions-fixture.mjs';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,writeGff,gffField as field} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {parse2da} from '../../src/area.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=value=>createHash('sha256').update(value instanceof ArrayBuffer?new Uint8Array(value):value).digest('hex');
function script(api){
 const code=[],patches=[];
 const integer=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);},object=value=>{const bytes=Buffer.alloc(4);bytes.writeUInt32BE(value);code.push(4,6,...bytes);},string=value=>{const bytes=Buffer.from(value,'ascii');assert.ok(bytes.length<65536);code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);};
 const action=(name,count)=>{const row=api.find(row=>row.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const branch=()=>{const at=code.length;code.push(0x1f,0,0,0,0,0);return at;},patch=at=>patches.push({at,to:code.length}),tag=name=>{integer(0);string(name);action('GetObjectByTag',2);};
 const status=label=>{string(label);object(0);action('GetCurrentAction',1);action('IntToString',1);code.push(0x14,0x23);action('GetFirstPC',0);action('SendMessageToPC',2);};
 const finish=()=>{const body=Buffer.from(code);for(const {at,to}of patches)body.writeInt32BE(to-at,at+2);const bytes=Buffer.alloc(13+body.length);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(body,13);parseNcs(bytes);return bytes;};
 return {code,integer,object,string,action,branch,patch,tag,status,finish};
}
function moduleBytes(entries){
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,bytes=Buffer.alloc(start+[...entries.values()].reduce((sum,row)=>sum+row.length,0));
 bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let offset=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+24*index,16,'ascii');bytes.writeUInt32LE(index,keys+24*index+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);bytes.writeUInt32LE(offset,resources+8*index);bytes.writeUInt32LE(value.length,resources+8*index+4);bytes.set(value,offset);offset+=value.length;}
 assert.equal(parseErf(bytes).entries.size,count);return bytes;
}
export async function createNpcCombatFixture(){
 const base=await createActionsFixture();assert.equal(base.module,'GodotActions');
 const baseline=await fs.readFile(path.join(actionsHome,'modules',base.module+'.mod'));assert.equal(hash(baseline),base.sha256);
 const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')});
 const apiBytes=await resolver.getResource('nwscript',2009),header=decodeResourceText(apiBytes),api=parseScriptApi(header),appearanceBytes=await resolver.getResource('appearance',2017),appearance=parse2da(decodeResourceText(appearanceBytes));
 const constants={};for(const name of ['ACTION_ATTACKOBJECT','ACTION_INVALID']){const match=header.match(new RegExp('\\b'+name+'\\s*=\\s*(0x[0-9a-fA-F]+|[0-9]+)\\s*;'));assert.ok(match,name);constants[name]=Number(match[1]);}
 const chat=script(api);
 for(const [text,event]of [['-native-npc-start',9005],['-native-npc-stop',9006]]){chat.string(text);chat.action('GetPCChatMessage',0);chat.code.push(0x0b,0x23);const next=chat.branch();chat.integer(event);chat.action('EventUserDefined',1);chat.tag('native_speaker');chat.action('SignalEvent',2);chat.code.push(0x20,0);chat.patch(next);}
 chat.code.push(...entries.get('godot_chat:2010').subarray(13));const chatBytes=chat.finish();entries.set('godot_chat:2010',chatBytes);
 const npc=script(api);
 npc.integer(9005);npc.action('GetUserDefinedEventNumber',0);npc.code.push(0x0b,0x20);const stop=npc.branch();npc.integer(0);npc.tag('native_defender');npc.action('ActionAttack',2);npc.status('NATIVE_NPC_START:');npc.code.push(0x20,0);npc.patch(stop);
 npc.integer(9006);npc.action('GetUserDefinedEventNumber',0);npc.code.push(0x0b,0x20);const done=npc.branch();npc.object(0);npc.integer(1);npc.action('ClearAllActions',2);npc.status('NATIVE_NPC_STOP:');npc.code.push(0x20,0);npc.patch(done);npc.code.push(0x20,0);
 const npcBytes=npc.finish();entries.set('godot_npc_evt:2010',npcBytes);
 const git=typedGff(parseGff(entries.get('dense_a:2023')).root),creatures=git.fields['Creature List'].value,attackers=creatures.filter(row=>row.fields.Tag.value==='native_speaker');assert.equal(attackers.length,1);
 const attacker=attackers[0],defender=structuredClone(attacker),row=appearance.orderedRows[attacker.fields.Appearance_Type.value];
 assert.equal(attacker.fields.ScriptUserDefine.value,'');assert.deepEqual(attacker.fields.ClassList.value.map(row=>[row.fields.Class.value,row.fields.ClassLevel.value]),[[4,1]]);
 const preferred=Number(row.PREFATCKDIST),hitDistance=Number(row.HITDIST);assert.ok(preferred>0&&hitDistance>0);
 attacker.fields.ScriptUserDefine=field(11,'godot_npc_evt');defender.fields.Tag=field(10,'native_defender');defender.fields.FirstName=field(12,'Native Defender');defender.fields.LastName=field(12,'');defender.fields.ScriptDialogue=field(11,'');
 defender.fields.XPosition=field(8,Number(attacker.fields.XPosition.value)+preferred+hitDistance);creatures.push(defender);
 entries.set('dense_a:2023',writeGff('GIT ',git));
 const module='GodotCombatNpc1',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=field(12,'Owned native NPC combat');ifo.fields.Mod_Tag=field(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const bytes=moduleBytes(entries);for(const folder of ['modules','client/nwm']){await fs.mkdir(path.join(actionsHome,folder),{recursive:true});const file=path.join(actionsHome,folder,module+'.'+(folder==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(bytes),'Existing owned NPC fixture differs');}catch(error){if(error.code!=='ENOENT')throw error;await fs.writeFile(file,bytes,{flag:'wx'});}}
 const result={...base,module,sha256:hash(bytes),npcCombat:{attackerTag:'native_speaker',defenderTag:'native_defender',startEvent:9005,stopEvent:9006,actionConstants:constants,baselineSha256:hash(baseline),npcScriptSha256:hash(npcBytes),chatScriptSha256:hash(chatBytes),apiSha256:hash(apiBytes),appearanceSha256:hash(appearanceBytes),placement:{appearance:attacker.fields.Appearance_Type.value,preferredDistance:preferred,hitDistance,separation:preferred+hitDistance},canonicalClassesUnchanged:true,pcUnchanged:true},scope:'Owned NPC-vs-NPC original ActionAttack/ClearAllActions through real UserDefined scripts. Original class/body/items copied from prior authored durable NPC; no PC/BIC/class edits or client animation/path/flag injection.'};
 await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/native_npc_combat_server_fixture.mjs'))console.log(JSON.stringify(await createNpcCombatFixture()));
