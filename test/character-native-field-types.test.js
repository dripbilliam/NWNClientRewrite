import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {openLocalModule} from '../scripts/local-module.mjs';
import {loadCreationRules,initialCreationDraft,recommendCreation,createCharacterBic} from '../src/character_creation.js';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';

const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-character-field-type-observations.json',import.meta.url)));
test('690 original typed INT/SHORT reads reject numerically equal fields of another GFF type',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(native.cases.length,690);
 for(const row of native.cases){const c=row.case,bits=c.reader==='INT'?32:16,found=Number(c.type===(c.reader==='INT'?5:3)&&!c.missing&&!c.noStruct&&!c.noLabel),raw=found?c.value:c.default,expected=bits===32?raw|0:raw<<16>>16;assert.equal(row.found,found,JSON.stringify(c));assert.equal(row.value,expected,JSON.stringify(c));}
});

test('vanilla server admits the generated level-one wizard and keeps uploaded innate powers outside replicated authority',async()=>{
 const root='../FullDecomp/NwnRootInstall',rules=await loadNetworkObjectRules(await openLocalModule(root,root+'/data/nwm/Prelude.nwm'));
 for(const version of [55,56]){const r=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-renderer-v${version}.json`,import.meta.url))),world=new NetworkWorld();assert.equal(r.renderer.state.phase,'playing');assert.equal(r.failure,undefined);assert.equal(r.states.at(-1).closed,true);
  for(const hex of r.wireMessages){const m=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17},objectRules:{...rules,objectState:id=>world.registry.get(id)?.replicated}});world.apply(m);}
  const actor=world.registry.get(world.localObjectId);assert.equal(actor.replicated.stats.classes[0].id,10);assert.equal(actor.replicated.stats.classes[0].level,1);assert.equal(actor.replicated.stats.race,0);assert.ok(actor.playerState.spellbooks[0].known.includes(100));assert.deepEqual(actor.playerState.specialAbilities,[]);
 }
});

test('fresh wizard BIC fields pass original typed readers and preserve native history record IDs',async()=>{
 const root='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,root+'/data/nwm/Prelude.nwm'),rules=await loadCreationRules(resolver),draft=initialCreationDraft(rules);Object.assign(draft,{raceId:0,classId:10,packageId:Number(rules.classes.orderedRows[10].Package),firstName:'Typed',lastName:'Admission'});await recommendCreation(draft,rules);
 const character=parseGff(await createCharacterBic(draft,rules)).root,cls=character.ClassList[0],types=getGffFieldTypes(cls);
 for(const [name,reader]of [['Class','INT'],['ClassLevel','SHORT']]){const row=native.cases.find(r=>r.case.reader===reader&&r.case.type===types[name]&&r.case.value===cls[name]&&r.case.default===255&&!r.case.missing&&!r.case.noStruct&&!r.case.noLabel);assert.ok(row);assert.equal(row.found,1);assert.equal(row.value,cls[name]);}
 const badClass=native.cases.find(r=>r.case.reader==='INT'&&r.case.type===0&&r.case.value===10&&r.case.default===255);assert.equal(badClass.found,0);assert.equal(badClass.value,255);
 assert.ok(!('LvlStatAbility'in character.LvlStatList[0]));assert.ok(character.LvlStatList[0].FeatList.every(f=>getGffStructType(f)===0));assert.ok(character.FeatList.every(f=>getGffStructType(f)===1));
 for(const [name,rows]of Object.entries(character.LvlStatList[0]))if(name.startsWith('KnownList'))assert.ok(rows.every(s=>getGffStructType(s)===0));
 assert.equal(character.Experience,0);assert.equal(cls.Class,10);assert.equal(cls.ClassLevel,1);assert.equal(character.ObjectId,undefined);
 // ReadFieldDWORDorBYTE1a1590, used by ValidateCreateServerCharacter5706d9,
 // reads the x-prefixed DWORD before the legacy BYTE. Custom selectable
 // packages can exceed255 even when classes.Package names a hidden preset.
 rules.packages.orderedRows[270]={...rules.packages.orderedRows[draft.packageId]};draft.packageId=270;
 const extended=parseGff(await createCharacterBic(draft,rules)).root;assert.equal(extended.StartingPackage,0);assert.equal(extended.xStartingPackage,270);assert.equal(getGffFieldTypes(extended).StartingPackage,0);assert.equal(getGffFieldTypes(extended).xStartingPackage,4);
});
