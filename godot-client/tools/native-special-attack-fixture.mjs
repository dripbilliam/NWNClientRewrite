// Authored local target only. The unchanged server resolves each feat and death;
// no forced client record, attack result, particle state or animation is sent.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {parseErf} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField,writeGff} from '../../src/gff_writer.js';
const hash=b=>createHash('sha256').update(b).digest('hex');
export async function createNativeSpecialAttackFixture(home,base){
 const input=await fs.readFile(path.join(home,'modules',base.module+'.mod'));assert.equal(hash(input),base.sha256);const entries=new Map(parseErf(input).entries),git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value.find(c=>c.fields.Tag.value==='native_speaker');assert.ok(npc);assert.equal(npc.fields.IsImmortal.value,1);assert.equal(npc.fields.ClassList.value[0].fields.ClassLevel.value,1);
 // Quivering Palm cannot be validated against the ordinary immortal merchant
 // fixture. Use an ordinary mortal level1 target; its authoritative death is
 // allowed in this isolated scenario, after Stunning Fist has been checked.
 npc.fields.IsImmortal.value=0;entries.set('dense_a:2023',writeGff('GIT ',git));const module='GodotMonk1',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=gffField(12,'Native special-attack encounter');ifo.fields.Mod_Tag=gffField(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(at,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,at);at+=value.length;}
 assert.equal(parseErf(out).entries.size,count);for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(home,dir),{recursive:true});const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(out));}catch(e){if(e.code!=='ENOENT')throw e;await fs.writeFile(file,out,{flag:'wx'});}}
 return {module,port:5125,sha256:hash(out),baseline:base.sha256,targetLevel:1,immortal:false,scope:'Authored mortal target and original monk sample. Original server resolves feat use, combat records and death; original art remains external.'};
}
