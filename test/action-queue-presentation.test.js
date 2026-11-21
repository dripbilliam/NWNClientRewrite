import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {describeActionQueue} from '../src/action_queue_presentation.js';
test('queue presentation resolves physical action/spell rows from active tables and retains special/target identities',()=>{
  const actions=parse2da('2DA V2.0\n\nLABEL STRING_REF ICONRESREF\n99 First 10 changed_icon\n77 Spell 11 ****\n'),spells=parse2da('2DA V2.0\n\nIconResRef\n90 new_spell_icon\n');
  const empty={action:65535,special:65535,group:65535,spell:-1,targetId:0x7f000000},special={action:65535,special:0,group:7,spell:-1,targetId:123};
  const rows=describeActionQueue([empty,special,{...special,action:0,group:8}],actions,spells,{strRef:ref=>ref===10?'Translated action':undefined});
  assert.equal(rows[0],null);assert.equal(rows[1].label,'Translated action');assert.equal(rows[1].icon,'changed_icon');assert.equal(rows[1].index,1);assert.equal(rows[1].group,7);assert.equal(rows[1].targetId,123);
  const spellActions=parse2da('2DA V2.0\n\nLABEL STRING_REF ICONRESREF\n0 Zero 0 ****\n1 One 1 ****\n2 Two 2 ****\n3 Three 3 ****\n4 Cast 4 ****\n');
  assert.equal(describeActionQueue([{...special,action:4,spell:0}],spellActions,spells)[0].icon,'new_spell_icon');
  assert.throws(()=>describeActionQueue([{...special,action:4,spell:1}],spellActions,spells),/spell row 1/);
});
