import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {NativeMessageReader} from '../../src/native_message.js';
import {characterSheetRequest,skillDescriptionGuiRequest,featDescriptionGuiRequest} from '../../src/network_hud_input.js';
const {associateRecordProof}=createRequire(import.meta.url)('../tools/native-associate-record-proof.cjs');
let checks=0;const check=(value,label)=>{checks++;assert.ok(value,label);};
const actor=0xffffffff,target=0x80000004,packet=bytes=>({major:bytes[1],minor:bytes[2],controlledId:actor,bytes:[...bytes]});
const pages=[0,1,2,-1].map(page=>packet(characterSheetRequest({targetId:target,page})));
const details=[[3,1],[3,1],[3,3],[4,3],[4,3],[4,4]].map(([event,id])=>packet((event===3?skillDescriptionGuiRequest:featDescriptionGuiRequest)({targetId:target,includePosition:true,[event===3?'skillId':'featId']:id})));
const input={target,actions:true,lifecycle:true,wire:[...pages,...details]};
const before=structuredClone(input),run=value=>associateRecordProof(value,NativeMessageReader);
check(run(input).success,'Exact current target typed subscriptions and six GUI callbacks admitted');
assert.deepEqual(input,before);checks++;
for(const key of ['actions','lifecycle'])check(!run({...input,[key]:false}).success,'Outcome/lifecycle mandatory: '+key);
for(const bad of [undefined,null,-1,1.5,0x100000000,0x7f000000])check(!run({...input,target:bad}).success,'Unavailable/invalid target rejected');
for(let n=0;n<input.wire.length;n++)check(!run({...input,wire:input.wire.filter((_,index)=>index!==n)}).success,'Each expected page/callback mandatory '+n);
for(let n=0;n<details.length;n++){
 const wrong=structuredClone(input);wrong.wire[n+pages.length]=packet((n<3?skillDescriptionGuiRequest:featDescriptionGuiRequest)({targetId:actor,includePosition:true,[n<3?'skillId':'featId']:n<2?1:n===2?3:n<5?3:4}));
 check(!run(wrong).success,'Actor may not replace displayed NPC target '+n);
}
for(const bytes of [[],[112,53,1],[-1],[256],[1.5]])check(!run({...input,wire:[...input.wire,{major:53,minor:1,bytes}]}).success,'Malformed extra witness rejects acceptance');
const self=structuredClone(input);self.wire.at(-1).controlledId=target;check(!run(self).success,'GUI event cannot claim target is controlled actor');
const detached=run(input);detached.wire[0].page=127;detached.wire[4].position[0]=9;assert.deepEqual(input,before);checks++;
console.log(JSON.stringify({success:true,checks,scope:'Test-only bounded witness decoder against actual typed protocol writers; no server/UI/GPU acceptance.'}));
