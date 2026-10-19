import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {quickChatRequest,associateCommandRequest,networkAssociateShortcut,NETWORK_PARTY_COMMANDS,networkPartyCommandMenu,networkAssociateShortcutChoices} from '../src/network_associate_input.js';
import {possessFamiliarRequest} from '../src/network_feat_input.js';
import {quickbarAssignmentRequest} from '../src/network_quickbar.js';
import {networkRadialActions} from '../src/network_action_menu.js';
import {NetworkWorld} from '../src/network_world.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageReader} from '../src/native_message.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';

const fixture=name=>JSON.parse(fs.readFileSync(new URL('../backups/animations/'+name,import.meta.url)));
function equalPacket(actual,hex){const native=Buffer.from(hex,'hex');assert.equal(actual.length,native.length);if(native.length===3){assert.deepEqual(Buffer.from(actual),native);return;}const used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);}

test('640 original quickchat/server relay and general shortcut cases preserve distinct wire paths and native widget truncation',()=>{
 const f=fixture('native-network-party-command-observations.json');assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,640);
 const commands=new Map([[0,-3],[4,-4],[9,-7],[10,-2],[22,-5]]);
 for(const r of f.cases){const c=r.case;
  if(c.kind==='chat'){
   if(c.format===1)equalPacket(quickChatRequest(c),r.packet);
   const response=r.calls.find(v=>v.kind==='response');assert.deepEqual(response,c.noActor?undefined:{kind:'response',id:100,quickChat:c.quickChat});
   const received=r.calls.filter(v=>v.kind==='receive');if(c.noActor||c.noList||c.ids?.length===0||!commands.has(c.quickChat))assert.deepEqual(received,[]);else{assert.equal(received.length,c.mutate?2:3);assert.ok(received.every(v=>v.command===commands.get(c.quickChat)));assert.deepEqual(received.map(v=>v.id),c.mutate?[200,201]:[200,201,200]);}
   continue;
  }
  const actor={companionId:0x800000c8,familiarId:0xffffffff},b={...c},request=c.type===39?networkAssociateShortcut(b,actor):null;
  const active=!c.disabled&&!c.noClient&&(c.type===38||!c.noActor)&&(c.type!==39||request!==null);assert.equal(r.packets.length,Number(active),JSON.stringify(c));
  if(active&&c.format===1)equalPacket(c.type===38?possessFamiliarRequest():c.type===42?quickChatRequest({quickChat:c.intParam&65535}):associateCommandRequest(request),r.packets[0]);
  if(c.type===39){assert.equal(r.calls.find(v=>v.kind==='widget').packed,((c.intParam<<16)|c.associateType)>>>0);if(request)assert.equal(request.command,(c.intParam<<16)>>16);}
 }
 for(const quickChat of [-1,65536,1.1,NaN])assert.throws(()=>quickChatRequest({quickChat}));
});

test('108 original assignment/full-server cases agree on types38/39/42 and separate command/type/ID fields',()=>{
 const f=fixture('native-network-associate-shortcut-request-observations.json');assert.equal(f.cases.length,108);
 for(const r of f.cases){const c=r.case,b={...c};if(c.format===1)equalPacket(quickbarAssignmentRequest({index:c.index,button:b}),r.packet);assert.equal(r.result.type,c.type);if(c.type!==38)assert.equal(r.result.intParam,c.intParam);if(c.type===39){assert.equal(r.result.associateType,c.associateType);assert.equal(r.result.associateId,0x7fffffff);}}
});

test('720 complete original quickchat response cases preserve native area/radius filtering and canonical ID/WORD replies',()=>{
 const f=fixture('native-network-quickchat-response-observations.json');assert.equal(f.cases.length,720);
 for(const r of f.cases){const c=r.case,expected=!c.noSource&&c.sameArea&&c.distance<=20;assert.equal(r.sent.length,Number(expected));if(!expected)continue;assert.equal(r.sent[0].playerId,7);const packet=Buffer.from(r.sent[0].packet,'hex'),id=c.objectId===0x7f000000?c.objectId:(c.objectId|0x80000000)>>>0;
  if(c.format===1){assert.deepEqual(decodeServerGameMessage(packet),{kind:'quick-chat',major:22,minor:0,objectId:id,quickChat:c.quickChat});for(let i=0;i<packet.length;i++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,i)));}
  else{const reader=new NativeMessageReader(0);assert.equal(reader.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1),1);assert.equal(reader.readObjectIdClient(),id);assert.equal(reader.readWord(),c.quickChat);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);}
 }
});

