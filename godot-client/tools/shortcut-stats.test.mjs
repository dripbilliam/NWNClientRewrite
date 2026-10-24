import test from 'node:test';import assert from 'node:assert/strict';
import {ensureShortcutStats} from './shortcut-stats.mjs';
function fixture(){const actor={},scope={actor,actorId:9,areaId:7,areaGeneration:1},calls=[],record={opened:false,page:0};let owned=true,clock=0;const actions={owned:()=>owned,session:{hudPanel:async request=>calls.push(request)}};return{actor,scope,calls,record,actions,retire:()=>owned=false,options:{now:()=>clock,wait:async()=>{clock+=20;},timeout:60}};}
test('missing skills request real server page 1 and restore a closed character sheet',async()=>{
 const f=fixture();f.options.wait=async()=>{f.actor.inventoryStats={skills:[{index:0,value:4,flag:1}]};};
 assert.equal(await ensureShortcutStats(f.actions,f.scope,()=>f.record,f.options),true);assert.deepEqual(f.calls.map(v=>[v.open,v.page]),[[true,1],[false,-1]]);assert.equal(f.actor.inventoryStats.skills[0].value,4);
});
test('existing server skill records do not create unnecessary sheet subscriptions',async()=>{const f=fixture();f.actor.inventoryStats={skills:[]};assert.equal(await ensureShortcutStats(f.actions,f.scope,()=>f.record,f.options),false);assert.equal(f.calls.length,0);});
test('a sheet opened while metadata is pending keeps its current visible page',async()=>{const f=fixture();f.options.wait=async()=>{f.record.opened=true;f.record.page=2;f.actor.inventoryStats={skills:[]};};await ensureShortcutStats(f.actions,f.scope,()=>f.record,f.options);assert.deepEqual(f.calls.map(v=>[v.open,v.page]),[[true,1],[true,2]]);});
test('timeouts restore the subscription without fabricating data and retired worlds cannot close new actor panels',async()=>{
 const f=fixture();await assert.rejects(ensureShortcutStats(f.actions,f.scope,()=>f.record,f.options),/not supplied/);assert.equal(f.actor.inventoryStats,undefined);assert.equal(f.calls.at(-1).open,false);
 const old=fixture();old.options.wait=async()=>old.retire();assert.equal(await ensureShortcutStats(old.actions,old.scope,()=>old.record,old.options),false);assert.equal(old.calls.length,1);
});
