import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {parseErf} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField,writeGff} from '../../src/gff_writer.js';
import {decodeResourceText} from '../../src/resource_archive.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function createNativeRangedFixture(home,base,{deflection=false,miss=false,shield=false,shieldKind='small'}={}){
	assert.ok(!shield||!deflection&&!miss);
	assert.ok(['small','large','tower'].includes(shieldKind)&&(shield||shieldKind==='small'));
 const input=await fs.readFile(path.join(home,'modules',base.module+'.mod'));assert.equal(hash(input),base.sha256);const entries=new Map(parseErf(input).entries),git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value.find(row=>row.fields.Tag.value==='native_speaker');assert.ok(npc);
 npc.fields.XPosition.value=48.4;npc.fields.YPosition.value=36;npc.fields.ZPosition.value=0;
 // A stationary authored target: remove its AI scripts, not the server's
 // combat rules. Actual native attack rolls, damage and ammunition still run.
 for(const[name,field]of Object.entries(npc.fields))if(name.startsWith('Script')&&typeof field.value==='string')field.value='';
 if(miss){assert.equal(deflection,false);npc.fields.NaturalAC.value=50;}
 let feat=null;if(deflection||shield){const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),header=decodeResourceText(await resolver.getResource('nwscript',2009)),match=(shield?/^int\s+FEAT_SHIELD_PROFICIENCY\s*=\s*(\d+)\s*;/m:/^int\s+FEAT_DEFLECT_ARROWS\s*=\s*(\d+)\s*;/m).exec(header);assert.ok(match);feat=Number(match[1]);if(deflection)npc.fields.Dex.value=30;npc.fields.FeatList.value.push({type:1,fields:{Feat:gffField(2,feat)}});
  // Enter an actual server combat round: its per-round deflection allowance
  // is not exercised by a permanently idle, scriptless target.
  const api=parseScriptApi(header),code=[],int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(r=>r.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);},wrap=()=>{const ncs=Buffer.alloc(13+code.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(code,13);parseNcs(ncs);return ncs;};
  const script=shield?'native_shield':'native_deflect';
  if(shield){const [resource,baseItem]={small:['nw_ashsw001',14],large:['nw_ashlw001',56],tower:['nw_ashto001',57]}[shieldKind],left=/^int\s+INVENTORY_SLOT_LEFTHAND\s*=\s*(\d+)\s*;/m.exec(header);assert.ok(left);assert.equal(parseGff(await resolver.getResource(resource,2025)).root.BaseItem,baseItem);npc.fields.NaturalAC.value=50;npc.fields.Equip_ItemList.value=[];
   int(Number(left[1]));str('');int(1);int(0);str('native_speaker');action('GetObjectByTag',2);str(resource);action('CreateItemOnObject',4);action('ActionEquipItem',2);
  }
  int(0);action('GetFirstPC',0);action('ActionAttack',2);code.push(0x20,0);entries.set(script+':2010',wrap());code.length=0;
  str(shield?'-native-shield-start':'-native-deflect-start');action('GetPCChatMessage',0);code.push(0x0b,0x23);const jump=code.length;code.push(0x1f,0,0,0,0,0);
  int(0);str('native_speaker');action('GetObjectByTag',2);str(script);action('ExecuteScript',2);str(shield?'GODOT_SHIELD_COMBAT':'GODOT_DEFLECT_COMBAT');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);
  const next=code.length;code.push(...entries.get('godot_chat:2010').subarray(13));const chat=wrap();chat.writeInt32BE(next-jump,13+jump+2);entries.set('godot_chat:2010',chat);
 }
 entries.set('dense_a:2023',writeGff('GIT ',git));const module=shield?{small:'GodotShield1',large:'GodotShieldL1',tower:'GodotShieldT1'}[shieldKind]:deflection?'GodotDeflect2':miss?'GodotMiss1':'GodotRanged1',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=gffField(12,'Native ranged playability');ifo.fields.Mod_Tag=gffField(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(at,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,at);at+=value.length;}
 assert.equal(parseErf(out).entries.size,count);
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(home,dir),{recursive:true});const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(out));}catch(error){if(error.code!=='ENOENT')throw error;await fs.writeFile(file,out,{flag:'wx'});}}
 return{module,port:5125,sha256:hash(out),baseline:base.sha256,deflection,miss,shield,shieldKind,feat,scope:'Authored native NPC and installed original ranger equipment; actual unmodified server resolves attacks/damage/ammunition/misses/feat deflection/shield blocks; no original art copied'};
}
