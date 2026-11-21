// Extends authored fixture metadata/scripts only. Installed UTI/model/icon
// payloads remain in the installation and are referenced by name.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {gffField as f,gffRecord as r,typedGff,writeGff} from '../../src/gff_writer.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';import {parseScriptApi,parseNcs} from '../../src/ncs.js';
const home=path.resolve('runtime-logs/local-multiplayer-server'),name=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9);
if(!/^[a-z0-9-]+\.json$/.test(name??''))throw Error('Provide an unused report name');
const output=path.join(home,'modules/GodotStores.mod'),report=path.resolve('godot-client/reports',name);
for(const file of[output,report,path.join(home,'nwm/GodotStores.nwm')]){try{await fs.access(file);throw Error('Fixture output already exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
const baseline=await fs.readFile(path.join(home,'modules/GodotContainers.mod')),reference=JSON.parse(await fs.readFile('godot-client/reports/container-server-fixture-v1.json'));
assert.equal(createHash('sha256').update(baseline).digest('hex'),reference.sha256);
const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')});
for(const ref of['nw_cloth001','nw_it_mpotion001'])assert.ok((await resolver.getResource(ref,2025)).byteLength);
const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[],patches=[],labels=new Map();
const int=value=>{const b=Buffer.alloc(4);b.writeInt32BE(value);code.push(4,3,...b);},string=value=>{const b=Buffer.from(value,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(row=>row.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);},jump=(opcode,label)=>{patches.push({at:code.length,label});code.push(opcode,0,0,0,0,0);},drop=()=>code.push(0x1b,0,255,255,255,252),pc=()=>action('GetPCChatSpeaker',0),store=()=>{int(0);string('native_store');action('GetObjectByTag',2);};
for(const command of['setup','store']){
 string('-native-'+(command==='setup'?'store-setup':'store'));action('GetPCChatMessage',0);code.push(0x0b,0x23);jump(0x1f,'next_'+command);
 if(command==='setup'){
  string('native_store');int(0);pc();action('GetLocation',1);string('native_store');int(128);action('CreateObject',5);drop();
  for(let i=0;i<18;i++){string('native_stock_'+i);int(1);store();string('nw_cloth001');action('CreateItemOnObject',4);drop();}
  string('native_potion');int(1);store();string('nw_it_mpotion001');action('CreateItemOnObject',4);drop();
  int(50000);pc();action('GiveGoldToCreature',2);
  // An unidentified carried item exercises the server's identification path.
  int(0);string('native_unidentified');int(1);pc();string('nw_it_mpotion001');action('CreateItemOnObject',4);action('SetIdentified',2);
  string('GODOT_STORE_READY');pc();action('SendMessageToPC',2);
 }else{int(0);int(0);pc();store();action('OpenStore',4);}
 code.push(0x20,0);labels.set('next_'+command,code.length);
}
code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);for(const{at,label}of patches)body.writeInt32BE(labels.get(label)-at,at+2);
const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
entries.set('native_store:2051',writeGff('UTM ',r({Tag:f(10,'native_store'),ResRef:f(11,'native_store'),LocName:f(12,'Native test merchant'),MarkUp:f(5,125),MarkDown:f(5,50),BM_MarkDown:f(5,25),StoreGold:f(5,100000),MaxBuyPrice:f(5,-1),IdentifyPrice:f(5,100),BlackMarket:f(0,0),StoreList:f(15,Array.from({length:5},(_,i)=>r({ItemList:f(15,[])},i))),WillNotBuy:f(15,[]),WillOnlyBuy:f(15,[])},0)));
const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=f(12,'Godot Stores');ifo.fields.Mod_Tag=f(10,'GodotStores');entries.set('module:2014',writeGff('IFO ',ifo));
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);await fs.writeFile(output,bytes,{flag:'wx'});await fs.writeFile(path.join(home,'nwm/GodotStores.nwm'),bytes,{flag:'wx'});
const result={scope:'Authored local merchant with installed template references only; actual native OpenStore/buy/sell/identify test',module:'GodotStores',sha256:createHash('sha256').update(bytes).digest('hex'),commands:['-native-store-setup','-native-store'],stock:['18 × nw_cloth001','1 × nw_it_mpotion001'],identifyTemplate:'nw_it_mpotion001',storeGold:100000,identifyPrice:100};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
