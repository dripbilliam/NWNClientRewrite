import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {parseErf,RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parseGff} from '../src/gff.js';
import {typedGff,gffField as F,writeGff} from '../src/gff_writer.js';
import {parseScriptApi} from '../src/ncs.js';
export async function createObjectUIFixture(install){
 const raw=await fs.readFile(path.join(install,'data/nwm/Prelude.nwm')),archive=parseErf(raw),resolver=await openLocalModule(install,path.join(install,'data/nwm/Prelude.nwm')),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',RESOURCE_TYPE.NSS)));
 const reference=[...resolver.key.resources.values()].find(row=>row.resourceType===RESOURCE_TYPE.UTP)?.resref;assert.ok(reference);
 const code=[],int=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);},object=()=>code.push(4,6,0,0,0,0),float=value=>{const bytes=Buffer.alloc(4);bytes.writeFloatBE(value);code.push(4,4,...bytes);},string=value=>{const bytes=Buffer.from(value,'latin1');code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);},action=(name,argc)=>{const id=api.findIndex(row=>row.name===name);assert.ok(id>=0);code.push(5,0,id>>>8,id&255,argc);};
 string('CreatedByScript');int(0);object();action('GetLocation',1);string(reference);int(64);action('CreateObject',5);
 string('Created');object();action('SetLocalObject',3);float(0);object();action('DestroyObject',2);code.push(0x20,0);
 const ncs=Buffer.alloc(13+code.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(code,13);
 const key=(name,type)=>`${name}:${type}`,git=typedGff(parseGff(archive.entries.get(key('m0q1a',RESOURCE_TYPE.GIT))).root),source=git.fields['Placeable List'].value[0];assert.ok(source);
 Object.assign(source.fields,{Tag:F(10,'CreateSource'),X:F(8,25.5),Y:F(8,14),Z:F(8,0),Static:F(0,0),Useable:F(0,1),HasInventory:F(0,0),Plot:F(0,0),Locked:F(0,0),OnUsed:F(11,'mkobject'),ItemList:F(15,[])});
 const ifo=typedGff(parseGff(archive.entries.get(key('module',RESOURCE_TYPE.IFO))).root);Object.assign(ifo.fields,{Mod_Entry_Area:F(11,'m0q1a'),Mod_Entry_X:F(8,24),Mod_Entry_Y:F(8,14),Mod_Entry_Z:F(8,0)});
 archive.entries.set(key('m0q1a',RESOURCE_TYPE.GIT),new Uint8Array(writeGff('GIT ',git)));archive.entries.set(key('module',RESOURCE_TYPE.IFO),new Uint8Array(writeGff('IFO ',ifo)));archive.entries.set(key('mkobject',RESOURCE_TYPE.NCS),ncs);
 const entries=[...archive.entries],keys=160,resources=keys+entries.length*24,data=resources+entries.length*8,bytes=Buffer.alloc(data+entries.reduce((sum,[_key,value])=>sum+value.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(entries.length,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=data;
 entries.forEach(([reference,value],index)=>{const split=reference.lastIndexOf(':'),name=reference.slice(0,split),type=Number(reference.slice(split+1));bytes.write(name,keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(type,keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;});
 return{encoded:bytes.toString('base64'),reference};
}