test('self command wheel uses native quick-chat codes while owned commands keep signed targeted requests and shortcuts follow current links',()=>{
 const pc={id:0xffffffff,objectType:5,replicated:{},familiarId:0x80000002},pet={id:0x80000002,objectType:5,replicated:{master:pc.id,field908:3,name:{text:'Familiar'}}},world=new NetworkWorld(),before=structuredClone([pc,pet]);world.localObjectId=pc.id;for(const o of [pc,pet])world.registry.addObjectAtPos(o.id,o);
 const menu=networkRadialActions(pc,pc).entries.find(e=>e.slot===5).children();assert.deepEqual(menu,networkPartyCommandMenu());assert.deepEqual(menu.entries.map(e=>[e.slot,e.quickChat]),[[2,0],[3,22],[4,10],[5,9],[6,4]]);assert.ok(menu.entries.every(e=>e.action==='associate.quickChat'));
 assert.equal(networkRadialActions(pet,pc).entries.find(e=>e.slot===3).command,-5);
 const choices=networkAssociateShortcutChoices(world,pc);assert.deepEqual(choices.filter(e=>e.binding.type===42).map(e=>e.binding.intParam),NETWORK_PARTY_COMMANDS.map(e=>e.quickChat));assert.ok(choices.some(e=>e.binding.type===38));const unsummon=choices.find(e=>e.binding.type===39);assert.deepEqual(unsummon.binding,{type:39,intParam:-8,associateType:1,associateId:pet.id});
 assert.deepEqual(networkAssociateShortcut({type:39,intParam:-8,associateType:3,associateId:123},pc),{targetId:pet.id,command:-8});assert.deepEqual([pc,pet],before);pc.familiarId=0x80000003;assert.equal(networkAssociateShortcut({type:39,intParam:-8,associateType:3},pc).targetId,0x80000003);assert.equal(networkAssociateShortcut(unsummon.binding,pc).targetId,pet.id);assert.equal(networkAssociateShortcut({type:39,intParam:-8,associateType:2},pc).targetId,0x7f000000);pet.replicationRemoved=true;assert.equal(networkAssociateShortcutChoices(world,pc).some(e=>[38,39].includes(e.binding.type)),false);
});

test('real vanilla wheel/global shortcut commands drive server follow AI and types38/39 preserve possession and unsummon control',async()=>{
 const r=fixture('local-network-renderer-v63.json'),diagnostics=fixture('local-network-renderer-v63-diagnostics.json');assert.equal(r.failure,undefined);assert.equal(r.sampleFailure,undefined);assert.equal(r.quickbarActions.length,20);assert.ok(r.paintFrames>4000);assert.equal(r.states.at(-1).closed,true);assert.deepEqual(diagnostics.filter(e=>e.severity==='error'),[]);
 const packets=r.quickbarRequests,controls=[];for(const s of r.samples)if(controls.at(-1)!==s.server.controlledId)controls.push(s.server.controlledId);const familiarId=controls[2];assert.deepEqual(controls,[0x7f000000,0xffffffff,familiarId,0xffffffff]);assert.equal(packets.length,9);
 for(const code of [10,22])assert.equal(packets.filter(p=>p.packet===Buffer.from(quickChatRequest({quickChat:code})).toString('hex')).length,1);assert.equal(packets.filter(p=>p.packet==='700613').length,1);
 for(const command of [-13,-8])assert.equal(packets.filter(p=>p.packet===Buffer.from(associateCommandRequest({targetId:familiarId,command})).toString('hex')).length,1);
 const after=r.samples.at(-1).quickbar.buttons;assert.deepEqual([after[9].type,after[9].intParam,after[9].associateType,after[9].associateId],[39,-8,1,familiarId]);assert.equal(after[10].type,42);assert.equal(after[10].intParam,22);assert.equal(after[11].type,38);
 const followAt=packets.find(p=>p.packet===Buffer.from(quickChatRequest({quickChat:22})).toString('hex')).at,possessAt=packets.find(p=>p.packet==='700613').at,moveAt=r.moves[0].at;
 const position=(s,id)=>s.server.objects.find(o=>o.id===id)?.position,distance=(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]));const standing=r.samples.filter(s=>s.at>moveAt+1500&&s.at<followAt),following=r.samples.filter(s=>s.at>followAt+1000&&s.at<possessAt);assert.ok(standing.length>5);assert.ok(following.length>5);
 const old=position(standing[0],familiarId);assert.ok(standing.every(s=>distance(position(s,familiarId),old)<0.001));const startDistance=distance(position(standing.at(-1),0xffffffff),old);assert.ok(following.some(s=>distance(position(s,familiarId),old)>0.5&&distance(position(s,familiarId),position(s,0xffffffff))<startDistance-0.5));
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm')),world=new NetworkWorld(),replies=[];let familiar,pc;
 for(const hex of r.wireMessages){const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(message);if(message.kind==='quick-chat')replies.push(message);const p=world.registry.get(0xffffffff),f=world.registry.get(familiarId);if(p){if(pc)assert.equal(p,pc);else pc=p;}if(f){if(familiar)assert.equal(f,familiar);else familiar=f;}}
 assert.deepEqual(replies.map(m=>[m.objectId,m.quickChat]),[[0xffffffff,10],[0xffffffff,22]]);assert.equal(world.localObjectId,0xffffffff);assert.equal(world.controls.get(0),0xffffffff);assert.ok(familiar.replicationRemoved);assert.equal(pc.familiarId,0x7f000000);assert.equal(world.quickbar[10].type,42,'server re-sent the PC shortcut after possession');assert.equal(world.quickbar[11].type,38);
});
