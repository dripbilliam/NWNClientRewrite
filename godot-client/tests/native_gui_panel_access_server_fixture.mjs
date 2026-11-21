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
export async function createPanelAccessFixture(directory,install){
 const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
 const baseline=await fs.readFile(path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotStores.mod'));
 const prior=JSON.parse(await fs.readFile(path.join(workspace,'godot-client/reports/store-server-fixture-v1.json'),'utf8'));assert.equal(hash(baseline),prior.sha256,'Authored module baseline changed');
 const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install});
 const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[];
 const integer=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);};
 const string=value=>{const bytes=Buffer.from(value,'ascii');code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);};
 const action=(name,count)=>{const row=api.find(item=>item.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const addString=()=>code.push(0x14,0x23),player=()=>action('GetLastGuiEventPlayer',0);
 const count=()=>{string('native_access_gui_count');player();action('GetLocalInt',2);};
 const message=(prefix,body)=>{string(prefix);body();addString();player();action('SendMessageToPC',2);};
 integer(10);action('GetLastGuiEventType',0);code.push(0x0b,0x20);integer(14);action('GetLastGuiEventType',0);code.push(0x0b,0x20,7,0x20);
 const ignored=code.length;code.push(0x1f,0,0,0,0,0);
 count();integer(1);code.push(0x14,0x20);string('native_access_gui_count');player();action('SetLocalInt',3);
 message('NATIVE_ACCESS_TYPE:',()=>{action('GetLastGuiEventType',0);action('IntToString',1);});
 message('NATIVE_ACCESS_INT:',()=>{action('GetLastGuiEventInteger',0);action('IntToString',1);});
 message('NATIVE_ACCESS_TARGET:',()=>{action('GetLastGuiEventObject',0);action('ObjectToString',1);});
 message('NATIVE_ACCESS_TARGET_INVALID:',()=>{code.push(4,6,0x7f,0,0,0);action('GetLastGuiEventObject',0);code.push(0x0b,0x22);action('IntToString',1);});
 message('NATIVE_ACCESS_TARGET_SELF:',()=>{player();action('GetLastGuiEventObject',0);code.push(0x0b,0x22);action('IntToString',1);});
 message('NATIVE_ACCESS_POSITION_MAGNITUDE:',()=>{integer(3);integer(0);action('GetLastGuiEventVector',0);action('VectorMagnitude',1);action('FloatToString',3);});
 message('NATIVE_ACCESS_COUNT:',()=>{count();action('IntToString',1);});
 const invalid=()=>code.push(4,6,0x7f,0,0,0);
 const disable=(panel,value,targetSelf=false)=>{if(targetSelf)player();else invalid();integer(value);integer(panel);player();action('SetGuiPanelDisabled',4);};
 const popup=panel=>{integer(panel);player();action('PopUpGUIPanel',2);};
 const when=(number,body)=>{integer(number);count();code.push(0x0b,0x20);const skip=code.length;code.push(0x1f,0,0,0,0,0);body();const offset=Buffer.alloc(4);offset.writeInt32BE(code.length-skip);code.splice(skip+2,4,...offset);};
 when(1,()=>{for(const id of [5,6,7,8])disable(id,1);popup(6);});
 when(2,()=>{popup(6);popup(6);disable(6,1);disable(6,0,true);});
 when(3,()=>{disable(6,0);for(const id of [5,7,8])popup(id);});
 when(4,()=>{disable(5,0);popup(5);});
 when(5,()=>{disable(7,0);popup(7);});
 when(6,()=>{disable(8,1,true);disable(8,0);popup(8);});
 when(7,()=>{disable(8,0,true);});
 string('Owned GUI access callback ');count();action('IntToString',1);addString();integer(9004);action('SetCustomToken',2);
 message('NATIVE_ACCESS_DONE:',()=>{count();action('IntToString',1);});
 const end=code.length;code.push(0x20,0);const body=Buffer.from(code);body.writeInt32BE(end-ignored,ignored+2);
 const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);
 entries.set('panel_gui_evt:2010',ncs);const ifo=typedGff(parseGff(entries.get('module:2014')).root);
 Object.assign(ifo.fields,{Mod_Name:field(12,'Owned GUI access events'),Mod_Tag:field(10,'GuiAccess'),Mod_OnPlrGuiEvt:field(11,'panel_gui_evt')});entries.set('module:2014',writeGff('IFO ',ifo));
 const size=entries.size,keys=160,resources=keys+24*size,start=resources+8*size,output=Buffer.alloc(start+[...entries.values()].reduce((sum,value)=>sum+value.length,0));
 output.write('MOD V1.0');output.writeUInt32LE(size,16);output.writeUInt32LE(160,20);output.writeUInt32LE(keys,24);output.writeUInt32LE(resources,28);let offset=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');output.write(key.slice(0,split),keys+24*index,16,'ascii');output.writeUInt32LE(index,keys+24*index+16);output.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);output.writeUInt32LE(offset,resources+8*index);output.writeUInt32LE(value.length,resources+8*index+4);output.set(value,offset);offset+=value.length;}
 assert.equal(parseErf(output).entries.size,size);
 for(const folder of ['modules','client/nwm']){await fs.mkdir(path.join(directory,folder),{recursive:true});await fs.writeFile(path.join(directory,folder,'GuiAccess.'+(folder==='modules'?'mod':'nwm')),output,{flag:'wx'});}
 const result={module:'GuiAccess',port:5127,sha256:hash(output),scriptSha256:hash(ncs),baselineSha256:hash(baseline),tokenId:9004,scope:'Authored GUI10 bootstrap and GUI14 callback invokes actual SetGuiPanelDisabled/PopUpGUIPanel and reports type/selection/exact target/zero vector/count through speech and custom token. Original-server execution, no game renderer or gameplay command.'};
 await fs.writeFile(path.join(directory,'fixture.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);assert.ok(option('directory')&&option('install'));console.log(JSON.stringify(await createPanelAccessFixture(option('directory'),option('install'))));}
