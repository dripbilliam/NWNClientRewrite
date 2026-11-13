// Authored test-only module. Original installation and existing profiles stay read-only.
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
import {parse2da} from '../../src/area.js';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function createFeatGuiFixture(directory,install){
 const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
 const baseline=await fs.readFile(path.join(workspace,'runtime-logs/local-multiplayer-server/modules/GodotStores.mod'));
 const prior=JSON.parse(await fs.readFile(path.join(workspace,'godot-client/reports/store-server-fixture-v1.json'),'utf8'));
 assert.equal(hash(baseline),prior.sha256,'Authored module baseline changed');
 const entries=new Map(parseErf(baseline).entries);
 const resolver=await openServerResourceContext({install});
 const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
 const feats=parse2da(decodeResourceText(await resolver.getResource('feat',2017)));
 const bardBytes=await fs.readFile(path.join(install,'data/lcv/bard.bic'));
 const bard=parseGff(bardBytes).root;
 const cell=(row,name)=>Object.entries(row??{}).find(([key])=>key.toLowerCase()===name.toLowerCase())?.[1];
 // Test-fixture selection only. Production membership never reads or projects
 // this table; native GameUiRules owns all successor/display admission.
 const known=bard.FeatList.map(row=>row.Feat).filter(id=>{
  const definition=feats.orderedRows[id],name=cell(definition,'FEAT'),next=cell(definition,'SUCCESSOR');
  return definition&&name!==undefined&&!['','****'].includes(String(name))&&['****','-1','0'].includes(String(next));
 });
 const [customizedFeat,unchangedFeat]=known;assert.equal(customizedFeat,3);assert.equal(unchangedFeat,4);
 const code=[],fix=[];
 const integer=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);};
 const string=value=>{const bytes=Buffer.from(value,'ascii');code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);};
 const action=(name,count)=>{const row=api.find(item=>item.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const addString=()=>code.push(0x14,0x23),player=()=>action('GetLastGuiEventPlayer',0);
 const count=()=>{string('native_feat_gui_count');player();action('GetLocalInt',2);};
 const message=(prefix,body)=>{string(prefix);body();addString();player();action('SendMessageToPC',2);};
 integer(4);action('GetLastGuiEventType',0);code.push(0x0b,0x20);fix.push(code.length);code.push(0x1f,0,0,0,0,0);
 // Increment only an authored event counter. No rank, ability or disguise logic.
 count();integer(1);code.push(0x14,0x20);string('native_feat_gui_count');player();action('SetLocalInt',3);
 message('NATIVE_FEAT_TYPE:',()=>{action('GetLastGuiEventType',0);action('IntToString',1);});
 message('NATIVE_FEAT_INT:',()=>{action('GetLastGuiEventInteger',0);action('IntToString',1);});
 message('NATIVE_FEAT_TARGET:',()=>{action('GetLastGuiEventObject',0);action('ObjectToString',1);});
 message('NATIVE_FEAT_TARGET_PC:',()=>{player();action('GetLastGuiEventObject',0);code.push(0x0b,0x22);action('IntToString',1);});
 message('NATIVE_FEAT_POSITION_MAGNITUDE:',()=>{integer(3);integer(0);action('GetLastGuiEventVector',0);action('VectorMagnitude',1);action('FloatToString',3);});
 message('NATIVE_FEAT_COUNT:',()=>{count();action('IntToString',1);});
 integer(customizedFeat);action('GetLastGuiEventInteger',0);code.push(0x0b,0x20);const unchanged=code.length;code.push(0x1f,0,0,0,0,0);
 string('Owned GUI4 acknowledgement ');count();action('IntToString',1);addString();integer(9002);action('SetCustomToken',2);
 string('NATIVE_FEAT_CUSTOMIZED:1');player();action('SendMessageToPC',2);code.push(0x20,0);
 const unchangedTarget=code.length;string('NATIVE_FEAT_CUSTOMIZED:0');player();action('SendMessageToPC',2);
 const end=code.length;code.push(0x20,0);
 const body=Buffer.from(code);for(const at of fix)body.writeInt32BE(end-at,at+2);body.writeInt32BE(unchangedTarget-unchanged,unchanged+2);
 const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);
 entries.set('feat_gui_evt:2010',ncs);
 const ifo=typedGff(parseGff(entries.get('module:2014')).root);
 Object.assign(ifo.fields,{Mod_Name:field(12,'Owned feat GUI4 inspection'),Mod_Tag:field(10,'FeatGui4'),Mod_OnPlrGuiEvt:field(11,'feat_gui_evt')});
 entries.set('module:2014',writeGff('IFO ',ifo));
 const size=entries.size,keys=160,resources=keys+24*size,start=resources+8*size;
 const output=Buffer.alloc(start+[...entries.values()].reduce((sum,value)=>sum+value.length,0));
 output.write('MOD V1.0');output.writeUInt32LE(size,16);output.writeUInt32LE(160,20);output.writeUInt32LE(keys,24);output.writeUInt32LE(resources,28);let offset=start;
 for(const[index,[key,value]]of[...entries].entries()){
  const split=key.lastIndexOf(':');output.write(key.slice(0,split),keys+24*index,16,'ascii');output.writeUInt32LE(index,keys+24*index+16);output.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);output.writeUInt32LE(offset,resources+8*index);output.writeUInt32LE(value.length,resources+8*index+4);output.set(value,offset);offset+=value.length;
 }
 assert.equal(parseErf(output).entries.size,size);
 for(const folder of ['modules','client/nwm']){await fs.mkdir(path.join(directory,folder),{recursive:true});await fs.writeFile(path.join(directory,folder,'FeatGui4.'+(folder==='modules'?'mod':'nwm')),output,{flag:'wx'});}
 const result={module:'FeatGui4',port:5127,sha256:hash(output),scriptSha256:hash(ncs),baselineSha256:hash(baseline),characterSha256:hash(bardBytes),tokenId:9002,customizedFeat,unchangedFeat,scope:'Authored GUI4 script records actual original-server type/integer/object/vector/count. Only one actually disclosed stock Bard feat changes a custom token; the other still emits GUI4 and leaves text unchanged. No feat activation/effect or UI rule projection is emulated.'};
 await fs.writeFile(path.join(directory,'fixture.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const option=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
 const directory=option('directory'),install=option('install');assert.ok(directory&&install);
 console.log(JSON.stringify(await createFeatGuiFixture(directory,install)));
}
