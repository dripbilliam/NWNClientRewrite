import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const ncs=rows=>{const body=Buffer.from(rows),b=Buffer.alloc(13+body.length);b.write('NCS V1.0',0);b[8]=0x42;b.writeUInt32BE(b.length,9);body.copy(b,13);return b;};
const missing=(name,type=2010)=>Object.assign(new Error(`Missing ${name}`),{code:'RESOURCE_NOT_FOUND',resRef:name,resourceType:type});
function fixture(load){
  const errors=[],s=new ModuleSession({getResource:load},{runStartupScripts:false,runNativeAI:false,onDiagnostic:m=>errors.push(m)}),owner=s.register('area','area',{resRef:'area'});
  s.vm=new NwScriptVm({api:[],command:name=>s.commands[name],diagnosticContext:id=>s.diagnosticContext(id)});return {s,owner,errors};
}
test('absent NCS returns native failure without VM execution or session error and records each attempt',async()=>{
  let reads=0;const {s,owner,errors}=fixture(async name=>{reads++;throw missing(name);}),start=runtimeDiagnostics.records.length,budget={remaining:99};
  for(let n=0;n<2;n++)assert.deepEqual(await s.runScript('Unknown',owner.id,{budget,depth:2,scriptEventContext:4001}),{executed:false,nativeResult:0,loadError:-634,stack:[]});
  assert.equal(reads,2);assert.equal(s.programs.size,0);assert.equal(budget.remaining,99);assert.deepEqual(errors,[]);
  const records=runtimeDiagnostics.records.slice(start).filter(r=>r.code==='script.resource-unavailable');assert.equal(records.length,2);
  assert.ok(records.every(r=>r.context.objectId===owner.id&&r.context.script==='unknown'&&r.context.nativeLoadError===-634&&r.context.scriptEventContext===4001));
  assert.ok(records.every(r=>r.severity==='warning'));
});
test('failed loads are retried and later available NCS executes with the current canonical owner',async()=>{
  let available=false,reads=0;const {s,owner}=fixture(async name=>{reads++;if(!available)throw missing(name);return ncs([4,3,0,0,0,7,32,0]);});
  assert.equal((await s.runScript('late',owner.id)).executed,false);available=true;
  const result=await s.runScript('late',owner.id);assert.equal(result.executed,true);assert.equal(result.nativeResult,1);assert.deepEqual(result.stack,[{type:3,value:7}]);
  await s.runScript('LATE',owner.id);assert.equal(reads,2,'Successful compiled scripts remain cached');
});
test('ExecuteScript keeps the parent frame running after the child is absent',async()=>{
  const {s,owner}=fixture(async name=>{throw missing(name);});
  const api=[{name:'ExecuteScript',returns:'void',args:[{type:'string',name:'name'},{type:'object',name:'target'}]}];s.vm.api=api;
  const instructions=new Map([[13,{pc:13,op:4,type:6,value:owner.id,next:19}],[19,{pc:19,op:4,type:5,value:'absent_child',next:25}],[25,{pc:25,op:5,command:0,argc:2,next:30}],[30,{pc:30,op:4,type:3,value:42,next:36}],[36,{pc:36,op:32,next:38}]]);
  const result=await s.vm.run({name:'parent',instructions},owner.id);assert.deepEqual(result.stack,[{type:3,value:42}]);
});
test('missing DLG condition rejects the branch; missing action continues and leaves the dialogue usable',async()=>{
  const {s,owner,errors}=fixture(async name=>{throw missing(name);}),player=s.register('player','pc',{areaId:owner.id,position:[0,0,0],authored:{},stats:{},isPC:true});s.player=player;
  const npc=s.register('creature','npc',{areaId:owner.id,position:[0,0,0],authored:{},scripts:{}});
  s.conversation.resources.set('dlg',{StartingList:[{Index:0,Active:'missing_condition'},{Index:1}],EntryList:[{Text:'Hidden',RepliesList:[]},{Text:'Visible',Script:'missing_action',RepliesList:[]}],ReplyList:[]});
  assert.equal(await s.conversation.start(npc,player,'dlg'),true);assert.equal(s.conversation.state.entryIndex,1);assert.equal(s.conversation.state.error,null);assert.deepEqual(errors,[]);
});
test('missing area exit permits transfer; old/new membership and canonical ID remain intact',async()=>{
  const {s,owner,errors}=fixture(async name=>{throw missing(name);}),next=s.register('area','next',{resRef:'next',scripts:{},objects:[]}),player=s.register('player','pc',{areaId:owner.id,position:[0,0,0],stats:{},authored:{}});
  owner.scripts={exit:'missing_exit'};owner.objects=[player.id];s.player=player;s.currentArea=owner;s.started=true;s.areas.set('next',next);
  s.refreshCombat=()=>{};s.leaveTriggers=()=>{};s.updateTriggers=()=>{};
  await s.enterArea('next',[1,0,2]);assert.equal(s.player,player);assert.equal(s.currentArea,next);assert.equal(player.areaId,next.id);assert.ok(next.objects.includes(player.id));assert.ok(!owner.objects.includes(player.id));assert.deepEqual(errors,[]);
});
test('corrupt bytecode, read failures and runtime/engine failures remain real exceptions',async()=>{
  for(const error of [Object.assign(new Error('Disk read failed'),{code:'EIO'}),missing('other',2053)]){
    const {s,owner}=fixture(async()=>{throw error;});await assert.rejects(s.runScript('bad',owner.id),e=>e===error);
  }
  const {s,owner}=fixture(async()=>new Uint8Array(16));await assert.rejects(s.runScript('bad',owner.id),/invalid NCS header/);assert.equal(s.programs.size,0);
  const runtime=fixture(async()=>ncs([5,0,0,0,0,32,0]));runtime.s.vm.api=[{name:'MissingEngine',returns:'void',args:[]}];
  await assert.rejects(runtime.s.runScript('bad_engine',runtime.owner.id),/not implemented/);
});
