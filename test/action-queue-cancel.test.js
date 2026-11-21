import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createObjectActionState,addObjectAction} from '../src/object_actions.js';
import {cancelQueueAction,idByQueueActionId} from '../src/action_queue_cancel.js';
import {ModuleSession} from '../src/module_session.js';
import {createCombatRound} from '../src/combat_round.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-action-cancel-observations.json',import.meta.url)));
test('reverse queue enum matches every original ushort including shared icons and absent mappings',()=>{
  const words=Buffer.alloc(65536*2);for(let n=0;n<65536;n++)words.writeUInt16LE(idByQueueActionId(n),n*2);
  assert.equal(createHash('sha256').update(words).digest('hex'),capture.mapSha256);
  assert.equal(idByQueueActionId(27),204);assert.equal(idByQueueActionId(34),65535);
});
test('live player queue cancellation removes its group through the input FIFO and preserves other/protected records',async()=>{
  const s=new ModuleSession(null),actor=s.register('player','pc',{stats:{},combatRound:createCombatRound()});s.player=actor;actor.commandable=0;
  const first=addObjectAction(actor.objectActionState,37,7),other=addObjectAction(actor.objectActionState,37,8),protectedNode=addObjectAction(actor.objectActionState,37,7);protectedNode.nativeField9c=0;
  const request=s.queuePlayerCancelAction(3,7);await s.drainPlayerInputs();assert.equal(await request,1);
  assert.deepEqual([...actor.objectActionState.list],[other,protectedNode]);assert.ok(![...actor.objectActionState.list].includes(first));
  const stale=s.queuePlayerCancelAction(3,8);s.player=s.register('player','replacement',{stats:{}});await s.drainPlayerInputs();assert.equal(await stale,0);assert.deepEqual([...actor.objectActionState.list],[other,protectedNode]);
});
test('queue cancellation matches original special sequence priority, repeated groups, head identity and protected nodes',async()=>{
  for(const row of capture.rows){const c=row.case,calls=[],state=createObjectActionState(),nodes=[],actor={objectActionState:state,combatRound:{specialAttacks:c.specials.slice(),specialAttackParameters:c.sequences.slice()}};
    for(const group of c.groups)nodes.push(addObjectAction(state,12,group));
    const p={specialCount:round=>{calls.push(['specialCount']);return round.specialAttacks.length;},specialType:(round,n)=>{calls.push(['specialType',n]);return round.specialAttacks[n];},
      specialId:(round,n)=>{calls.push(['specialId',n]);return round.specialAttackParameters[n];},removeSpecial:(round,n)=>{calls.push(['removeSpecial',n]);round.specialAttacks.splice(n,1);round.specialAttackParameters.splice(n,1);},
      clearAction:(_actor,node,head)=>{const n=nodes.indexOf(node);calls.push(['clear',n,Number(head)]);return c.clear[n];},dispose:node=>calls.push(['dispose',nodes.indexOf(node)])};
    const result=await cancelQueueAction(actor,c.code,c.group,p);
    assert.deepEqual({result,calls,specials:actor.combatRound.specialAttacks,sequences:actor.combatRound.specialAttackParameters,remaining:[...state.list].map(node=>nodes.indexOf(node))},
      {result:row.result,calls:row.calls,specials:row.specials,sequences:row.sequences,remaining:row.remaining},JSON.stringify(c));
  }
});
