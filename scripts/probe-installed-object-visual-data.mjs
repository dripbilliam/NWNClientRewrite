import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {parseGff} from '../src/gff.js';
import {typedGff,writeGff,gffField as F,gffRecord as R} from '../src/gff_writer.js';
import {loadObjectShaderParams,loadObjectReplacements,loadObjectMiscVisuals,objectVisualDataGffProviders} from '../src/object_visual_data.js';
import {importedAnimationOverrides,nativeAnimationName} from '../src/native_animation.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-object-visual-data-v1.json',report={samples:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),p=objectVisualDataGffProviders();let creature=null;
 for(const[type,signature]of[[2027,'UTC '],[2044,'UTP '],[2051,'UTM '],[2058,'UTW ']]){
  const refs=[...resolver.key.resources.values()].filter(r=>r.resourceType===type).slice(0,3);assert.ok(refs.length,`Installed ${signature} templates are required`);
  for(const resource of refs){
   const data=parseGff(await resolver.getResource(resource.resref,type),signature).root,o={};
   await loadObjectShaderParams(o,data,p);await loadObjectReplacements('texture',o,data,p);await loadObjectReplacements('animation',o,data,p);await loadObjectMiscVisuals(o,data,p);
   if(type===2027&&!creature)creature=data;
   report.samples.push({reference:resource.resref,type,visualRootLabels:Object.keys(data).filter(key=>['Material','TextureReplace','AnimationReplace','MiscVisuals'].includes(key)),pools:Object.fromEntries(Object.entries(o.nativeVisualPools??{}).map(([key,value])=>[key,{count:value.records.length,capacity:value.capacity}])),miscFields:Object.keys(o.nativeMiscVisualFields??{}).length});
  }
 }
 // Extend a real installed UTC only in memory. No source resource or actor is
 // changed, and no original resource bytes are included in the report.
 const fields=typedGff(creature).fields;fields.AnimationReplace=F(14,R({AnimationReplace:F(15,[
  R({OldAnimation:F(11,'PAUSE1'),NewAnimation:F(11,'custom_first')}),R({OldAnimation:F(11,'pause1'),NewAnimation:F(11,'custom_second')}),
 ])}));fields.Material=F(14,R({ShaderParams:F(15,[R({Type:F(0,1),Int:F(5,-17),Material:F(10,'mesh'),Param:F(10,'parameter')})])}));
 const data=parseGff(writeGff('UTC ',{type:0xffffffff,fields}),'UTC ').root,o={id:99};
 await loadObjectShaderParams(o,data,p);await loadObjectReplacements('animation',o,data,p);
 assert.equal(o.nativeVisualPools[0x2b8].records.length,1);assert.equal(new DataView(o.nativeVisualPools[0x2b8].records[0].buffer).getInt32(88,true),-17);
 assert.equal(o.nativeVisualPools[0x2d8].records.length,2);const overrides=importedAnimationOverrides(data);
 assert.equal(nativeAnimationName(0,{fieldDE:1,fieldDD:3,fieldE0:0},overrides),'custom_first');assert.equal(o.id,99);
 const before=o.nativeVisualPools[0x2d8];await loadObjectReplacements('animation',o,parseGff(writeGff('UTC ',R({}))).root,p);assert.equal(o.nativeVisualPools[0x2d8],before);
 await loadObjectReplacements('animation',o,parseGff(writeGff('UTC ',R({AnimationReplace:F(14,R({AnimationReplace:F(15,[])}))}))).root,p);
 assert.equal(o.nativeVisualPools[0x2d8].records.length,0);assert.equal(o.nativeVisualPools[0x2d8].capacity,0);
 report.fixture={inMemoryOnly:true,firstMatch:'custom_first',shaderInt:-17,missingPreserves:true,emptyClears:true};report.validation='PASS';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error);process.exitCode=1;}
