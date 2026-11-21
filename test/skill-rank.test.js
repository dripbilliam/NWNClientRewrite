import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { skillRank } from '../src/skill_rank.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const rules = { skills: parse2da('2DA V2.0\n\nUntrained\n0 0\n1 1\n2 0') };
const creature = ranks => ({ creatureData: { SkillList: ranks.map(Rank => ({ Rank })) } });

test('base skill ranks use signed bytes, clamp negative 128 to -127, and narrow skill IDs', () => {
  const object = creature([20, 128, 255]);
  assert.equal(skillRank(object, 0, rules, true), 20);
  assert.equal(skillRank(object, 1, rules, true), -127);
  assert.equal(skillRank(object, 2, rules, true), -1);
  assert.equal(skillRank(object, 256, rules, true), 20);
  object.stats = { skills: [12] }; assert.equal(skillRank(object, 0, rules, true), 12, 'Canonical live ranks take precedence');
});

test('native invalid-skill and DM gates precede base/effective providers', () => {
  const object = creature([]); object.isDM = true;
  assert.equal(skillRank(object, 3, rules), 0);
  assert.equal(skillRank(object, 0, rules), 127);
  assert.equal(skillRank(object, 0, rules, true), 127);
  const large = { skills: { orderedRows: Array(260).fill({ Untrained: '1' }) } };
  assert.equal(skillRank(object, 4, large), 0, 'Native rule skill count is a byte');
});

test('effective rank paths fail explicitly instead of returning raw ranks or inferring an unaudited loader field', () => {
  const object = creature([0, 0, 1]);
  assert.throws(() => skillRank(object, 0, rules), /Effective skill rank/);
  assert.throws(() => skillRank(object, 1, rules), /Effective skill rank/);
  assert.throws(() => skillRank(object, 2, rules), /Effective skill rank/);
  assert.throws(() => skillRank(object, 0, {}), /skill rules/);
});

test('script skill query preserves native non-creature -1, SELF default and nonzero base flag', () => {
  const s = new ModuleSession(null); s.characterRules = rules;
  const object = s.register('creature', 'a', creature([7]));
  assert.equal(s.commands.GetSkillRank([0, undefined, -2], { self: object.id }), 7);
  assert.equal(s.commands.GetSkillRank([0, OBJECT_INVALID], { self: object.id }), -1);
  assert.equal(s.commands.GetSkillRank([0, s.register('door', 'door', {}).id], { self: object.id }), -1);
});
