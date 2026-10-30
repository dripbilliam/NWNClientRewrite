// Authored extension only. Installed nwscript API/constants are read-only;
// original models/textures are referenced by resref, never copied here.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField,writeGff} from '../../src/gff_writer.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function createNativeEffectsFixture(home){
 const prior=JSON.parse(await fs.readFile('godot-client/reports/world-audio-server-fixture-v2.json')),input=await fs.readFile(path.resolve('runtime-logs/local-multiplayer-server/modules',prior.module+'.mod'));assert.equal(hash(input),prior.sha256);
 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),header=decodeResourceText(await resolver.getResource('nwscript',2009)),api=parseScriptApi(header);
 const constant=name=>{const match=new RegExp('^int\\s+'+name+'\\s*=\\s*([0-9]+)\\s*;','m').exec(header);assert.ok(match,name);return Number(match[1]);};
 const code=[],int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},float=n=>{const b=Buffer.alloc(4);b.writeFloatBE(n);code.push(4,4,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(r=>r.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 str('-native-beam');action('GetPCChatMessage',0);code.push(0x0b,0x23);const jump=code.length;code.push(0x1f,0,0,0,0,0);
 float(5);int(0);str('native_speaker');action('GetObjectByTag',2);
 for(let i=0;i<6;i++)float(0);float(1);int(0);int(constant('BODY_NODE_HAND'));action('GetPCChatSpeaker',0);int(constant('VFX_BEAM_LIGHTNING'));action('EffectBeam',7);int(constant('DURATION_TYPE_TEMPORARY'));action('ApplyEffectToObject',4);
 str('GODOT_NATIVE_BEAM_ACK');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);
 const next=code.length;
 str('-native-projectile');action('GetPCChatMessage',0);code.push(0x0b,0x23);const projectileJump=code.length;code.push(0x1f,0,0,0,0,0);
 action('GetPCChatSpeaker',0);str('native_proj');action('ExecuteScript',2);code.push(0x20,0);
 const castNext=code.length;
 str('-native-cast-release');action('GetPCChatMessage',0);code.push(0x0b,0x23);const castJump=code.length;code.push(0x1f,0,0,0,0,0);
 action('GetPCChatSpeaker',0);str('native_release');action('ExecuteScript',2);code.push(0x20,0);
 const original=code.length,entries=new Map(parseErf(input).entries);code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);body.writeInt32BE(next-jump,jump+2);body.writeInt32BE(castNext-projectileJump,projectileJump+2);body.writeInt32BE(original-castJump,castJump+2);
 const script=Buffer.alloc(13+body.length);script.write('NCS V1.0');script[8]=0x42;script.writeUInt32BE(script.length,9);script.set(body,13);parseNcs(script);entries.set('godot_chat:2010',script);
 code.length=0;
 int(0);int(-1);int(0);int(constant('PROJECTILE_PATH_TYPE_DEFAULT'));int(0);int(1);int(constant('METAMAGIC_ANY'));int(0);str('native_speaker');action('GetObjectByTag',2);int(constant('SPELL_FIREBALL'));action('ActionCastSpellAtObject',9);code.push(0x20,0);
 const projectileScript=Buffer.alloc(13+code.length);projectileScript.write('NCS V1.0');projectileScript[8]=0x42;projectileScript.writeUInt32BE(projectileScript.length,9);projectileScript.set(code,13);parseNcs(projectileScript);entries.set('native_proj:2010',projectileScript);
 code.length=0;
 int(0);int(-1);int(0);int(constant('PROJECTILE_PATH_TYPE_DEFAULT'));int(0);int(1);int(constant('METAMAGIC_ANY'));int(0);str('native_speaker');action('GetObjectByTag',2);int(constant('SPELL_MAGIC_MISSILE'));action('ActionCastSpellAtObject',9);code.push(0x20,0);
 const castScript=Buffer.alloc(13+code.length);castScript.write('NCS V1.0');castScript[8]=0x42;castScript.writeUInt32BE(castScript.length,9);castScript.set(code,13);parseNcs(castScript);entries.set('native_release:2010',castScript);
 // The previous NPC was across a native LOS blocker. Place this authored
 // test target on the same known-clear segment used by the admission walk.
 const git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value.find(row=>row.fields.Tag.value==='native_speaker');assert.ok(npc);
 npc.fields.XPosition.value=48.4;npc.fields.YPosition.value=39.98;npc.fields.ZPosition.value=0;entries.set('dense_a:2023',writeGff('GIT ',git));
 const module='GodotNativeFx4',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=gffField(12,'Native effect integration');ifo.fields.Mod_Tag=gffField(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+24*index,16,'ascii');bytes.writeUInt32LE(index,keys+24*index+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);bytes.writeUInt32LE(at,resources+8*index);bytes.writeUInt32LE(value.length,resources+8*index+4);bytes.set(value,at);at+=value.length;}
 assert.equal(parseErf(bytes).entries.size,count);
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(home,dir),{recursive:true});const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.ok((await fs.readFile(file)).equals(bytes));}catch(error){if(error.code!=='ENOENT')throw error;await fs.writeFile(file,bytes,{flag:'wx'});}}
 return{...prior,module,sha256:hash(bytes),baseline:prior.sha256,port:5125,commands:[...prior.commands,{chat:'-native-beam',visualId:constant('VFX_BEAM_LIGHTNING'),seconds:5,source:'PC',target:'native_speaker'},{chat:'-native-projectile',spellId:constant('SPELL_FIREBALL'),source:'PC',target:'native_speaker',serverScript:true},{chat:'-native-cast-release',spellId:constant('SPELL_MAGIC_MISSILE'),source:'PC',target:'native_speaker',serverScript:true}]};
}
