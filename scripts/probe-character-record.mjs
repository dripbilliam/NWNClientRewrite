import fs from 'node:fs/promises';
import path from 'node:path';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {parseTalkTable} from '../src/talk_table.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {parseModel} from '../src/model_parser.js';
const [install,output]=process.argv.slice(2),resources=installedNetworkResources({install,reuseInstalledNWSync:false}),resolver=await resources.openModule(null,[]),tlk=parseTalkTable(await fs.readFile(path.join(install,'lang/en/data/dialog.tlk')));
const refs=[...new Set((await fs.readFile('backups/animations/character-record-format-native-v2.txt','utf8')).matchAll(/FetchInternal\(pCVar4,(0x[\da-f]+)/g).map(m=>Number(m[1])))];
const report={scope:'Derived UI resource metadata and label references; original assets stay external',strings:Object.fromEntries(refs.map(r=>[r,tlk.get(r)])),models:{}};
for(const name of ['pnl_chrsht','ctl_chrtab_char','ctl_chrtab_skils','ctl_chrtab_feats','ctl_btn_x','ctl_str','ctl_dex','ctl_con','ctl_int','ctl_wis','ctl_cha'])try{const model=parseModel(await resolver.getResource(name,2002));report.models[name]={materials:model.materialNames,animations:model.animations.map(a=>a.name)};}catch(e){report.models[name]={error:e.message};}
report.textureMetadata={};for(const name of ['gui_char_icons','gui_chrsht_2122','gui_chrsht_str','gui_chrsht_tabs']){try{const b=new Uint8Array(await resolver.getResource(name,3)),v=new DataView(b.buffer,b.byteOffset,b.byteLength);report.textureMetadata[name]={width:v.getUint16(12,true),height:v.getUint16(14,true)};}catch(e){report.textureMetadata[name]={missing:true};}try{report.textureMetadata[name].txi=decodeResourceText(await resolver.getResource(name,2022));}catch{}}report.textureNames=resolver.resourceNames(3).filter(n=>/strength|dexterity|constitution|intelligence|wisdom|charisma|ability|gui_char|gui_chrsht|^ia_|^ir_skill/i.test(n));report.iconNames=resolver.resourceNames(2002).filter(n=>/str|dex|con|int|wis|cha|armor|^ctl_.*ac/i.test(n)).filter(n=>n.startsWith('ctl')).slice(0,120);
await fs.writeFile(output,JSON.stringify(report,null,2));resources.close();console.log(JSON.stringify(report));
