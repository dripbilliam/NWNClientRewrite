// Read-only installed resource metadata; do not copy proprietary image/models.
import fs from 'node:fs/promises';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {parse2da} from '../src/area.js';
import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';
import {parseModel} from '../src/model_parser.js';
const resolver=await openServerResourceContext({install:'../FullDecomp/NwnRootInstall'}),report={resources:[],tables:{}};
for(const[typeName,type]of Object.entries(RESOURCE_TYPE)){const names=resolver.resourceNames(type).filter(n=>/cursor|target|mouse/i.test(n));if(names.length)report.resources.push({typeName,type,names});}
for(const name of resolver.resourceNames(2017).filter(n=>/cursor|target/i.test(n))){const table=parse2da(decodeResourceText(await resolver.getResource(name,2017)));report.tables[name]={columns:table.columns,rows:[...table.rows]};}
report.cursorModels=[];for(const name of ['gui_mouse','gui_mouse_center',...report.tables.cursors.rows.map(([,r])=>r.ResRef).filter(n=>n!=='****')]){const m=await resolver.getResource(name,2002).then(parseModel).catch(()=>null);report.cursorModels.push({name,texture:resolver.hasResource(name,3),...(m?{materials:m.materialNames,nodes:m.nodes.map(n=>({name:n.name,type:n.type,bitmap:n.bitmap,position:n.position,scale:n.scale,bounds:n.verts?.length?{min:[0,1,2].map(i=>Math.min(...n.verts.map(v=>v[i]))),max:[0,1,2].map(i=>Math.max(...n.verts.map(v=>v[i])))}:null})),clips:m.animations.map(a=>a.name)}:{})});}
const spells=parse2da(decodeResourceText(await resolver.getResource('spells',2017)));report.spellColumns=spells.columns.filter(n=>/target|range/i.test(n));report.spells=[...spells.rows].filter(([,r])=>/fireball|cone|lightning|entangle/i.test(r.Label??'')).slice(0,14).map(([id,r])=>({id,label:r.Label,values:Object.fromEntries(report.spellColumns.map(k=>[k,r[k]]))}));
const api=decodeResourceText(await resolver.getResource('nwscript',2009));report.constants=[...api.matchAll(/(?:const\s+)?int\s+((?:SPELL_TARGETING_|MOUSECURSOR_)[\w]+)\s*=\s*([^;]+);/g)].map(m=>({name:m[1],value:m[2]}));
await fs.writeFile('backups/animations/target-preview-cursor-resources-v1.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
