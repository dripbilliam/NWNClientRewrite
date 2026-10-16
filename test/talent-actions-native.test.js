import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {addTalentOnObject,addTalentAtLocation,scriptUseTalent,talentAccess} from '../src/talent_actions.js';
import {scriptTalent} from '../src/talent.js';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';

test('complete talent wrappers and script dispatch match native calls, widths, gates and conditional pops',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-talent-action-observations.json',import.meta.url)));
 for(const {case:c,mode,result,calls,pops,pushed}of oracle.rows){
  const value={...scriptTalent(c.type??0,c.id??100),classIndex:c.classIndex??254,itemId:c.itemId??0x7f000000,itemPropertyIndex:c.propertyIndex??-1,casterLevel:c.casterLevel??7,metamagic:c.metamagic??0};
  if(mode==='access'){if(result===-639)continue;assert.equal(talentAccess(c.ordinal,value),pushed,JSON.stringify(c));continue;}
  const actual=[],actualPops=[],actor={id:99,nativeFieldEc:c.commandable??1},target={id:100},area={id:c.areaId??7},point=[4.5,-6.25,8.75];
  const p={creature:id=>{actual.push(['creature',id]);return id===99?c.selfExists===false?null:actor:c.targetCreature===false?null:target;},
   position:()=>[1.25,2.5,3.75],area:()=>{actual.push(['area']);return c.area===false?null:area;},random:()=>{actual.push(['random']);return c.random??1;},
   clearActions:()=>actual.push(['clearActions']),useFeat:(_o,...a)=>{actual.push(['feat',...a]);return c.lowerResult??1;},
   useSkill:(_o,...a)=>{actual.push(['skill',...a]);return c.lowerResult??1;},useItem:(_o,...a)=>{actual.push(['item',...a]);return c.lowerResult??1;},
   addCast:(_o,r)=>{actual.push(['cast',r]);return c.lowerResult??1;}};
  const onObject=(...a)=>addTalentOnObject(...a,p),atLocation=(...a)=>addTalentAtLocation(...a,p);
  let actualResult;
  if(mode.startsWith('wrapper'))actualResult=await (mode.endsWith('object')?onObject:atLocation)(actor,value.type,value.id,mode.endsWith('object')?c.targetId??100:point,value.classIndex,value.itemId,value.itemPropertyIndex,value.casterLevel,value.metamagic);
  else{
   const pop=(kind,v)=>{actualPops.push(kind);if(actualPops.length===c.failPop)throw new Error('native pop failure');return v;};
   const invoke=()=>scriptUseTalent(mode.endsWith('object')?309:310,99,{talent:()=>pop('talent',value),object:()=>pop('object',c.targetId??100),location:()=>pop('location',{position:point,areaId:12345})},{creature:p.creature,onObject,atLocation});
   if(result===-639){await assert.rejects(invoke(),/native pop failure/);actualResult=-639;}else actualResult=await invoke();
  }
  assert.equal(actualResult,result,JSON.stringify({mode,c}));assert.deepEqual(actual,calls,JSON.stringify({mode,c}));assert.deepEqual(actualPops,pops,JSON.stringify({mode,c}));
 }
});

const spec=(name,target)=>({name,returns:'void',args:[{type:'talent'},{type:target}]});
test('typed talent commands preserve a skipped target cell even when its type is wrong',async()=>{
 for(const ordinal of [309,310])for(const type of [-2147483648,-2,-1,0])for(const exists of [false,true]){
  const s=new ModuleSession(null),name=ordinal===309?'ActionUseTalentOnObject':'ActionUseTalentAtLocation',calls=[];
  s.talents.actionProviders=()=>({creature:id=>{calls.push(id);return exists?{id,nativeFieldEc:0}:null;}});
  const vm=new NwScriptVm({api:{[ordinal]:spec(name,ordinal===309?'object':'location')},command:n=>s.commands[n]}),f={stack:[{type:3,value:42},{type:0x13,value:scriptTalent(type,10)}],self:99,program:{name:'owned-talent-pop-fixture'}};
  if(type>=0&&exists)await assert.rejects(vm.step(f,{op:5,command:ordinal,argc:2,pc:13}),/Stack type mismatch/);
  else{await vm.step(f,{op:5,command:ordinal,argc:2,pc:13});assert.deepEqual(f.stack,[{type:3,value:42}]);}
  assert.deepEqual(calls,type<0?[]:[99]);
 }
});
test('active API talent accessor names preserve signed type and ID without validity normalization',async()=>{
 const s=new ModuleSession(null),vm=new NwScriptVm({api:{362:{name:'GetTypeFromTalent',returns:'int',args:[{type:'talent'}]},363:{name:'GetIdFromTalent',returns:'int',args:[{type:'talent'}]}},command:n=>s.commands[n]});
 for(const [ordinal,expected]of [[362,-2],[363,-2147483648]]){const f={stack:[{type:0x13,value:scriptTalent(-2,-2147483648)}]};await vm.step(f,{op:5,command:ordinal,argc:1,pc:13});assert.deepEqual(f.stack,[{type:3,value:expected}]);}
});
