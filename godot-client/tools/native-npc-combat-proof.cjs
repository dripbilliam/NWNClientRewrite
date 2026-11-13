'use strict';
// Acceptance policy only. Never produces game traffic or presentation state.
function npcCombatProof({received=[],stimuli=[],actions,lifecycle=false}){
 const checks=actions?.checks??[],done=checks.find(row=>row.passed&&row.label==='NPC combat scoped original-server presentation outcome complete'),details=done?.details??{},attacker=details.attacker,defender=details.defender,lifetime=details.lifetime;
 const objectId=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff&&value!==0x7f000000;
 const identity=objectId(attacker)&&objectId(defender)&&objectId(details.controlledId)&&attacker!==defender&&attacker!==details.controlledId&&defender!==details.controlledId&&Number.isSafeInteger(lifetime)&&lifetime>0&&Number.isSafeInteger(details.defenderLifetime)&&details.defenderLifetime>0&&Number.isSafeInteger(details.generation)&&details.generation>=0&&objectId(details.areaId);
 const timestamps=stimuli.length===2&&stimuli.every(row=>Number.isSafeInteger(row.at)&&row.at>0);
 const start=timestamps&&stimuli[0]?.text==='-native-npc-start'?stimuli[0]:null,stop=timestamps&&stimuli[1]?.text==='-native-npc-stop'&&stimuli[1].at>start?.at?stimuli[1]:null;
 const rows=identity?received.filter(row=>row.id===attacker&&row.nativeLifetime===lifetime&&row.generation===details.generation&&row.areaId===details.areaId):[];
 const bounded=received.length<=128&&rows.every(row=>Number.isSafeInteger(row.at)&&row.at>0);
 const attack=start&&stop?rows.find(row=>row.at>=start.at&&row.at<stop.at&&row.animation===9&&row.attacks?.some(value=>value.target===defender)):null;
 const facing=start&&stop?rows.find(row=>row.at>=start.at&&row.at<stop.at&&row.facingTarget===defender):null;
 const idle=stop?rows.find(row=>row.at>=stop.at&&[0,1].includes(row.animation)):null;
 const required=['Actual current NPC positions/appearance yield original near branch2','Actual NPC private body clip/speed/one-shot mode match its selected near cue','Actual NPC private pose and selected original clip clock advance without GPU waits','Original NPC selected clock reaches its actual authored Hit event','Received NPC facing lock turns its private body toward the actual defender','Original GetCurrentAction confirms the NPC queue is empty','Original NPC stop returns the received and private presentation to its idle/ready base'];
 const nativeChecks=required.every(label=>checks.some(row=>row.label===label&&row.passed));
 const classState=details.metadata?.classState,classProvenance=Boolean(classState&&classState.id===attacker&&classState.lifetime===lifetime&&classState.known===true&&typeof classState.monk==='boolean'&&['received-creature-classes','native-constructor-7ea230'].includes(classState.source));
 return {success:Boolean(identity&&bounded&&start&&stop&&attack&&facing&&idle&&nativeChecks&&classProvenance&&actions?.success===true&&lifecycle===true),attacker,defender,lifetime,start,stop,attack,facing,idle,nativeChecks,classProvenance,constructorPathExercised:classState?.source==='native-constructor-7ea230',constructorGameplayAccepted:false,source:'Actual decoded original NPC attack/facing/idle fields and private native near-clip/clock/Hit/queue checks. Constructor-vs-received class provenance is recorded, never forced; no pixels/full-combat claim.'};
}
module.exports={npcCombatProof};
