// Authored localhost JRL/NCS only; the original server owns all journal updates.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffRecord,gffField as field,writeGff} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=b=>createHash('sha256').update(b).digest('hex');
export async function createNativeJournalFixture(home,base){
 const input=await fs.readFile(path.join(home,'modules',base.module+'.mod'));assert.equal(hash(input),base.sha256);const entries=new Map(parseErf(input).entries);
 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[],patches=[];
 const integer=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);};
 const action=(name,count)=>{const row=api.find(r=>r.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const category=gffRecord({Name:field(12,'NATIVE_JOURNAL_QUEST'),Tag:field(10,'native_journal'),XP:field(4,0),Priority:field(4,3),Picture:field(2,65535),Comment:field(10,''),EntryList:field(15,[1,2,3].map(id=>gffRecord({ID:field(4,id),End:field(2,id===3?1:0),Text:field(12,'NATIVE_JOURNAL_STAGE_'+id)},0)))},0);
 entries.set('module:2056',writeGff('JRL ',gffRecord({Categories:field(15,[category])})));
 for(const state of [1,2,3,0]){
  str('-native-journal-'+state);action('GetPCChatMessage',0);code.push(0x0b,0x23);const jump=code.length;code.push(0x1f,0,0,0,0,0);
  if(state){integer(1);integer(0);integer(0);action('GetPCChatSpeaker',0);integer(state);str('native_journal');action('AddJournalQuestEntry',6);}
  else{integer(0);integer(0);action('GetPCChatSpeaker',0);str('native_journal');action('RemoveJournalQuestEntry',4);}
  str('NATIVE_JOURNAL_ACK_'+state);action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);patches.push({jump,next:code.length});
 }
 code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);for(const p of patches)body.writeInt32BE(p.next-p.jump,p.jump+2);const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
 const module='GodotJournal2',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=field(12,'Godot Native Journal');ifo.fields.Mod_Tag=field(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(at,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,at);at+=value.length;}
 assert.equal(parseErf(out).entries.size,count);assert.equal(parseGff(entries.get('module:2056')).root.Categories[0].EntryList[2].End,1);
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(home,dir),{recursive:true});const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(out));}catch(error){if(error.code!=='ENOENT')throw error;await fs.writeFile(file,out,{flag:'wx'});}}
 return{module,port:5125,sha256:hash(out),baseline:base.sha256,journal:{tag:'native_journal',states:[1,2,3],removed:0},scope:'Authored JRL and chat actions invoke original-server AddJournalQuestEntry/RemoveJournalQuestEntry. Actual journal replication; no fabricated client state or original profile changes.'};
}
