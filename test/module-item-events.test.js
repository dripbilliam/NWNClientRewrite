import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeModuleItemHistory,receiveModuleItemEvent,moduleItemHistory} from '../src/module_item_events.js';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
test('equipped/unequipped module histories and event scripts match48 full native observations',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-module-equipment-event-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,48);
  const names=['nativeEquippedItem368','nativeEquippedBy36c','nativeUnequippedItem370','nativeUnequippedBy374','nativeEquippedSlot378'];
  for(const {case:c,result} of capture.observations){
    const module={id:11},scripts=[],eventCalls=[];names.forEach((name,i)=>module[name]=100+i);
    await receiveModuleItemEvent(module,21,{type:c.type,objectIds:c.objects,integers:[c.quantity]},{runEventScript:(m,index)=>{
      eventCalls.push(index);if(c.names&(index===15?1:2))scripts.push({name:index===15?'equip':'unequip',objectId:m.id,context:3000+index,valid:1});}});
    assert.deepEqual({history:Object.fromEntries(names.map(name=>[name,module[name]])),scripts,eventCalls},result,JSON.stringify(c));
  }
});

test('module item histories, script contexts and getters match288 complete native handler observations',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-module-item-event-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.observations.length,288);
  for(const {case:c,result:expected} of oracle.observations){
    const module={id:11,nativeScriptObjectType34:c.scriptType},names=['nativeAcquiredItem34c','nativeAcquiredFrom350','nativeAcquiredBy354','nativeLostItem358','nativeLostBy35c','nativeAcquiredQuantity360','nativeLostQuantity364'];
    names.forEach((name,index)=>module[name]=100+index);const scripts=[],eventCalls=[];
    const scriptName=index=>index===7?c.names&1?'acq':'':c.names&2?'lost':'';
    await receiveModuleItemEvent(module,c.caller,{type:c.type,objectIds:c.objects,integers:[c.quantity]},{scriptName:(_m,index)=>scriptName(index),
      runScript:(m,name,context)=>scripts.push({name,objectId:m.id,context,valid:1}),
      runEventScript:(m,index)=>{eventCalls.push(index);const name=scriptName(index);if(name)scripts.push({name,objectId:m.id,context:(m.nativeScriptObjectType34&255)*1000+index,valid:1});}});
    const getters={};for(const present of [false,true])for(const ordinal of [282,283,292,293,579,707,0])getters[`${Number(present)}:${ordinal}`]=moduleItemHistory(present?module:null,ordinal);
    assert.deepEqual({history:Object.fromEntries(names.map(name=>[name,module[name]])),scripts,eventCalls,getters},expected,JSON.stringify(c));
  }
});

test('canonical session module events retain separate histories before authored scripts run',async()=>{
  const s=new ModuleSession(null);s.module=s.register('module','module',{});s.ifo={Mod_OnAcquirItem:'got',Mod_OnUnAqreItem:'lost'};
  const initial=s.commands.GetModuleItemAcquired();assert.equal(initial,0x7f000000);assert.equal(s.commands.GetModuleItemAcquiredStackSize(),0);
  const calls=[];s.program=async name=>name;s.vm={run:async(name,id,options)=>calls.push({name,id,options,item:s.commands.GetModuleItemAcquired(),lost:s.commands.GetModuleItemLost()})};
  s.combat.enqueueEvent(10,101,s.module.id,0,{type:19,objectIds:[101,31,22],integers:[-5]});await s.scheduler.pump();
  assert.equal(s.commands.GetModuleItemAcquiredFrom(),31);assert.equal(s.commands.GetModuleItemAcquiredBy(),22);assert.equal(s.commands.GetModuleItemAcquiredStackSize(),-5);
  s.combat.enqueueEvent(10,22,s.module.id,0,{type:20,objectIds:[101],integers:[]});await s.scheduler.pump();
  assert.equal(s.commands.GetModuleItemLostBy(),22);assert.equal(s.module.nativeLostQuantity364,0);
  assert.deepEqual(calls,[{name:'got',id:s.module.id,options:{scriptEventContext:3007},item:101,lost:0x7f000000},{name:'lost',id:s.module.id,options:{scriptEventContext:3008},item:101,lost:101}]);
  s.ifo={};await s.receiveItemModuleEvent(10,{type:19,objectIds:[999],integers:[7]});assert.equal(s.commands.GetModuleItemAcquired(),999);assert.equal(s.commands.GetModuleItemLost(),101);
  initializeModuleItemHistory(s.module);assert.equal(s.commands.GetModuleItemAcquired(),999);
});

test('module dispatch context reaches the executing VM frame as an INT',async()=>{
  const contexts=[],program={name:'context',instructions:new Map([[13,{op:5,pc:13,next:18,command:0,argc:0}],[18,{op:0x20,pc:18,next:20}]])};
  const vm=new NwScriptVm({api:[{name:'Observe',returns:'void',args:[]}],command:()=> (_args,frame)=>contexts.push(frame.scriptEventContext)});
  await vm.run(program,11,{scriptEventContext:3007});await vm.run(program,11);await vm.run(program,11,{scriptEventContext:0x80000001});
  assert.deepEqual(contexts,[3007,-1,-2147483647]);await assert.rejects(vm.run(program,11,{scriptEventContext:null}),/context is unavailable/);
});
