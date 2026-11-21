import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const {npcCombatProof}=createRequire(import.meta.url)('../godot-client/tools/native-npc-combat-proof.cjs');
const required=['Actual current NPC positions/appearance yield original near branch2','Actual NPC private body clip/speed/one-shot mode match its selected near cue','Actual NPC private pose and selected original clip clock advance without GPU waits','Original NPC selected clock reaches its actual authored Hit event','Received NPC facing lock turns its private body toward the actual defender','Original GetCurrentAction confirms the NPC queue is empty','Original NPC stop returns the received and private presentation to its idle/ready base'];
function observed(){
 const attacker=0x80000011,defender=0x80000012,lifetime=11,generation=2,areaId=0x80000001;
 const details={attacker,defender,lifetime,defenderLifetime:12,controlledId:0xffffffce,generation,areaId,metadata:{classState:{id:attacker,lifetime,known:true,monk:false,source:'received-creature-classes'}}};
 const received=[{at:101,id:attacker,nativeLifetime:lifetime,generation,areaId,animation:9,attacks:[{target:defender}],facingTarget:defender},{at:201,id:attacker,nativeLifetime:lifetime,generation,areaId,animation:0}];
 return {received,stimuli:[{at:100,text:'-native-npc-start'},{at:200,text:'-native-npc-stop'}],actions:{success:true,checks:[...required.map(label=>({label,passed:true})),{label:'NPC combat scoped original-server presentation outcome complete',passed:true,details}]},lifecycle:true};
}
const detail=x=>x.actions.checks.at(-1).details;
test('strict observed NPC record, native clip/clock/Hit, facing, queue stop and lifecycle admit only this scoped result',()=>{const result=npcCombatProof(observed());assert.equal(result.success,true);assert.equal(result.constructorPathExercised,false);assert.equal(result.constructorGameplayAccepted,false);});
for(const [name,edit]of [
 ['no native completion',x=>x.actions.checks.pop()],['failed actions',x=>x.actions.success=false],['unverified lifecycle',x=>x.lifecycle=false],['truthy nonboolean lifecycle',x=>x.lifecycle=1],
 ['foreign current controlled actor',x=>detail(x).controlledId=detail(x).attacker],['OBJECT_INVALID attacker',x=>detail(x).attacker=0x7f000000],['out of range defender',x=>detail(x).defender=0x100000000],['missing defender lifetime',x=>delete detail(x).defenderLifetime],
 ['stale native lifetime',x=>x.received[0].nativeLifetime++],['stale generation',x=>x.received[0].generation++],['foreign area',x=>x.received[0].areaId++],['wrong attacker',x=>x.received[0].id++],
 ['wrong attack target',x=>x.received[0].attacks[0].target++],['missing received attack animation',x=>delete x.received[0].animation],['wrong received facing target',x=>x.received[0].facingTarget++],
 ['pre-input attack',x=>x.received[0].at=99],['post-stop attack',x=>x.received[0].at=202],['pre-stop idle',x=>x.received[1].at=199],['same-timestamp unordered setup',x=>x.stimuli[1].at=100],['replayed setup',x=>x.stimuli.push(x.stimuli[0])],
 ['missing class provenance',x=>delete detail(x).metadata.classState],['foreign private class owner',x=>detail(x).metadata.classState.id++],['stale private class lifetime',x=>detail(x).metadata.classState.lifetime++],['unknown classes',x=>detail(x).metadata.classState.known=false],['guessed provenance',x=>detail(x).metadata.classState.source='fixture-default'],
 ['unbounded received log',x=>x.received.push(...Array.from({length:127},()=>({...x.received[1]})))],
 ])test(name+' cannot become server/model acceptance',()=>{const input=observed();edit(input);assert.equal(npcCombatProof(input).success,false);});
for(const label of required)test('missing actual native assertion: '+label,()=>{const input=observed();input.actions.checks.find(row=>row.label===label).passed=false;assert.equal(npcCombatProof(input).success,false);});
test('a genuinely observed constructor class path is recorded without inventing a second gameplay acceptance',()=>{const input=observed();detail(input).metadata.classState.source='native-constructor-7ea230';const result=npcCombatProof(input);assert.equal(result.success,true);assert.equal(result.constructorPathExercised,true);assert.equal(result.constructorGameplayAccepted,false);});
