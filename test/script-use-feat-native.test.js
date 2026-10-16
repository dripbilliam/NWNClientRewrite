import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptUseFeat} from '../src/script_use_feat.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {RuntimeDiagnostics} from '../src/runtime_diagnostics.js';
import {ModuleSession} from '../src/module_session.js';

test('ActionUseFeat matches full original auxiliary, actor/target, area and position dispatch',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-use-feat-observations.json',import.meta.url)));
 for(const {case:c,result,calls,cleanup}of oracle.rows){
  assert.equal(cleanup.length,2,JSON.stringify(c));
  if(result===-639){assert.deepEqual(calls,[]);continue;}
  const actual=[],actor={id:99},target={id:100},area={id:7},args=[c.featId??257,c.targetId??100];
  if(c.argc>2)args.push(c.auxiliary??20,c.location?{areaId:8,position:[4.5,6.25,-8.75]}:null);
  const p={spell:id=>{actual.push(['spell',id>>>0]);return c.missingSpell?null:{featId:(c.spellFeat??1009)<<16};},
   object:id=>{actual.push(['object',id]);return id===99?c.selfExists===false?null:actor:c.targetExists===false?null:target;},
   asCreature:()=>{actual.push(['asCreature']);return c.creature===false?null:actor;},asObject:()=>{actual.push(['asObject']);return c.worldObject===false?null:actor;},
   area:()=>{actual.push(['area']);return c.area===false?null:area;},areaById:id=>{actual.push(['areaById',id]);return c.locationArea===false?null:area;},
   position:()=>[1.25,-2.5,30.75],use:(_o,...a)=>{actual.push(['use',...a]);return c.useResult??1;}};
  assert.equal(await scriptUseFeat(args,99,p),result,JSON.stringify(c));assert.deepEqual(actual,calls,JSON.stringify(c));
 }
});

const spec={name:'ActionUseFeat',returns:'void',args:[{type:'int'},{type:'object'},{type:'int',optional:true},{type:'location',optional:true}]};
test('typed VM consumes two or four ActionUseFeat arguments and preserves void return and canonical self',async()=>{
 for(const args of [[305,100],[305,100,1008,null],[257,100,22,{areaId:8,position:[1,2,3]}]]){
  const s=new ModuleSession(null),seen=[];s.feats.script=(value,frame)=>{seen.push({args:value,self:frame.self});return 0;};
  const vm=new NwScriptVm({api:{287:spec},command:name=>s.commands[name]}),frame={stack:[],self:99,program:{name:'owned-feat-fixture'}};
  for(let i=args.length-1;i>=0;i--)vm.push(frame,spec.args[i].type,args[i]);
  await vm.step(frame,{op:5,command:287,argc:args.length,pc:13});assert.deepEqual(frame.stack,[]);assert.deepEqual(seen,[{args,self:99}]);
 }
});
test('missing fourth location and typed mismatches fail with engine context instead of executing a feat',async()=>{
 const diagnostics=new RuntimeDiagnostics(),vm=new NwScriptVm({api:{287:spec},command:()=>args=>scriptUseFeat(args,99,{}) ,diagnostics});
 const program={name:'owned-feat-malformed',instructions:new Map([[13,{op:5,command:287,argc:3,pc:13,next:14}],[14,{op:0x20,pc:14,next:15}]])};
 await assert.rejects(vm.run(program,99,{situation:{pc:13,bp:0,stack:[{type:3,value:1008},{type:6,value:100},{type:3,value:305}]}}),/fourth VM location/);
 assert.equal(diagnostics.records.at(-1).context.engineCall,'ActionUseFeat');assert.equal(diagnostics.records.at(-1).context.argumentCount,3);
 assert.equal(diagnostics.records.at(-1).code,'engine.failure');
 await assert.rejects(vm.run(program,99,{situation:{pc:13,bp:0,stack:[{type:3,value:1008},{type:3,value:100},{type:3,value:305}]}}),/Stack type mismatch/);
});
