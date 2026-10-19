import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellPreparationRequest,spellPreparationClearRequest} from '../src/network_spell_input.js';
import {networkPreparationEntries} from '../src/network_spellbook.js';
import {parse2da} from '../src/area.js';

test('234 unchanged original preparation/clear writer packets match every transmitted bit',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spellbook-request-observations.json',import.meta.url)));
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,234);
 for(const row of oracle.cases){const c=row.case,actual=Buffer.from(c.clear?spellPreparationClearRequest(c):spellPreparationRequest(c)),native=Buffer.from(row.packet,'hex');assert.equal(actual.length,native.length);assert.deepEqual(actual.subarray(0,-1),native.subarray(0,-1),JSON.stringify(c));const used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.at(-1)&mask,native.at(-1)&mask,JSON.stringify(c));}
 for(const c of [{classIndex:-1},{slot:256},{metamagic:NaN},{domainLevel:256},{spellId:-1}])assert.throws(()=>spellPreparationRequest({classIndex:0,spellId:123,slot:0,...c}));
 assert.throws(()=>spellPreparationClearRequest({classIndex:0,level:0,slot:1.5}));
});

test('replicated spellbook adapter uses class data, owned wizard knowledge, divine lists and domains',()=>{
 const classes=parse2da('2DA V2.0\n\nSpellCaster PlayerClass SpellTableColumn SpellbookRestricted MinCastingLevel PickDomains\n0 1 1 Custom 1 1 0\n1 1 1 Custom 0 4 1\n'),spells=parse2da('2DA V2.0\n\nCustom MetaMagic\n0 0 63\n1 1 4\n2 1 1\n3 **** 63\n'),domains=parse2da('2DA V2.0\n\nLevel_1\n0 3\n1 3\n'),rules={classes,spells,domains},actor={replicated:{stats:{classes:[{id:0,level:1},{id:1,level:4,domains:[0,1]}]}},playerState:{spellbooks:{0:{known:[2,0]},1:{known:[]}}}};
 assert.deepEqual(networkPreparationEntries(actor,rules,0,1),[{id:2,domain:0,metamagic:0}]);assert.deepEqual(networkPreparationEntries(actor,rules,0,1,4),[]);
 assert.deepEqual(networkPreparationEntries(actor,rules,1,1,4),[{id:1,domain:0,metamagic:4},{id:3,domain:1,metamagic:4}]);actor.replicated.stats.classes[1].level=3;assert.deepEqual(networkPreparationEntries(actor,rules,1,1),[]);
});

test('live vanilla server acknowledges DOM clearing and memorization without readying the new spell',()=>{
 const a=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-spellbook-acceptance-v87.json',import.meta.url)));
 assert.equal(a.connected,true);assert.equal(a.normalClose,true);assert.equal(a.failure,null);assert.equal(a.sampleFailure,null);assert.deepEqual(a.runtimeErrors,[]);assert.deepEqual(a.preparationDiagnostics,[]);
 assert.equal(a.requests.length,2);assert.ok(a.requests[0].packet.startsWith('700611'));assert.ok(a.requests[1].packet.startsWith('700610'));
 assert.equal(a.changes.length,3);assert.equal(a.changes[0].slots[0].ready,1);assert.equal(a.changes[1].slots[0],null);assert.equal(a.changes[2].slots[0].spell,a.actions.find(r=>r.step.mode==='spellbookMemorize').result.spellId);assert.equal(a.changes[2].slots[0].ready,0);assert.deepEqual(a.changes.map(c=>c.slots.length),[4,4,4]);
});
