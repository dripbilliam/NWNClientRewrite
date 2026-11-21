import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptResourceReference,ScriptResourceRuntime,importObjectTemplateReference} from '../src/script_resref.js';
import {scriptStringCase} from '../src/script_string.js';
import {decodeGffText,encodeGffText} from '../src/gff_text.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
import {ModuleSession} from '../src/module_session.js';
import {canCarryUUID} from '../src/object_uuid.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-resref-observations.json',import.meta.url))),decode=hex=>decodeGffText(Buffer.from(hex,'hex')),hex=text=>Buffer.from(encodeGffText(text)).toString('hex');

test('resource-reference commands match full original handler, original virtual casts, string lengths and case conversion',async()=>{
 for(const row of oracle.rows){const c=row.case,calls=[],object={},area={};let casts=0,output=null;
  const status=await scriptResourceReference(c.command,{pop:type=>{calls.push(['pop',type]);return{ok:Boolean(c.pop),value:c.id};},object:id=>{calls.push(['object',id]);return c.kind==='missing'?null:object;},
   asObject:o=>{assert.equal(o,object);calls.push(['asObject']);casts++;return['object','sound','both','second-null'].includes(c.kind)&&!(c.kind==='second-null'&&casts===2)?object:null;},
   asArea:o=>{assert.equal(o,object);calls.push(['asArea']);return['area','both','second-null'].includes(c.kind)?area:null;},
   template:o=>{assert.equal(o,object);return c.nullString?'':decode(c.hex);},resref:(o,offset)=>{assert.equal(o,area);return decode(offset===0x120?c.areaHex:c.tilesetHex);},
   lowercase:value=>{calls.push(['lowercase',hex(value)]);return scriptStringCase(value);},push:value=>{output=hex(value);calls.push(['push',output]);return c.push;}});
  assert.equal(status>>>0,row.result,JSON.stringify(c));assert.equal(output,row.output,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
 assert.equal(oracle.rows.length,682);
 assert.equal(oracle.virtualSlots.base['0x20'],'0x1402962e0');assert.equal(oracle.virtualSlots.base['0x50'],'0x140296270');assert.equal(oracle.virtualSlots.object['0x20'],'0x140382910');assert.equal(oracle.virtualSlots.area['0x50'],'0x14035c250');
});

test('serialized template import admits only native RESREF fields and retains constructor empty values for unsupported kinds',()=>{
 for(const type of[5,6,7,9,10,12,13,14]){
  const object={objectType:type,templateResRef:'old'};
  const correct=parseGff(writeGff('UTC ',gffRecord({TemplateResRef:gffField(11,'MiXeD')},0xffffffff))).root;importObjectTemplateReference(object,correct);assert.equal(object.templateResRef,'MiXeD');
  const wrong=parseGff(writeGff('UTC ',gffRecord({TemplateResRef:gffField(10,'not a resref')},0xffffffff))).root;importObjectTemplateReference(object,wrong);assert.equal(object.templateResRef,'');
  const missing=parseGff(writeGff('UTC ',gffRecord({},0xffffffff))).root;object.templateResRef='old';importObjectTemplateReference(object,missing);assert.equal(object.templateResRef,'');
 }
 for(const type of[3,4,8,11,16]){const object={objectType:type,templateResRef:'old'};importObjectTemplateReference(object,{TemplateResRef:'do not read'});assert.equal(object.templateResRef,'old');}
});

test('runtime reads canonical live storage, separates area/tileset/template references and rejects unavailable locale conversion',async()=>{
 const objects=new Map([[1,{objectType:5,templateResRef:'LIVE\0ABC',authored:{TemplateResRef:'stale'}}],[2,{objectType:4,resRef:'ArEa',tilesetResRef:'TilEs'}],[3,{objectType:3,templateResRef:'module fake'}],[4,{objectType:16,templateResRef:'sound fake'}]]),runtime=new ScriptResourceRuntime({registry:{get:id=>objects.get(id)}});
 assert.equal(await runtime.command(582,[1]),'live\0abc');objects.get(1).templateResRef='Changed';assert.equal(await runtime.command(582,[1]),'changed');
 assert.equal(await runtime.command(582,[2]),'area');assert.equal(await runtime.command(814,[2]),'tiles');assert.equal(await runtime.command(814,[1]),'');
 assert.equal(await runtime.command(582,[4]),'sound fake');
 for(const id of[3,0x7f000000,0x80000001])assert.equal(await runtime.command(582,[id]),'');
 objects.get(1).templateResRef='É';await assert.rejects(runtime.command(582,[1]),/locale-specific bytes/);await assert.rejects(runtime.stack(582,{pop:()=>{throw new Error('typed pop failed');}},{}),/typed pop failed/);
 assert.equal(objects.size,4);
});

test('sound construction includes the proven CNWSObject base without granting native UUID eligibility',async()=>{
 const s=new ModuleSession({}),sound=s.register('sound','resref-sound',{position:[1,2,3],authored:{TemplateResRef:'unread'}});
 assert.equal(sound.objectType,16);assert.equal(sound.templateResRef,'');assert.equal(sound.nativeFieldEc,1);assert.equal(sound.nativeAILevel7c,-1);assert.equal(sound.nativeDestroyableF0,1);assert.deepEqual(sound.effects,[]);assert.deepEqual(sound.orientation,[1,0,-0]);assert.equal(sound.nativePortraitId,65535);
 assert.equal(canCarryUUID(sound.objectType),0);assert.equal(sound.nativeUUID,undefined);
 assert.equal(await s.commands.GetResRef([sound.id]),'');sound.templateResRef='LiVeSound';assert.equal(await s.commands.GetResRef([sound.id]),'livesound');assert.equal(s.registry.get(sound.id),sound);
 const effect=s.effects.create(15,sound.id,[1],8);assert.equal(effect.creatorId,sound.id);assert.equal(effect.casterLevel,0);assert.equal(effect.spellId,-1);
});
