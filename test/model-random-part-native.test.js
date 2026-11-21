import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {nativeRandomModelPart,randomSceneModelPart} from '../src/model_random_part.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {parseModel} from '../src/model_parser.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
test('84 original Gob/Part executions retain native cached area, strict weighted boundary, traversal and CRT draw count',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-random-part-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,84);
 for(const row of fixture.cases){const c=row.case,parts=c.areas.map((area,i)=>({name:'part'+i,area:Math.fround(area??0),children:[]}));c.parents.forEach((parent,i)=>{if(parent>=0)parts[parent].children.push(parts[i]);});let draws=0;const model={partArea:c.cached},name=nativeRandomModelPart(model,{root:()=>parts[0],children:p=>p.children,area:p=>p.area,name:p=>p.name,random:()=>{draws++;return c.draw;}});assert.deepEqual({name,area:model.partArea,draws},{name:row.name,area:row.area,draws:row.draws},JSON.stringify(c));}
 for(const row of fixture.copies)assert.equal(row.result,Math.fround(row.value));
});
test('installed binary chest retains original stored areas through the real physical hierarchy',async t=>{
 const install=new URL('../../FullDecomp/NwnRootInstall',import.meta.url);if(!fs.existsSync(install)){t.skip('Installed native resources unavailable');return;}
 const resolver=await openLocalModule(fileURLToPath(install),fileURLToPath(new URL('../../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm',import.meta.url)));
 const model=parseModel(await resolver.getResource('plc_a08',RESOURCE_TYPE.MDL)),hierarchy=createModelHierarchy(model),handle={root:hierarchy.root,model};assert.ok(model.nodes.some(n=>n.nativeTriMeshArea>0));
 const name=randomSceneModelPart(handle,{next:()=>1});assert.ok(model.nodes.some(n=>n.name===name));assert.ok(handle.partArea>0);
});
