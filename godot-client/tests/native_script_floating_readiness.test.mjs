import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
const require=createRequire(import.meta.url),{ScriptFloatingCapture}=require('../tools/native-script-floating-capture.cjs');
const host=fs.readFileSync(new URL('../tools/native-session-host.cjs',import.meta.url),'utf8'),start=host.indexOf('// Dedicated received-script validation has no movement/picking claim.'),end=host.indexOf('   if(localCheck&&recordLoading){',start);
if(start<0||end<start)throw Error('Exact dedicated Host readiness boundary changed');
const fragment=host.slice(start,end),run=new Function('context','with(context){'+fragment+'\nreturn "generic-movement-chain";}');
function fixture(){const actor={id:42,objectType:5,areaId:7,replicationRemoved:false},lifetimes=new WeakMap([[actor,1]]),known=new WeakMap([[actor,2]]),session={phase:'playing',closed:false,peer:{closed:false},areaGeneration:2,world:{areaId:7,localObjectId:42,registry:new Map([[42,actor]]),entityDisclosures:{token:value=>known.get(value)}}},harness=new ScriptFloatingCapture(decodeServerGameMessage,{identity:value=>lifetimes.get(value)}),sent=[],failures=[],state={ready:true,admission_ready:true,object_visuals_complete:true,pending_batches:0,entities:1,hidden:0,desired:1,generation:2,area_id:7,controlled_id:42};return {actor,known,session,harness,sent,failures,context:{scriptFloatingCheck:true,localCycleEnding:false,actionsProbeSent:false,catalogReady:true,rawPending:null,session,message:{kind:'observed',connection:3,generation:2,areaId:7,nativeProcessId:123,state},native:{pid:123},lobby:{connection:3},scriptFloatingHarness:harness,report:{},send:value=>sent.push(value),finish:reason=>failures.push(reason)}};}
test('bounded actual Host readiness dispatch runs once before unrelated movement; default handler falls through unchanged',()=>{
 const h=fixture();assert.equal(run(h.context),undefined);assert.deepEqual(h.sent,[{kind:'probe-script-floating'}]);assert.equal(h.context.actionsProbeSent,true);assert.equal(h.harness.owner,null);assert.equal(h.context.report.scriptFloatingReady.movementAcceptance,false);run(h.context);assert.equal(h.sent.length,1);
 const normal=fixture();normal.context.scriptFloatingCheck=false;assert.equal(run(normal.context),'generic-movement-chain');assert.deepEqual(normal.sent,[]);assert.equal(normal.context.actionsProbeSent,false);
 const before=fs.readFileSync(new URL('../.cache/script-floating-authority/harness-before-readiness-v3/godot-client/tools/native-session-host.cjs',import.meta.url),'utf8');const line=text=>text.split(/\r?\n/).find(value=>value.includes('if(localCheck&&!recordLoading')&&value.includes('localWalkDistance>0.2'));
 assert.equal(line(host).replace('&&!scriptFloatingCheck',''),line(before));assert.ok(host.includes("...(localCheck&&!scriptFloatingCheck?['--settings-check=true']:[])"));
});
test('actual readiness/scope guards reject stale or incomplete native publication and remain detached',()=>{
 for(const change of [h=>h.context.catalogReady=false,h=>h.context.rawPending={serial:1},h=>h.session.phase='resources',h=>h.context.message.generation++,h=>h.context.message.areaId++,h=>h.context.message.nativeProcessId++,h=>h.context.message.state.ready=false,h=>h.context.message.state.object_visuals_complete=false,h=>h.context.message.state.pending_batches=1,h=>h.context.message.state.desired=2,h=>h.context.message.state.controlled_id=99]){const h=fixture();change(h);run(h.context);assert.deepEqual(h.sent,[]);assert.equal(h.harness.owner,null);}
 const h=fixture();run(h.context);h.context.report.scriptFloatingReady.source.knownLifetime=999;assert.equal(h.harness.readiness.source.knownLifetime,2);h.known.set(h.actor,3);assert.throws(()=>h.harness.arm(h.session,3),/retired/);
});
test('dedicated native finish requires readiness/ack/worker/source identity and explicitly makes no movement or pixel acceptance',()=>{
 const h=fixture();run(h.context);h.harness.arm(h.session,3);const value={success:true,playable:true,object_visuals_complete:true,environment_accepted:true,workers_remaining:0,protocol_finish_ack:true,gameplay_success:false,world:{ready:true,generation:2,area_id:7,controlled_id:42}};
 const result=h.harness.nativeExit(value,true);assert.equal(result.success,true);assert.equal(result.movementAcceptance,false);assert.equal(result.pixelAcceptance,false);assert.equal(result.nativeGameplaySuccess,false);
 for(const patch of [{success:false},{playable:false},{object_visuals_complete:false},{environment_accepted:false},{workers_remaining:1},{protocol_finish_ack:false},{gameplay_success:true},{world:{...value.world,controlled_id:99}}])assert.equal(h.harness.nativeExit({...value,...patch},true).success,false);assert.equal(h.harness.nativeExit(value,false).success,false);
});
