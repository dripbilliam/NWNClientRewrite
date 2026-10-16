import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parseModel} from '../src/model_parser.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),table=parse2da(decodeResourceText(await resolver.getResource('visualeffects',RESOURCE_TYPE.TWO_DA)));
const requested=process.argv.find(v=>v.startsWith('--visuals='))?.slice(10).split(',').map(Number);
const rows=(requested??[153,154,156,177,179,180,3,5,9]).map(id=>({id,row:table.orderedRows[id]})),models=[];
for(const name of new Set(rows.flatMap(({row})=>Object.entries(row).filter(([key,value])=>/imp_|model/i.test(key)&&value!=='****'&&value!=='0').map(([,value])=>value)))){
 try{const model=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));models.push({name,format:model.format,supermodel:model.supermodel,nodes:model.nodes.map(n=>({type:n.type,name:n.name,parent:n.parent,position:n.position,properties:n.properties})),animations:model.animations.map(a=>({name:a.name,length:a.length,tracks:a.tracks.map(t=>({node:t.node,property:t.property,frames:t.frames}))}))});}
 catch(e){models.push({name,error:e.message});}
}
const progfx=parse2da(decodeResourceText(await resolver.getResource('progfx',RESOURCE_TYPE.TWO_DA))),programs=rows.map(({id,row})=>({visualId:id,id:Number(row.ProgFX_Duration),row:progfx.orderedRows[Number(row.ProgFX_Duration)]}));
for(const name of new Set(programs.filter(p=>p.row?.Type==='4').map(p=>p.row.Param7))){const model=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));models.push({name,format:model.format,nodes:model.nodes.map(n=>({type:n.type,name:n.name,parent:n.parent,position:n.position,properties:n.properties,unsupportedFeatures:n.unsupportedFeatures})),animations:model.animations.map(a=>({name:a.name,length:a.length,tracks:a.tracks.map(t=>({node:t.node,property:t.property,frames:t.frames})),unsupported:a.unsupported}))});}
const report={columns:table.columns,rows,models,programColumns:progfx.columns,programs,limits:'Read-only active visual metadata/model structure; no geometry, textures or binary assets copied. Sample resource inspection is not client presentation parity.'};
await fs.writeFile('backups/animations/looping-visual-resources.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
