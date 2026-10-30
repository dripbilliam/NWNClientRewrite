// Authored localhost encounter only. Original server computes every roll and
// reaction; this does not fabricate attack/animation/result packets.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField,writeGff} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=b=>createHash('sha256').update(b).digest('hex');
export async function createNativeParryFixture(home,base){
 const input=await fs.readFile(path.join(home,'modules',base.module+'.mod'));assert.equal(hash(input),base.sha256);const entries=new Map(parseErf(input).entries),git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value.find(row=>row.fields.Tag.value==='native_speaker');assert.ok(npc);
 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),weapon='nw_wswls001',weaponData=parseGff(await resolver.getResource(weapon,2025)).root;assert.equal(weaponData.BaseItem,1);
 // Equipment is created/equipped by ordinary script actions below. Earlier
 // load-time EquippedRes/embedded attempts did not yield an equipped NPC.
 npc.fields.NaturalAC.value=50;npc.fields.Str.value=6;npc.fields.Equip_ItemList.value=[];
 for(const[name,field]of Object.entries(npc.fields))if(name.startsWith('Script')&&typeof field.value==='string')field.value='';
 const header=decodeResourceText(await resolver.getResource('nwscript',2009)),martial=/^int\s+FEAT_WEAPON_PROFICIENCY_MARTIAL\s*=\s*(\d+)\s*;/m.exec(header),right=/^int\s+INVENTORY_SLOT_RIGHTHAND\s*=\s*(\d+)\s*;/m.exec(header);assert.ok(martial&&right);
 npc.fields.FeatList.value.push({type:1,fields:{Feat:gffField(2,Number(martial[1]))}});
 const api=parseScriptApi(header),code=[],int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(r=>r.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);},wrap=()=>{const ncs=Buffer.alloc(13+code.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(code,13);parseNcs(ncs);return ncs;};
 // Use ordinary server item creation/equip actions, after all feat/stat loading.
 int(Number(right[1]));str('');int(1);int(0);str('native_speaker');action('GetObjectByTag',2);str(weapon);action('CreateItemOnObject',4);action('ActionEquipItem',2);
 int(0);action('GetFirstPC',0);action('ActionAttack',2);code.push(0x20,0);entries.set('native_parry:2010',wrap());code.length=0;
 str('-native-parry-start');action('GetPCChatMessage',0);code.push(0x0b,0x23);const jump=code.length;code.push(0x1f,0,0,0,0,0);
 int(0);str('native_speaker');action('GetObjectByTag',2);str('native_parry');action('ExecuteScript',2);str('GODOT_PARRY_COMBAT');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);
 const next=code.length;code.push(...entries.get('godot_chat:2010').subarray(13));const chat=wrap();chat.writeInt32BE(next-jump,13+jump+2);entries.set('godot_chat:2010',chat);
 entries.set('dense_a:2023',writeGff('GIT ',git));const module='GodotParry4',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=gffField(12,'Native original parry encounter');ifo.fields.Mod_Tag=gffField(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(at,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,at);at+=value.length;}
 assert.equal(parseErf(out).entries.size,count);
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(home,dir),{recursive:true});const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(out));}catch(e){if(e.code!=='ENOENT')throw e;await fs.writeFile(file,out,{flag:'wx'});}}
 return{module,port:5125,sha256:hash(out),baseline:base.sha256,weapon,naturalAC:50,scope:'Authored immortal high-AC equipped melee target and original fighter sample; unchanged server chooses attack rolls, miss/parry reactions and combat records. No original art or simulated presentation packets.'};
}
