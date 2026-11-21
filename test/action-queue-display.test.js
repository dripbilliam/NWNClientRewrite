import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createObjectActionState,addObjectAction,actionByGroupId} from '../src/object_actions.js';
import {actionQueueId,actionGroupPosition,updateActionQueueDisplay} from '../src/action_queue_display.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-action-queue-observations.json',import.meta.url)));
test('AQ display maps match original instructions for all65536 ushort inputs in both modes',()=>{
  for(const row of capture.maps){const words=Buffer.alloc(65536*2);
    for(let n=0;n<65536;n++)words.writeUInt16LE(actionQueueId(n,row.special),n*2);
    assert.equal(createHash('sha256').update(words).digest('hex'),row.sha256);
    for(const [input,expected] of Object.entries(row.mapping)){assert.equal(actionQueueId(Number(input)+65536,row.special),expected);if(row.special)assert.equal(actionQueueId(Number(input),-1),expected);}
  }
});
test('queue summary matches original ten physical records, raw words, special packing and item spell query order',async()=>{
  for(const row of capture.rows){const c=row.case,calls=[],state=createObjectActionState(),buffer=new Uint8Array(280).fill(0xa5),actor={objectActionState:state,
      nativeActionQueue59c:new DataView(buffer.buffer),combatRound:{specialAttacks:c.specials.slice(),specialAttackParameters:c.specialIds.slice()}};
    for(const entry of c.actions){const node=addObjectAction(state,entry.action,entry.group);node.parameterData=entry.words.slice();}
    const p={groupPosition:(state,index)=>{calls.push(['groupPosition',index]);return actionGroupPosition(state,index);},
      groupAction:(state,group)=>{calls.push(['groupAction',group]);return actionByGroupId(state,group);},
      specialCount:round=>{calls.push(['specialCount']);return round.specialAttacks.length;},specialId:(round,n)=>{calls.push(['specialId',n]);return round.specialAttackParameters[n];},
      specialType:(round,n)=>{calls.push(['specialType',n]);return round.specialAttacks[n];},
      item:id=>{calls.push(['item',id]);return c.item?{}:null;},activeProperty:(_item,n)=>{calls.push(['property',n]);return c.property?{subtype:c.subtype}:null;},
      spellIndex:n=>{calls.push(['spellIndex',n]);return c.spellIndex;}};
    await updateActionQueueDisplay(actor,p);
    assert.deepEqual({calls,raw:Buffer.from(buffer).toString('hex')},{calls:row.calls,raw:row.raw},JSON.stringify(c));
  }
});
