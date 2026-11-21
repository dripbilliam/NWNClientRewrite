// Authored assets and offline JS oracles only. No server or original assets.
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {workshopContent} from '../../electron/workshop_content.mjs';
const folder=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-local-content-')),install=path.join(folder,'install'),profile=path.join(folder,'profile'),mods=path.join(folder,'steamapps/workshop/content/704450'),cache=path.join(folder,'cache');
const write=async(file,bytes)=>{await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,bytes,{flag:'wx'});};
const hash=(bytes,algorithm='sha256')=>crypto.createHash(algorithm).update(bytes).digest('hex');
const originalFixture=path.resolve('godot-client/reports/native-data-fixture-v1');
for(const[from,to]of [['base.key','data/nwn_base.key'],['data/base.bif','data/base.bif']])await write(path.join(install,to),await fs.readFile(path.join(originalFixture,from)));
function erf(entries){const start=160,table=start+entries.length*24,payload=table+entries.length*8,result=Buffer.alloc(payload+entries.reduce((sum,row)=>sum+row.bytes.length,0));result.write('HAK V1.0');result.writeUInt32LE(entries.length,16);result.writeUInt32LE(start,24);result.writeUInt32LE(table,28);let at=payload;entries.forEach((row,i)=>{const key=start+i*24;result.write(row.name,key,16,'latin1');result.writeUInt32LE(i,key+16);result.writeUInt16LE(row.type,key+20);result.writeUInt32LE(at,table+i*8);result.writeUInt32LE(row.bytes.length,table+i*8+4);row.bytes.copy(result,at);at+=row.bytes.length;});return result;}
const row=(name,type,text)=>({name,type,bytes:Buffer.from(text,'latin1')}),table=label=>`2DA V2.0\n\nLabel Value\n0 ${label} 17\n`;
const serverFile=path.join(profile,'hak/server.hak'),moduleFile=path.join(install,'data/nwm/Prelude.nwm');
await write(serverFile,erf([row('shared',2017,'server'),row('hakmod',2017,'server-hak'),row('format',2033,'server-dds')]));
await write(moduleFile,erf([row('shared',2017,'module'),row('hakmod',2017,'module'),row('localmod',2017,'module'),row('module_override',2017,'module'),row('moduleonly',2017,'module-only'),row('format',3,'module-tga')]));
for(const[id,marker]of [['local','local-root'],['11','eleven'],['22','twenty-two'],['99','pending']]){
 const base=id==='local'?mods:path.join(mods,id);
 await write(path.join(base,'hak/a.hak'),erf([row('globalwinner',2017,marker),row('globaltable',2017,table(marker)),row('localmod',2017,marker),row('mod'+(id==='local'?'local':id),2017,marker)]));
 await write(path.join(base,'portraits/portrait.dds'),Buffer.from(marker+'-portrait'));
 await write(path.join(base,'portraits/portrait_rule.2da'),Buffer.from('must-not-be-rules'));
 await write(path.join(base,'override/workshoponly.2da'),Buffer.from(marker+'-override'));
}
const metadata=path.resolve(mods,'../../appworkshop_704450.acf');
await write(metadata,'"AppWorkshop"\n{\n"WorkshopItemsInstalled"\n{\n"22"\n{ "manifest" "22" }\n"11"\n{ "manifest" "11" }\n}\n"WorkshopItemDetails"\n{ "99" {"manifest" "pending"} }\n}\n');
for(const[file,value]of [[path.join(profile,'override/empty.wav'),'profile-wav'],[path.join(profile,'override/fallback.2da'),'profile-override'],[path.join(profile,'override/module_override.2da'),'profile-override'],[path.join(profile,'override/xformat.tga'),'profile-tga'],[path.join(profile,'override/sameformat.tga'),'profile-same'],[path.join(profile,'portraits/portrait.tga'),'profile-portrait'],[path.join(install,'data/prt/installed_portr.tga'),'installed-portrait'],[path.join(install,'ovr/fallback.2da'),'install-ovr'],[path.join(install,'override/fallback.2da'),'install-override']])await write(file,Buffer.from(value));
const syncEntries=[row('shared',2017,'sync-shared'),row('xformat',2033,'sync-dds'),row('sameformat',3,'sync-same'),row('portrait',3,'sync-portrait'),row('installed_portr',2033,'sync-installed-dds')];
const manifest=Buffer.alloc(16+syncEntries.length*42);manifest.write('NSYM');manifest.writeUInt32LE(3,4);manifest.writeUInt32LE(syncEntries.length,8);
for(const[at,entry]of syncEntries.entries()){const offset=16+at*42;Buffer.from(hash(entry.bytes,'sha1'),'hex').copy(manifest,offset);manifest.writeUInt32LE(entry.bytes.length,offset+20);manifest.write(entry.name,offset+24,16,'latin1');manifest.writeUInt16LE(entry.type,offset+40);const encoded=Buffer.alloc(16+entry.bytes.length);encoded.write('NSYC');encoded.writeUInt32LE(3,4);encoded.writeUInt32LE(entry.bytes.length,12);entry.bytes.copy(encoded,16);await write(path.join(cache,'objects',hash(entry.bytes,'sha1')),encoded);}
const manifestHash=hash(manifest,'sha1');await write(path.join(cache,'manifests',manifestHash),manifest);
const syncMap=new Map(syncEntries.map(entry=>[entry.name+':'+entry.type,entry.bytes])),layer={catalog:new Map(syncMap),hasResource:(name,type)=>syncMap.has(name+':'+type),getResource:async(name,type)=>syncMap.get(name+':'+type)};
const queries=[['shared',2017],['hakmod',2017],['localmod',2017],['module_override',2017],['moduleonly',2017],['globalwinner',2017],['globaltable',2017],['empty',4],['fallback',2017],['workshoponly',2017],['mod99',2017],['portrait_rule',2017],['portrait',3],['portrait',2033],['installed_portr',3]];
const variants=[];
for(const disabledMods of [[],['local'],['local','22'],['11','22','local']]){
 const resolver=await openServerResourceContext({install,userDirectory:profile,modsDirectory:mods,disabledMods,module:moduleFile,resolved:[{kind:'hak',name:'server',resource:serverFile},{kind:'nwsync',name:manifestHash,resource:layer}]});
 const resources=[];for(const[name,type]of queries){const present=resolver.hasResource(name,type);resources.push({name,type,present,...(present?{sha256:hash(Buffer.from(await resolver.getResource(name,type)))}:{})});}
 const textures=[];for(const name of ['format','xformat','sameformat','portrait','installed_portr']){const selected=await resolver.getTextureResource(name);textures.push({name,type:selected.type,sha256:hash(Buffer.from(selected.bytes))});}
 const workshop=workshopContent(mods,{disabledMods}),roots=(await workshop.mods()).filter(value=>value.enabled).map(value=>value.id);
 variants.push({sources:{install,profileDirectory:profile,modsDirectory:mods,disabledMods,archives:[{path:moduleFile,priority:23000000},{path:serverFile,priority:31000000}],nwsync:[{hash:manifestHash,cacheDirectory:cache}]},resources,textures,roots,names2017:resolver.resourceNames(2017).sort()});
}
const fixture={version:1,scope:'Authored local content and offline resolver oracle; native runtime must discover/read content itself',root:folder,variants,deletePath:path.join(profile,'override/empty.wav')};
const file=path.join(folder,'fixture.json');await write(file,JSON.stringify(fixture,null,2));console.log(file);
