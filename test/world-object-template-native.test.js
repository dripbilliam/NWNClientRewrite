import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadWorldObjectTemplate} from '../src/world_object_template.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-world-object-template-observations.json',import.meta.url)));

test('world blueprint wrappers match original ordering, resource types, ignored lower results and failure cleanup',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],o={template:'previous_template'},resource={loaded:c.loaded},root={id:123};
  const result=await loadWorldObjectTemplate(c.kind,o,c.reference,c.tag,{
   resource:(type,signature,name)=>{calls.push(['resource',type,signature,name]);return resource;},
   root:r=>{assert.equal(r,resource);calls.push(['root']);return root;},
   release:(r,flag)=>{assert.equal(r,resource);calls.push(['release',flag]);},
   setTemplate:(obj,name)=>{assert.equal(obj,o);calls.push(['setTemplate',name]);obj.template=name;},
   loadData:(kind,obj,r,s,...args)=>{assert.equal(obj,o);assert.equal(r,resource);assert.equal(s,root);calls.push(['load',kind,o.template,kind==='waypoint'?args[0]:args[1],kind==='waypoint'?null:args[0]]);o.template='authored_template';return c.lower;},
   loadVariables:(obj,r,s)=>{assert.equal(obj,o);assert.equal(r,resource);assert.equal(s,root);calls.push(['variables',o.template]);return 0;},
   warning:message=>calls.push(['warning',message]),
  });
  const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.equal(o.template,row.template,label);assert.deepEqual(calls,row.calls,label);
 }
 assert.equal(native.rows.length,720);
});
