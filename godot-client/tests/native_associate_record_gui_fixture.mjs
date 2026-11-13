// NEW authored local module; preserves every earlier module/profile/receipt.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createAssociateRecordFixture} from './native_associate_record_server_fixture.mjs';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {typedGff,writeGff,gffField as field} from '../../src/gff_writer.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {parse2da} from '../../src/area.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function createAssociateRecordGuiFixture(directory,install){
 const baselineDirectory=path.join(directory,'accepted-baseline'),baseline=await createAssociateRecordFixture(baselineDirectory);
 const original=await fs.readFile(path.join(baselineDirectory,'modules/GodotQuick3.mod'));assert.equal(hash(original),baseline.sha256);
 const entries=new Map(parseErf(original).entries),resolver=await openServerResourceContext({install});
 const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
 const skills=parse2da(decodeResourceText(await resolver.getResource('skills',2017))),feats=parse2da(decodeResourceText(await resolver.getResource('feat',2017)));
 const cell=(row,key)=>Object.entries(row??{}).find(([name])=>name.toLowerCase()===key.toLowerCase())?.[1];
 const description=(table,id)=>{const value=cell(table.orderedRows[id],'Description');assert.match(String(value),/^\d+$/);const ref=Number(value);assert.ok(Number.isSafeInteger(ref)&&ref>=0&&ref<0xffffffff);return ref;};
 const rows={skill:{event:3,customized:1,unchanged:3,token:9011},feat:{event:4,customized:3,unchanged:4,token:9012}};
 for(const row of Object.values(rows)){
  const table=row.event===3?skills:feats;row.description=description(table,row.customized);row.unchangedDescription=description(table,row.unchanged);
  if(row.event===4)for(const id of [row.customized,row.unchanged]){assert.ok(!['','****',undefined].includes(cell(feats.orderedRows[id],'FEAT')));assert.ok(['-1','0','****'].includes(String(cell(feats.orderedRows[id],'SUCCESSOR'))));}
 }
 assert.equal(new Set(Object.values(rows).flatMap(row=>[row.description,row.unchangedDescription])).size,4,'Authored selective rows must not share description refs');
 // Genuine authored creature data, subsequently disclosed by the ORIGINAL
 // server. Never insert feats into a received/client object or installed BIC.
 const git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value.find(row=>row.fields.Tag.value==='native_speaker');assert.ok(npc);
 assert.ok(npc.fields.FeatList.value.some(row=>row.fields.Feat.value===baseline.proficiency.id));
 for(const id of [rows.feat.customized,rows.feat.unchanged])if(!npc.fields.FeatList.value.some(row=>row.fields.Feat.value===id))npc.fields.FeatList.value.push({type:1,fields:{Feat:field(2,id)}});
 entries.set('dense_a:2023',writeGff('GIT ',git));
 const code=[];
 const integer=value=>{const b=Buffer.alloc(4);b.writeInt32BE(value);code.push(4,3,...b);};
 const string=value=>{const b=Buffer.from(value,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);};
 const action=(name,count)=>{const row=api.find(row=>row.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const add=()=>code.push(0x14,0x23),player=()=>action('GetLastGuiEventPlayer',0);
 const count=()=>{string('native_record_gui_count');player();action('GetLocalInt',2);};
 const message=(prefix,value)=>{string(prefix);value();add();player();action('SendMessageToPC',2);};
 const branch=()=>{const at=code.length;code.push(0x1f,0,0,0,0,0);return at;};
 const jumps=[];
 for(const row of Object.values(rows)){
  integer(row.event);action('GetLastGuiEventType',0);code.push(0x0b,0x20);const next=branch();
  count();integer(1);code.push(0x14,0x20);string('native_record_gui_count');player();action('SetLocalInt',3);
  message('NATIVE_RECORD_TYPE:',()=>{action('GetLastGuiEventType',0);action('IntToString',1);});
  message('NATIVE_RECORD_INT:',()=>{action('GetLastGuiEventInteger',0);action('IntToString',1);});
  message('NATIVE_RECORD_TARGET:',()=>{action('GetLastGuiEventObject',0);action('ObjectToString',1);});
  message('NATIVE_RECORD_TARGET_NPC:',()=>{integer(0);string('native_speaker');action('GetObjectByTag',2);action('GetLastGuiEventObject',0);code.push(0x0b,0x22);action('IntToString',1);});
  message('NATIVE_RECORD_TARGET_PC:',()=>{player();action('GetLastGuiEventObject',0);code.push(0x0b,0x22);action('IntToString',1);});
  message('NATIVE_RECORD_POSITION:',()=>{integer(3);integer(0);action('GetLastGuiEventVector',0);action('VectorMagnitude',1);action('FloatToString',3);});
  message('NATIVE_RECORD_COUNT:',()=>{count();action('IntToString',1);});
  integer(row.customized);action('GetLastGuiEventInteger',0);code.push(0x0b,0x20);const unchanged=branch();
  string('Owned Record GUI'+row.event+' token ');count();action('IntToString',1);add();integer(row.token);action('SetCustomToken',2);
  string('Owned Record GUI'+row.event+' help ');count();action('IntToString',1);add();string(' <CUSTOM'+row.token+'>');add();integer(row.description);action('SetTlkOverride',2);
  string('NATIVE_RECORD_CUSTOMIZED:1');player();action('SendMessageToPC',2);code.push(0x20,0);
  const unchangedAt=code.length;string('NATIVE_RECORD_CUSTOMIZED:0');player();action('SendMessageToPC',2);code.push(0x20,0);
  jumps.push([unchanged,unchangedAt],[next,code.length]);
 }
 code.push(0x20,0);const body=Buffer.from(code);for(const[at,target]of jumps)body.writeInt32BE(target-at,at+2);
 const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('record_gui_evt:2010',ncs);
 const ifo=typedGff(parseGff(entries.get('module:2014')).root);Object.assign(ifo.fields,{Mod_Name:field(12,'Owned associate record GUI inspection'),Mod_Tag:field(10,'AssocRecordGui'),Mod_OnPlrGuiEvt:field(11,'record_gui_evt')});entries.set('module:2014',writeGff('IFO ',ifo));
 const size=entries.size,keys=160,resources=keys+24*size,start=resources+8*size,output=Buffer.alloc(start+[...entries.values()].reduce((sum,bytes)=>sum+bytes.length,0));
 output.write('MOD V1.0');output.writeUInt32LE(size,16);output.writeUInt32LE(160,20);output.writeUInt32LE(keys,24);output.writeUInt32LE(resources,28);let offset=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');output.write(key.slice(0,split),keys+24*index,16,'ascii');output.writeUInt32LE(index,keys+24*index+16);output.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);output.writeUInt32LE(offset,resources+8*index);output.writeUInt32LE(value.length,resources+8*index+4);output.set(value,offset);offset+=value.length;}
 assert.equal(parseErf(output).entries.size,size);
 for(const[folder,extension]of[['modules','mod'],['client/nwm','nwm']]){await fs.mkdir(path.join(directory,folder),{recursive:true});await fs.writeFile(path.join(directory,folder,'AssocRecordGui.'+extension),output,{flag:'wx'});}
 const result={module:'AssocRecordGui',port:5127,sha256:hash(output),scriptSha256:hash(ncs),baselineSha256:baseline.sha256,acceptedBaselineReceiptSha256:baseline.acceptedReceiptSha256,rows,proficiency:baseline.proficiency,scope:'NEW authored module from exact accepted baseline; only tagged placed NPC FeatList adds legitimate3/4 and module GUI script is replaced. Original server must disclose real rows, record exact GUI3/4 targets and send selective TLK/token updates. No client-owned stats injection or installed BIC edit.'};
 await fs.writeFile(path.join(directory,'fixture.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);assert.ok(option('directory')&&option('install'));console.log(JSON.stringify(await createAssociateRecordGuiFixture(option('directory'),option('install'))));}
