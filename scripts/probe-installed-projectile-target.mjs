import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {parseGff} from '../src/gff.js';
import {parseAreaModule} from '../src/area.js';
import {parseModel} from '../src/model_parser.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {clientProjectileTargetPrefix,setClientProjectileTarget} from '../src/client_projectile_target.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-projectile-target-v1.json',report={};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),ifo=parseGff(await resolver.getResource('module',RESOURCE_TYPE.IFO)).root,area=await parseAreaModule(ifo.Mod_Entry_Area,resolver);
 const models=new Map(),rows=[];
 for(const [type,objects]of [[9,area.placeables],[10,area.doors]])for(const object of objects){
  const key=`${type}:${object.model}`;if(models.has(key))continue;
  const model=parseModel(await resolver.getResource(object.model,RESOURCE_TYPE.MDL)),target={objectType:type},state={};models.set(key,model);
  setClientProjectileTarget(state,0x80000063,'ignored-custom-part',{object:()=>target,targetPrefix:()=>clientProjectileTargetPrefix(type,object.model)});
  rows.push({type,resource:object.model,internalModelName:model.modelName,impactNode:state.impactNode,found:model.nodes.some(n=>n.name.toLowerCase()===state.impactNode.toLowerCase())});
 }
 report.area=ifo.Mod_Entry_Area;report.rows=rows;
 for(const type of [9,10])assert.ok(rows.some(r=>r.type===type&&r.found),`Installed entry area must include a real type${type} authored impact part`);
 report.validation='PASS';report.limits='Read-only active Prelude entry-area resource/model metadata and native target naming. Some models legitimately omit an impact part and use native pose fallback. No proprietary assets copied; not a rendered door-target spell or native full model loader.';
}catch(error){report.validation='FAIL';report.error=error.stack;process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,area:report.area,models:report.rows?.length,found:report.rows?.filter(r=>r.found).length,error:report.error}));
