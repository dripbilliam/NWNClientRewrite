// Read-only active visual/program/model capability inventory. Store metadata
// only: no proprietary geometry, textures, shaders or binary resource copies.
import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parseModel} from '../src/model_parser.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',module=process.argv[3]??`${root}/data/nwm/Prelude.nwm`,resolver=await openLocalModule(root,module);
const tables=await Promise.all(['visualeffects','progfx'].map(async name=>parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA))))),[visuals,programs]=tables;
const references=new Map(),empty=v=>v===undefined||v===''||v==='****'||v==='0',durationTypes={},rows=[];
for(const [id,row]of visuals.orderedRows.entries()){
 const modelRefs=Object.entries(row).filter(([k,v])=>/^(imp_|ces_).*_node$/i.test(k)&&!empty(v)).map(([column,name])=>({column,name}));
 for(const {name}of modelRefs){if(!references.has(name.toLowerCase()))references.set(name.toLowerCase(),[]);references.get(name.toLowerCase()).push(id);}
 const duration=empty(row.ProgFX_Duration)?null:Number(row.ProgFX_Duration),program=duration===null?null:programs.orderedRows[duration];
 if(row.Type_FD==='D')durationTypes[program?.Type??'no program']=(durationTypes[program?.Type??'no program']??0)+1;
 if(program?.Type==='4'&&!empty(program.Param7)&&!references.has(program.Param7.toLowerCase()))references.set(program.Param7.toLowerCase(),[id]);
 rows.push({id,label:row.Label,type:row.Type_FD,models:modelRefs,durationProgram:duration,programType:program?.Type??null});
}
const models=[];
for(const [name,visualIds]of references){
 try{const model=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL)),types={},unsupported=new Set();
  for(const node of model.nodes){types[node.type]=(types[node.type]??0)+1;for(const feature of node.unsupportedFeatures??[])unsupported.add(feature);}
  models.push({name,visualIds,format:model.format,nodeTypes:types,unsupported:[...unsupported],unsupportedAnimations:model.unsupportedAnimations,animations:model.animations.map(a=>({name:a.name,length:a.length,tracks:a.tracks.length}))});
 }catch(error){models.push({name,visualIds,error:error.message});}
}
const report={module,visualRows:rows.length,durationTypes,modelCount:models.length,failedModels:models.filter(m=>m.error).length,models,rows,limits:'Static metadata capability inventory. Type4 duration model presentation exists for supported creature scope only. Presence/parser success is not live playback, emitter simulation, impact/cessation, sound, beam or campaign acceptance.'};
await fs.writeFile('backups/animations/visual-presentation-active-audit.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({visualRows:report.visualRows,durationTypes,modelCount:report.modelCount,failedModels:report.failedModels,emitterModels:models.filter(m=>m.nodeTypes?.emitter||m.unsupported?.includes('Binary emitter payload')).length}));
