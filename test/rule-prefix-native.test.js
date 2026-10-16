import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {rulesetHash} from '../src/combat_stats.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-rule-prefix-observations.json',import.meta.url)));
test('prehashed-prefix native rule call sites hash to the complete E/M/A-prefixed keys',()=>{
 assert.equal(capture.rows.length,3);for(const row of capture.rows){assert.equal(rulesetHash(row.label).toString(16).padStart(16,'0'),row.hash);assert.notEqual(rulesetHash(row.suffix).toString(16).padStart(16,'0'),row.hash);}
});
test('all four companion interaction runtime providers read the active ALL_ASSOCIATES_CAN_INTERACT key',()=>{
 const s=new ModuleSession(null);s.characterRules={ruleset:parse2da('2DA V2.0\n\nLabel Value\n0 ALL_ASSOCIATES_CAN_INTERACT 7\n1 LL_ASSOCIATES_CAN_INTERACT 99')};
 const values=()=>[s.importedEquipmentProviders().associatesCanInteract(),s.combat.unequipActionProviders().associatesCanInteract(),s.combat.repositoryMoveProviders().associatesCanInteract(),s.combat.useObjectProviders().associatesCanInteract()];
 assert.deepEqual(values(),[7,7,7,7]);s.characterRules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 ALL_ASSOCIATES_CAN_INTERACT 0');assert.deepEqual(values(),[0,0,0,0]);
});
