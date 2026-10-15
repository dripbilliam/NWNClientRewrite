// Execute the exact installed scripts reported by the user's log, in memory.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {parseGff} from '../src/gff.js';
const install='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),messages=[],sounds=[],camera=[];
const bytes=await fs.readFile(`${install}/data/lcv/wizard.bic`);
const session=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,onMessage:m=>messages.push(m),onSound:s=>sounds.push(s),onCameraMode:(actor,mode)=>camera.push({actorId:actor.id,mode})}).initialize(['m0q1a'],{character:bytes});
const owner=session.byTag('M1Q0ABim')[0],door=session.byTag('M1Q0A_M1Q0B')[0],player=session.player;
assert.ok(owner&&door);owner.conversation={playerId:player.id};
const dialogue=parseGff(await resolver.getResource(owner.authored.Conversation,2029)).root;
const target=dialogue.EntryList.findIndex(n=>n.Script==='m1q0apaveslg03');
const pending=dialogue.StartingList.map(l=>({index:l.Index,choices:[]})),visited=new Set();let route=null;
while(pending.length){const item=pending.shift();if(item.index===target){route=item;break;}if(visited.has(item.index))continue;visited.add(item.index);
 for(const [ordinal,l]of (dialogue.EntryList[item.index].RepliesList??[]).entries())for(const next of dialogue.ReplyList[l.Index].EntriesList??[])pending.push({index:next.Index,choices:[...item.choices,ordinal]});}
const start=runtimeDiagnostics.records.length;
await session.vm.run(await session.program('m1q0apaveslg03'),owner.id);
assert.deepEqual(camera,[{actorId:player.id,mode:1}]);owner.conversation=null;
player.areaId=door.areaId;player.position=[...door.position];
await session.vm.run(await session.program('nw_od_feedback8'),door.id);
assert.equal(messages.at(-1)?.type,'oneLiner');assert.equal(messages.at(-1)?.id,door.id);
assert.ok([...door.objectActionState.list].some(node=>node.actionId===37),'Authored feedback cleanup remains queued as ActionDoCommand');
assert.equal(session.conversation.state,null);
const failures=runtimeDiagnostics.records.slice(start).filter(r=>r.code==='engine.unimplemented'||r.code==='script.failure');assert.deepEqual(failures,[]);
console.log(JSON.stringify({camera,messages,sounds,scriptFailures:failures.length,feedbackLocal:session.local(door.id,'NW_L_FEEDBACK','int'),dialogueRoute:route,ownerPosition:owner.position},null,2));
