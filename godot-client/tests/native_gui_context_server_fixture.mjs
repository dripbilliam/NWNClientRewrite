// Authored test-only module; no original installation/profile changes.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {typedGff,writeGff,gffField as field} from '../../src/gff_writer.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function createGuiContextFixture(directory,install){
 const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
 const baseline=await fs.readFile(path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotStores.mod'));
 const prior=JSON.parse(await fs.readFile(path.join(workspace,'godot-client/reports/store-server-fixture-v1.json'),'utf8'));assert.equal(hash(baseline),prior.sha256,'Authored module baseline changed');
 const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install});
 const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[];
 const integer=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);};
 const string=value=>{const bytes=Buffer.from(value,'ascii');code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);};
 const action=(name,count)=>{const row=api.find(item=>item.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const addString=()=>code.push(0x14,0x23),player=()=>action('GetLastGuiEventPlayer',0);
 const count=()=>{string('native_context_gui_count');player();action('GetLocalInt',2);};
 const message=(prefix,body)=>{string(prefix);body();addString();player();action('SendMessageToPC',2);};
 integer(26);action('GetLastGuiEventType',0);code.push(0x0b,0x20);integer(14);action('GetLastGuiEventType',0);code.push(0x0b,0x20,7,0x20);
 const ignored=code.length;code.push(0x1f,0,0,0,0,0);
 count();integer(1);code.push(0x14,0x20);string('native_context_gui_count');player();action('SetLocalInt',3);
 message('NATIVE_CONTEXT_TYPE:',()=>{action('GetLastGuiEventType',0);action('IntToString',1);});
 message('NATIVE_CONTEXT_INT:',()=>{action('GetLastGuiEventInteger',0);action('IntToString',1);});
 message('NATIVE_CONTEXT_TARGET:',()=>{action('GetLastGuiEventObject',0);action('ObjectToString',1);});
 message('NATIVE_CONTEXT_TARGET_INVALID:',()=>{code.push(4,6,0x7f,0,0,0);action('GetLastGuiEventObject',0);code.push(0x0b,0x22);action('IntToString',1);});
 message('NATIVE_CONTEXT_TARGET_TYPE:',()=>{action('GetLastGuiEventObject',0);action('GetObjectType',1);action('IntToString',1);});
 for(const [index,axis]of ['X','Y','Z'].entries())message('NATIVE_CONTEXT_POSITION_'+axis+':',()=>{integer(3);integer(0);action('GetLastGuiEventVector',0);code.push(0x21,0,0,12,0,index*4,0,4);action('FloatToString',3);});
 const when=(type,body)=>{integer(type);action('GetLastGuiEventType',0);code.push(0x0b,0x20);const skip=code.length;code.push(0x1f,0,0,0,0,0);body();const offset=Buffer.alloc(4);offset.writeInt32BE(code.length-skip);code.splice(skip+2,4,...offset);};
 when(26,()=>{action('GetLastGuiEventObject',0);integer(1);integer(15);action('GetLastGuiEventInteger',0);code.push(0x14,0x20);player();action('SetGuiPanelDisabled',4);});
 when(14,()=>{action('GetLastGuiEventObject',0);integer(0);action('GetLastGuiEventInteger',0);player();action('SetGuiPanelDisabled',4);});
 string('Owned GUI context callback ');count();action('IntToString',1);addString();integer(9005);action('SetCustomToken',2);
 message('NATIVE_CONTEXT_DONE:',()=>{count();action('IntToString',1);});
 const end=code.length;code.push(0x20,0);const body=Buffer.from(code);body.writeInt32BE(end-ignored,ignored+2);
 const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);
 entries.set('context_gui_evt:2010',ncs);const ifo=typedGff(parseGff(entries.get('module:2014')).root);
 Object.assign(ifo.fields,{Mod_Name:field(12,'Owned GUI context events'),Mod_Tag:field(10,'GuiContext'),Mod_OnPlrGuiEvt:field(11,'context_gui_evt')});entries.set('module:2014',writeGff('IFO ',ifo));
 // Use actual original GIT field widths/struct IDs; author only isolated
 // near-entry world objects. Installed resources and module stay read-only.
 const chapter=await fs.readFile(path.join(install,'data/nwm/Chapter1.nwm')),campaign=parseErf(chapter).entries;
 const door=typedGff(parseGff(campaign.get('estate:2023')).root['Door List'][0]);
 Object.assign(door.fields,{Tag:field(10,'native_context_door'),X:field(8,54),Y:field(8,41),Z:field(8,0),Bearing:field(8,0),LinkedTo:field(10,''),LinkedToFlags:field(0,0),Plot:field(0,1)});
 const item=typedGff(parseGff(campaign.get('map_m1q2i:2023')).root.List[0]);
 Object.assign(item.fields,{Tag:field(10,'native_context_item'),XPosition:field(8,54),YPosition:field(8,43),ZPosition:field(8,0),Plot:field(0,1)});
 const git=typedGff(parseGff(entries.get('dense_a:2023')).root);
 const trigger=structuredClone(git.fields.TriggerList.value[0]);Object.assign(trigger.fields,{Tag:field(10,'native_context_trigger'),Type:field(5,0),LinkedTo:field(10,''),LinkedToFlags:field(0,0),XPosition:field(8,54),YPosition:field(8,39),ZPosition:field(8,0)});
 git.fields['Door List'].value.push(door);git.fields.List.value.push(item);git.fields.TriggerList.value.push(trigger);entries.set('dense_a:2023',writeGff('GIT ',git));
 const size=entries.size,keys=160,resources=keys+24*size,start=resources+8*size,output=Buffer.alloc(start+[...entries.values()].reduce((sum,value)=>sum+value.length,0));
 output.write('MOD V1.0');output.writeUInt32LE(size,16);output.writeUInt32LE(160,20);output.writeUInt32LE(keys,24);output.writeUInt32LE(resources,28);let offset=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');output.write(key.slice(0,split),keys+24*index,16,'ascii');output.writeUInt32LE(index,keys+24*index+16);output.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);output.writeUInt32LE(offset,resources+8*index);output.writeUInt32LE(value.length,resources+8*index+4);output.set(value,offset);offset+=value.length;}
 assert.equal(parseErf(output).entries.size,size);
 for(const folder of ['modules','client/nwm']){await fs.mkdir(path.join(directory,folder),{recursive:true});await fs.writeFile(path.join(directory,folder,'GuiContext.'+(folder==='modules'?'mod':'nwm')),output,{flag:'wx'});}
 const result={module:'GuiContext',port:5127,sha256:hash(output),scriptSha256:hash(ncs),baselineSha256:hash(baseline),tokenId:9005,chapterSha256:hash(chapter),scope:'Authored near-entry original-layout world objects and GUI26/14 callback toggles exact GUI_PANEL16..21 membership, returns exact XYZ/target type and custom-token barrier. Original-server execution; no renderer/gameplay command.'};
 await fs.writeFile(path.join(directory,'fixture.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);assert.ok(option('directory')&&option('install'));console.log(JSON.stringify(await createGuiContextFixture(option('directory'),option('install'))));}
