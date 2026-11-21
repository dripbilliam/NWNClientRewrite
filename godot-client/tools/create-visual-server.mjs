// Authored extension of the hashed authored gameplay module. Original models,
// textures and script API are referenced/read; no game assets enter the module.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';import {typedGff,gffField as f,writeGff} from '../../src/gff_writer.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const root=path.resolve('.'),home=path.join(root,'runtime-logs/local-multiplayer-server'),reportName=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9)??'visual-server-fixture-v1.json';
if(!/^[a-z0-9-]+\.json$/.test(reportName))throw Error('Invalid report name');
const audio=process.argv.includes('--audio'),points=audio||process.argv.includes('--points'),moduleName=process.argv.find(arg=>arg.startsWith('--module='))?.slice(9)??(audio?'GodotSounds':points?'GodotPoints':'GodotVisuals');
if(!/^[A-Za-z][A-Za-z0-9]{1,15}$/.test(moduleName))throw Error('Invalid authored fixture module name');
const report=path.join(root,'godot-client/reports',reportName),output=path.join(home,'modules',moduleName+'.mod');
for(const file of [report,output,path.join(home,'nwm',moduleName+'.nwm')]){try{await fs.access(file);throw Error('Authored fixture output exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
const source=await fs.readFile(path.join(home,'modules/GodotGameplay.mod')),baseline=JSON.parse(await fs.readFile(path.join(root,'godot-client/reports/gameplay-server-fixture-v3.json'),'utf8'));
assert.equal(createHash('sha256').update(source).digest('hex'),baseline.sha256);
const entries=new Map(parseErf(source).entries),resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')});
const header=decodeResourceText(await resolver.getResource('nwscript',2009)),api=parseScriptApi(header);
const constant=name=>{const match=new RegExp('^int\\s+'+name+'\\s*=\\s*([0-9]+)\\s*;','m').exec(header);assert.ok(match,name);return Number(match[1]);};
const duration=constant('DURATION_TYPE_TEMPORARY'),darkness=constant('VFX_DUR_DARKNESS'),healing=constant('VFX_IMP_HEALING_S');
const code=[],patches=[],labels=new Map(),int=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);},float=value=>{const bytes=Buffer.alloc(4);bytes.writeFloatBE(value);code.push(4,4,...bytes);},string=value=>{const bytes=Buffer.from(value,'ascii');code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);};
const action=(name,count)=>{const spec=api.find(row=>row.name===name);assert.equal(spec.args.length,count,name);code.push(5,0,spec.id>>>8,spec.id&255,count);},jump=(opcode,label)=>{patches.push({at:code.length,label});code.push(opcode,0,0,0,0,0);};
for(const [command,id,type,seconds]of [['vfx',darkness,duration,6],['vfxi',healing,0,0],...(points?[['vfxp',healing,0,0]]:[]),...(audio?[['vfxloop',constant('VFX_DUR_ELEMENTAL_SHIELD'),duration,6]]:[])]){
 string('-native-'+command);action('GetPCChatMessage',0);code.push(0x0b,0x23);jump(0x1f,'next_'+command);
 float(seconds);action('GetPCChatSpeaker',0);if(command==='vfxp')action('GetLocation',1);
 // Full current API: rotate vector, translate vector, scale, miss mode, ID.
 for(let index=0;index<6;index++)float(0);float(1);int(0);int(id);action('EffectVisualEffect',5);int(type);action(command==='vfxp'?'ApplyEffectAtLocation':'ApplyEffectToObject',4);
 string('GODOT_VISUAL_ACK_'+command);action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);labels.set('next_'+command,code.length);
}
// Preserve all prior authored dialogue/chat/transition behavior. Every branch
// in the appended body is relative, so its existing offsets remain valid.
if(audio){
 string('-native-sound');action('GetPCChatMessage',0);code.push(0x0b,0x23);jump(0x1f,'next_sound');
 // Original compiler STORE_STATE/AssignCommand pattern, already exercised by
 // the authored gameplay fixture: run PlaySound with the player as OBJECT_SELF.
 code.push(0x2c,16,0,0,0,0,0,0,0,0);jump(0x1d,'sound_body_end');string('sim_heal01');action('PlaySound',1);code.push(0x20,0);labels.set('sound_body_end',code.length);action('GetPCChatSpeaker',0);action('AssignCommand',2);
 string('GODOT_SOUND_ACK');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);labels.set('next_sound',code.length);
}
code.push(...entries.get('godot_chat:2010').subarray(13));
const body=Buffer.from(code);for(const{at,label}of patches)body.writeInt32BE(labels.get(label)-at,at+2);
const script=Buffer.alloc(13+body.length);script.write('NCS V1.0');script[8]=0x42;script.writeUInt32BE(script.length,9);script.set(body,13);parseNcs(script);entries.set('godot_chat:2010',script);
const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=f(12,'Godot Visual Effects');ifo.fields.Mod_Tag=f(10,moduleName);entries.set('module:2014',writeGff('IFO ',ifo));
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((sum,value)=>sum+value.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const[index,[key,value]]of [...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);await fs.writeFile(output,bytes,{flag:'wx'});await fs.writeFile(path.join(home,'nwm',moduleName+'.nwm'),bytes,{flag:'wx'});
const result={scope:'Authored server-chat visual-effect fixture using installed API signatures/constants; no simulated effect packets or copied art',module:moduleName,sha256:createHash('sha256').update(bytes).digest('hex'),commands:[{chat:'-native-vfx',visualId:darkness,durationType:duration,seconds:6},{chat:'-native-vfxi',visualId:healing,durationType:0,seconds:0},...(points?[{chat:'-native-vfxp',visualId:healing,durationType:0,seconds:0,location:true}]:[]),...(audio?[{chat:'-native-vfxloop',visualId:constant('VFX_DUR_ELEMENTAL_SHIELD'),durationType:duration,seconds:6},{chat:'-native-sound',sound:'sim_heal01',playerCommand:true}]:[])]};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
