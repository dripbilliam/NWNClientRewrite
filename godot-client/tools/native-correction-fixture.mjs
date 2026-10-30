// Authored local server script only. The original server performs the position
// change and sends ordinary replication; no fake movement/animation packets.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField,writeGff} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=b=>createHash('sha256').update(b).digest('hex');
export async function createNativeCorrectionFixture(home,base){
 const input=await fs.readFile(path.join(home,'modules',base.module+'.mod'));assert.equal(hash(input),base.sha256);const entries=new Map(parseErf(input).entries);
 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[];
 const integer=(n,type=3)=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,type,...b);},real=n=>{const b=Buffer.alloc(4);b.writeFloatBE(n);code.push(4,4,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);};
 const action=(name,count)=>{const row=api.find(r=>r.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const wrap=()=>{const ncs=Buffer.alloc(13+code.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(code,13);parseNcs(ncs);return ncs;};
 // OBJECT_SELF is the PC because the chat script ExecuteScript's target is the
 // actual speaker. Location arguments are pushed in native reverse order.
 integer(0,6);action('GetFacing',1);
 real(0);real(0);real(0.75);action('Vector',3);integer(0,6);action('GetPosition',1);code.push(0x14,0x3a);
 integer(0,6);action('GetArea',1);action('Location',3);action('JumpToLocation',1);code.push(0x20,0);entries.set('native_shift:2010',wrap());code.length=0;
 str('-native-correction-step');action('GetPCChatMessage',0);code.push(0x0b,0x23);const jump=code.length;code.push(0x1f,0,0,0,0,0);
 action('GetPCChatSpeaker',0);str('native_shift');action('ExecuteScript',2);str('GODOT_CORRECTION_STEP');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);
 const next=code.length;code.push(...entries.get('godot_chat:2010').subarray(13));const chat=wrap();chat.writeInt32BE(next-jump,13+jump+2);entries.set('godot_chat:2010',chat);
 const module='GodotCorrection',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=gffField(12,'Godot Native Correction');ifo.fields.Mod_Tag=gffField(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(at,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,at);at+=value.length;}
 assert.equal(parseErf(out).entries.size,count);
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(home,dir),{recursive:true});const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(out));}catch(error){if(error.code!=='ENOENT')throw error;await fs.writeFile(file,out,{flag:'wx'});}}
 return{module,port:5125,sha256:hash(out),baseline:base.sha256,correctionDelta:[0.75,0,0],scope:'Owned local server executes authored JumpToLocation for a 0.75m correction; original server binary, real replication and original model assets. No fabricated presentation packets.'};
}
