import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {associateCommandRequest} from '../src/network_associate_input.js';
import {networkRadialActions} from '../src/network_action_menu.js';
import {NetworkWorld} from '../src/network_world.js';
import {networkFamiliar} from '../src/network_associates.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';

test('451 original sender/full server associate cases preserve signed commands, raw IDs, ownership and self redirection',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-associate-request-observations.json',import.meta.url)));assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,451);
 for(const {case:c,packet,calls}of f.cases){
  if(c.format===1){const actual=associateCommandRequest(c),native=Buffer.from(packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);}
  const decodedId=c.targetId===0x7f000000?c.targetId:c.targetId&0x7fffffff,redirect=c.command===-19&&decodedId===100,lookupId=redirect?(c.redirectId??777):decodedId;
  const expected=!c.noActor&&!c.blocked&&!c.noTarget&&lookupId===(c.resolvedId??decodedId)&&((c.masterId??100)===100||lookupId===100&&c.command===-13);
  assert.equal(calls.some(v=>v.kind==='receive'),expected,JSON.stringify(c));
  if(expected)assert.deepEqual(calls.find(v=>v.kind==='receive'),{kind:'receive',id:c.resolvedId??decodedId,command:c.command});
  assert.equal(calls.some(v=>v.kind==='associate'),!c.noActor&&!c.blocked&&redirect);
 }
 for(const change of [{targetId:-1},{targetId:2**32},{targetId:1.2},{command:-2147483649},{command:2147483648},{command:NaN}])assert.throws(()=>associateCommandRequest({targetId:0xffffffff,command:-13,...change}));
});

test('replicated ownership selects native owned menus and self familiar unpossession without fabricating relationships',()=>{
 const pc={id:0xffffffff,objectType:5,replicated:{master:0x7f000000,field908:0}},pet={id:0x80000002,objectType:5,replicated:{master:pc.id,field908:3}},before=structuredClone([pc,pet]);
 const root=networkRadialActions(pet,pc),actions=root.entries.find(e=>e.slot===7).children();assert.equal(root.entries.find(e=>e.slot===3).command,-5);assert.equal(root.entries.find(e=>e.slot===4).command,-2);assert.equal(actions.entries.find(e=>e.slot===3).command,-8);assert.equal(actions.entries.find(e=>e.slot===2).action,'associate.possess');
 assert.deepEqual(networkRadialActions(pet,pet).entries.find(e=>e.slot===4),{slot:4,label:'Unpossess Familiar',icon:'IFE_UNPOSSESS',action:'associate.command',system:'associate command dispatch',command:-13});
 assert.equal(networkRadialActions(pc,pc).entries.some(e=>e.command===-13),false);assert.deepEqual([pc,pet],before);
 const stranger={...pc,id:0x80000003};assert.equal(networkRadialActions(pet,stranger).entries.some(e=>e.action==='associate.command'),false);
 for(const [type,command]of [[2,-9],[3,-8],[4,-10],[5,-12]]){const target={...pet,replicated:{master:pc.id,field908:type}},menu=networkRadialActions(target,pc).entries.find(e=>e.slot===7).children();assert.equal(menu.entries.find(e=>e.slot===3).command,command);}
});

test('real vanilla UI summon/possess/unpossess/commands/unsummon cycle preserves canonical proxies and restores the PC book and hotbar',async()=>{
 const r=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v62.json',import.meta.url))),d=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v62-diagnostics.json',import.meta.url)));
 assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,15);assert.ok(r.paintFrames>3000);assert.equal(r.states.at(-1).closed,true);assert.deepEqual(d.filter(e=>e.severity==='error'),[]);
 const controls=[];for(const s of r.samples)if(controls.at(-1)!==s.server.controlledId)controls.push(s.server.controlledId);const familiarId=controls[2];assert.deepEqual(controls,[0x7f000000,0xffffffff,familiarId,0xffffffff]);assert.notEqual(familiarId,0xffffffff);
 const packets=r.quickbarRequests.map(p=>Buffer.from(p.packet,'hex'));assert.deepEqual(packets.map(p=>[p[1],p[2]]),[[6,6],[6,19],[6,27],[6,27],[6,27],[6,27]]);
 for(const [i,command]of [-13,-5,-2,-8].entries())assert.deepEqual(packets[i+2],Buffer.from(associateCommandRequest({targetId:familiarId,command})));
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm')),world=new NetworkWorld(),controlled=[],references=new Map();
 for(const hex of r.wireMessages){const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);
  if(controlled.at(-1)!==world.localObjectId)controlled.push(world.localObjectId);for(const id of [0xffffffff,familiarId]){const object=world.registry.get(id);if(!object)continue;if(references.has(id))assert.equal(object,references.get(id));else references.set(id,object);}
 }
 assert.deepEqual(controlled,controls);assert.equal(world.controls.get(0),0xffffffff);assert.equal(world.localObjectId,0xffffffff);const pc=world.registry.get(0xffffffff);assert.equal(networkFamiliar(world,pc),null);assert.equal(pc.familiarId,0x7f000000);assert.ok(world.registry.get(familiarId)?.replicationRemoved);assert.ok(pc.playerState.spellbooks[0].memorized[0].length);assert.ok(r.samples.at(-1).quickbar.buttons.some(b=>b.type===2));
});
