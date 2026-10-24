// Authored NUI layouts/scripts over the verified owned ActivatePortal fixtures.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField as F,writeGff,encodeGffText} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const revision=Number(process.argv.find(v=>v.startsWith('--revision='))?.slice(11)??2);assert.ok(Number.isSafeInteger(revision)&&revision>=2&&revision<=9);
const syncIcon=process.argv.includes('--nwsync-icon');
const report=`godot-client/reports/nui-handoff-server-fixtures-v${revision}.json`,base=JSON.parse(await fs.readFile('godot-client/reports/handoff-server-fixtures-v1.json','utf8'));
try{await fs.access(report);throw Error('Fixture report exists');}catch(e){if(e.code!=='ENOENT')throw e;}
const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
class Script{
 constructor(){this.code=[];this.labels=new Map();this.fix=[];}
 string(v){const b=encodeGffText(v);assert.ok(b.length<16000);this.code.push(4,5,b.length>>>8,b.length&255,...b);return this;}
 action(name,count){const row=api.find(v=>v.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);this.code.push(5,0,row.id>>>8,row.id&255,count);return this;}
 json(v){return this.string(JSON.stringify(v)).action('JsonParse',1);}
 drop(){this.code.push(0x1b,0,255,255,255,252);return this;}
 when(fn,value,label,body){this.string(value).action(fn,0);this.code.push(0x0b,0x23);this.fix.push({at:this.code.length,label});this.code.push(0x1f,0,0,0,0,0);body();this.labels.set(label,this.code.length);return this;}
 finish(tail){this.code.push(...(tail?tail.subarray(13):[0x20,0]));const b=Buffer.from(this.code);for(const{at,label}of this.fix)b.writeInt32BE(this.labels.get(label)-at,at+2);const n=Buffer.alloc(13+b.length);n.write('NCS V1.0');n[8]=0x42;n.writeUInt32BE(n.length,9);n.set(b,13);parseNcs(n);return n;}
}
const writes=[],servers=[];
function pack(entries,kind){const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write(kind+' V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}assert.equal(parseErf(bytes).entries.size,count);return bytes;}
for(const row of base.servers){
 const source=await fs.readFile(path.join(row.profile,'modules/'+row.module+'.mod'));assert.equal(createHash('sha256').update(source).digest('hex'),row.sha256);
 const entries=new Map(parseErf(source).entries),label=row.label,module='GodotHand'+label+(revision+1);
 const layout={title:'Transfer NUI '+label,geometry:{x:70,y:100,w:460,h:260},root:{type:'col',children:[{type:'label',id:'caption',value:{bind:'caption'},height:35},{type:'textedit',id:'edit',value:{bind:'name'},max:64,height:40},{type:'label',id:'echo',value:{bind:'echo'},height:35},{type:'button',id:'child',label:'Open server '+label+' child',height:40},{type:'button_image',id:'icon',label:'is_light',width:48,height:48}]}},child={title:'Transfer child '+label,geometry:{x:560,y:120,w:430,h:180},root:{type:'col',children:[{type:'label',id:'resource',value:'Resource belongs to server '+label,height:40},{type:'button',id:'ack',label:'Acknowledge on '+label,height:40}]}};
 if(syncIcon)layout.root.children.find(v=>v.id==='icon').label='gd_sync_icon';
 child.root.children.splice(1,0,{type:'label',id:'caption',value:{bind:'caption'},height:35});
 const set=(s,bind,value)=>s.json(value).string(bind).action('NuiGetEventWindow',0).action('NuiGetEventPlayer',0).action('NuiSetBind',4);
 const event=new Script();
 event.when('NuiGetEventType','open','open',()=>{set(event,'caption','Opened by server '+label);set(event,'name','Draft '+label);set(event,'echo','Awaiting '+label);event.code.push(4,3,0,0,0,1);event.string('name').action('NuiGetEventWindow',0).action('NuiGetEventPlayer',0).action('NuiSetBindWatch',4).drop();});
 event.when('NuiGetEventType','watch','watch',()=>event.string('name').action('NuiGetEventWindow',0).action('NuiGetEventPlayer',0).action('NuiGetBind',3).string('echo').action('NuiGetEventWindow',0).action('NuiGetEventPlayer',0).action('NuiSetBind',4));
 event.when('NuiGetEventType','click','click',()=>{
  event.when('NuiGetEventElement','child','child',()=>event.string('port_nui_evt').string('child').string('port_nui_jui').action('NuiGetEventPlayer',0).action('NuiCreateFromResRef',4).drop());
  event.when('NuiGetEventElement','ack','ack',()=>set(event,'caption','Acknowledged by server '+label));
 });entries.set('port_nui_evt:2010',event.finish());entries.set('port_nui_jui:2083',Buffer.from(JSON.stringify(child)));
 const chat=new Script();chat.when('GetPCChatMessage','-native-transfer-nui','nui',()=>{chat.string('port_nui_evt').string('root').json(layout).action('GetPCChatSpeaker',0).action('NuiCreate',4).drop();chat.code.push(0x20,0);});entries.set('godot_chat:2010',chat.finish(entries.get('godot_chat:2010')));
 const hakName='handnui_'+label.toLowerCase()+revision,hak=pack(new Map([['port_nui_jui:2083',Buffer.from(JSON.stringify(child))]]),'HAK');
 const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=F(12,'Godot NUI Handoff '+label);ifo.fields.Mod_Tag=F(10,module);ifo.fields.Mod_OnNuiEvent=F(11,'port_nui_evt');ifo.fields.Mod_HakList=F(15,[{type:0,fields:{Mod_Hak:F(10,hakName)}}]);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}assert.equal(parseErf(bytes).entries.size,count);
 // Both authored module packs are available to the local resource resolver;
 // each server still has a separate exact profile and UDP endpoint.
 for(const profile of new Set([row.profile,base.servers[0].profile]))for(const dir of ['modules','nwm'])writes.push({file:path.join(profile,dir,module+(dir==='nwm'?'.nwm':'.mod')),bytes});
 for(const profile of new Set([row.profile,base.servers[0].profile]))writes.push({file:path.join(profile,'hak',hakName+'.hak'),bytes:hak});
 servers.push({...row,module,hak:hakName,hakSha256:createHash('sha256').update(hak).digest('hex'),sha256:createHash('sha256').update(bytes).digest('hex')});
}
for(const{file}of writes){try{await fs.access(file);throw Error('Fixture output exists: '+file);}catch(e){if(e.code!=='ENOENT')throw e;}}
for(const{file,bytes}of writes){await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,bytes,{flag:'wx'});}
const result={version:1,servers,command:'-native-transfer-nui',scope:'Owned loopback NUI across real server handoff; same JUI resref with distinct A/B module content; original artwork referenced only'};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
