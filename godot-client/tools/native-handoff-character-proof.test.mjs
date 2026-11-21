import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { parseGff } from '../../src/gff.js';
import { typedGff, writeGff, gffField as F } from '../../src/gff_writer.js';
import { readHandoffCharacter, projectHandoffCharacter, compareHandoffCharacters as compare,
  compareHandoffCharacterChain as chain } from './native-handoff-character-proof.mjs';

// Public installed preset, not a profile/vault export or authored character DTO.
const presetPath = fileURLToPath(new URL('../../../FullDecomp/NwnRootInstall/data/lcv/wizard.bic',import.meta.url));
const bytes = fs.readFileSync(presetPath), sha = b => crypto.createHash('sha256').update(b).digest('hex');
const sourceHash = sha(bytes), original = readHandoffCharacter(bytes);
function variant(edit) {
  const root = typedGff(parseGff(bytes,'BIC ').root);
  edit(root);
  return readHandoffCharacter(writeGff('BIC ',root));
}
const field = (root,label) => root.fields[label];
const equipment = root => field(root,'Equip_ItemList').value;
const inventory = root => field(root,'ItemList').value;
const roundtrip = value => JSON.parse(JSON.stringify(value));

test('actual Wizard BIC yields complete detached selected-field proof and exact known values',() => {
  assert.equal(original.kind,'bic'); assert.equal(original.parsedOriginal,true);
  assert.equal(original.bytes,bytes.length); assert.equal(original.sha256,sourceHash);
  const p = original.character;
  assert.equal(p.complete,true); assert.deepEqual(p.coverage.missingCore,[]); assert.deepEqual(p.coverage.invalidCore,[]);
  assert.equal(p.canonical.identity.FirstName.value.entries[0].text,'Spectorial');
  assert.equal(p.canonical.identity.LastName.value.entries[0].text,'Melimion');
  assert.equal(p.canonical.identity.Race.value,1); assert.equal(p.canonical.abilities.Int.value,19);
  assert.equal(p.canonical.classes.value[0].fields.Class.value,10);
  assert.equal(p.canonical.classes.value[0].fields.ClassLevel.value,15);
  assert.deepEqual(p.canonical.equipment.value.map(v => v.structType),[2,128,256]);
  assert.equal(p.canonical.inventory.value.length,5); assert.equal(p.coverage.itemCount,8);
  assert.ok(p.omitted.rootFields.includes('HitPoints')); assert.ok(p.omitted.rootFields.includes('XPosition'));
  assert.ok(!p.omitted.classFields[0].includes('KnownList0'));
  assert.equal(p.coverage.scope,'selected-character-fields-and-spells-v2');
  assert.equal(compare(original,roundtrip(original)).success,true);
  assert.equal(JSON.stringify(original).includes('"data":['),false);
});

test('actual parser output projects identically; reserialization preserves all compared fields',() => {
  assert.deepEqual(projectHandoffCharacter(parseGff(bytes,'BIC ')),original.character);
  assert.equal(compare(original,variant(() => {})).success,true);
});

for (const [name,edit] of [
  ['first name',r => { field(r,'FirstName').value.entries[0].text = 'Other'; }],
  ['last name',r => { field(r,'LastName').value.entries[0].text = 'Other'; }],
  ['gender',r => { field(r,'Gender').value = 1; }],
  ['race',r => { field(r,'Race').value = 2; }],
  ['base ability',r => { field(r,'Int').value--; }],
  ['class identity',r => { field(r,'ClassList').value[0].fields.Class.value = 4; }],
  ['class level',r => { field(r,'ClassList').value[0].fields.ClassLevel.value++; }],
  ['school',r => { field(r,'ClassList').value[0].fields.School.value = 1; }],
  ['experience',r => { field(r,'Experience').value++; }],
  ['gold',r => { field(r,'Gold').value++; }],
  ['equipment slot',r => { equipment(r)[0].type = 4; }],
  ['item base type',r => { equipment(r)[0].fields.BaseItem.value++; }],
  ['item property',r => { equipment(r)[1].fields.PropertiesList.value[0].fields.CostValue.value++; }],
  ['item stack',r => { inventory(r)[1].fields.StackSize.value++; }],
  ['item charges',r => { inventory(r)[1].fields.Charges.value++; }],
  ['item cost',r => { equipment(r)[1].fields.Cost.value++; }],
]) test('semantic mismatch is visible: ' + name,() => {
  const result = compare(original,variant(edit));
  assert.equal(result.success,false); assert.equal(result.availableEqual,false);
  assert.ok(result.differenceCount > 0); assert.ok(result.differences.length > 0);
});

test('known absent optional identity remains distinct from explicitly empty',() => {
  const missing = variant(r => { delete r.fields.Subrace; });
  assert.equal(missing.character.complete,true);
  assert.deepEqual(missing.character.canonical.identity.Subrace,{present:false});
  assert.equal(compare(original,missing).success,false);
});

test('missing core fields and wrong-width core fields do not certify continuity',() => {
  const missing = variant(r => { delete r.fields.Race; });
  assert.equal(missing.character.complete,false);
  assert.deepEqual(missing.character.coverage.missingCore,['Race']);
  const result = compare(missing,missing);
  assert.equal(result.availableEqual,true); assert.equal(result.success,false);
  const width = variant(r => { r.fields.Race = F(4,r.fields.Race.value); });
  assert.deepEqual(width.character.coverage.invalidCore,['Race']);
  assert.equal(compare(original,width).success,false);
  const noLevel = variant(r => { delete r.fields.ClassList.value[0].fields.ClassLevel; });
  assert.equal(noLevel.character.complete,false);
});

test('empty class list and duplicate equipment slots are incomplete rather than successful',() => {
  const noClass = variant(r => { r.fields.ClassList.value = []; });
  assert.equal(noClass.character.complete,false);
  assert.ok(noClass.character.coverage.invalidCore.includes('ClassList.empty'));
  const slots = variant(r => { equipment(r)[1].type = equipment(r)[0].type; });
  assert.equal(slots.character.complete,false);
  assert.ok(slots.character.coverage.invalidCore.some(x => x.startsWith('Equip_ItemList.duplicateSlot:')));
});

test('incomplete item semantics and invalid class values cannot certify equality with themselves',() => {
  const noBase = variant(r => { delete equipment(r)[0].fields.BaseItem; });
  assert.equal(noBase.character.complete,false);
  assert.ok(noBase.character.coverage.missingCore.some(x => x.endsWith('.BaseItem')));
  assert.equal(compare(noBase,noBase).success,false);
  for (const [label,value] of [['Class',-1],['ClassLevel',0]]) {
    const bad = variant(r => { r.fields.ClassList.value[0].fields[label].value = value; });
    assert.equal(bad.character.complete,false);
    assert.equal(compare(bad,bad).success,false);
  }
});

test('runtime object IDs, world pose, grid placement, HP/time changes remain raw differences only',() => {
  const moved = variant(r => {
    for (const k of ['HitPoints','CurrentHitPoints','MaxHitPoints','XPosition','YPosition','AnimationTime'])
      if (r.fields[k]) r.fields[k].value++;
    for (const item of [...equipment(r),...inventory(r)]) {
      for (const k of ['ObjectId','XPosition','YPosition','ZPosition','Repos_PosX','Repos_Posy'])
        if (item.fields[k]) item.fields[k].value++;
    }
  });
  const result = compare(original,moved);
  assert.equal(result.success,true); assert.equal(result.rawEqual,false);
});

test('inventory order and equipment list order normalize without dropping duplicates',() => {
  const reordered = variant(r => { inventory(r).reverse(); equipment(r).reverse(); });
  assert.equal(compare(original,reordered).success,true);
  const duplicate = variant(r => { inventory(r).push(structuredClone(inventory(r)[1])); });
  assert.equal(compare(original,duplicate).success,false);
  assert.equal(duplicate.character.canonical.inventory.value.length,6);
});

test('class slot order remains significant rather than sorting multiclass identities',() => {
  const make = reverse => variant(r => {
    const next = structuredClone(r.fields.ClassList.value[0]);
    next.fields.Class.value = 4; next.fields.ClassLevel.value = 1;
    r.fields.ClassList.value.push(next);
    if (reverse) r.fields.ClassList.value.reverse();
  });
  assert.equal(compare(make(false),make(true)).success,false);
});

test('actual Wizard present spell fields retain native entry types, with no fabricated level9 or daily-use lists',() => {
  const book = original.character.canonical.classes.value[0].spellbook;
  assert.equal(book.known.present,true); assert.equal(book.memorized.present,true);
  assert.equal(Object.keys(book.known.fields).length,9); assert.equal(Object.keys(book.memorized.fields).length,9);
  assert.equal(Object.hasOwn(book.known.fields,'KnownList9'),false);
  assert.equal(Object.hasOwn(book.memorized.fields,'MemorizedList9'),false);
  assert.deepEqual(book.dailyUses,{present:false});
  const known = book.known.fields.KnownList0;
  assert.equal(known.type,15); assert.equal(known.value.length,7);
  assert.deepEqual(known.value[0].fields.Spell,{present:true,type:2,value:37});
  const memorized = book.memorized.fields.MemorizedList0.value[0].fields;
  assert.deepEqual(memorized.Ready,{present:true,type:0,value:1});
  assert.deepEqual(memorized.SpellMetaMagic,{present:true,type:0,value:0});
});

for (const [name,edit] of [
  ['known spell ID',c => { c.KnownList0.value[0].fields.Spell.value++; }],
  ['memorized spell ID',c => { c.MemorizedList0.value[0].fields.Spell.value++; }],
  ['memorized metamagic',c => { c.MemorizedList0.value[0].fields.SpellMetaMagic.value = 1; }],
  ['memorized ready flag',c => { c.MemorizedList0.value[0].fields.Ready.value = 0; }],
  ['known spell count',c => { c.KnownList0.value.pop(); }],
  ['memorized slot count',c => { c.MemorizedList0.value.pop(); }],
]) test('available spellbook mismatch remains visible: ' + name,() => {
  const changed = variant(r => edit(r.fields.ClassList.value[0].fields));
  const result = compare(original,changed);
  assert.equal(result.success,false); assert.equal(result.complete,true);
  assert.ok(result.differences.some(d => d.path.includes('/spellbook/')));
});

test('optional absent spell family/level is normal, but differs from an explicitly empty list',() => {
  const removed = variant(r => { delete r.fields.ClassList.value[0].fields.KnownList0; });
  const empty = variant(r => { r.fields.ClassList.value[0].fields.KnownList0.value = []; });
  assert.equal(removed.character.complete,true); assert.equal(empty.character.complete,true);
  assert.equal(compare(removed,empty).success,false);
  const noFamilies = variant(r => {
    const c=r.fields.ClassList.value[0].fields;
    for (const k of Object.keys(c)) if (/^(KnownList|MemorizedList)[0-9]$/.test(k)) delete c[k];
  });
  assert.deepEqual(noFamilies.character.canonical.classes.value[0].spellbook.known,{present:false,fields:{}});
  assert.deepEqual(noFamilies.character.canonical.classes.value[0].spellbook.memorized,{present:false,fields:{}});
  assert.equal(compare(noFamilies,noFamilies).success,true);
});

test('present spontaneous daily-use counts/types/length differ without normalizing server changes',() => {
  const daily = (counts,type=0) => variant(r => {
    r.fields.ClassList.value[0].fields.SpellsPerDayList=F(15,counts.map(n => ({type:0x4567,fields:{NumSpellsLeft:F(type,n)}})));
  });
  const before=daily([3,2]);
  for (const changed of [daily([3,1]),daily([3]),daily([3,2],2),daily([]),original]) {
    assert.equal(compare(before,changed).success,false);
    assert.equal(changed.character.complete,true);
  }
  assert.equal(compare(before,roundtrip(before)).success,true);
  assert.equal(compare(original,daily([])).success,false);
});

test('optional memorized entry flags missing versus zero and ordered slots remain distinguishable',() => {
  const missing=variant(r => { delete r.fields.ClassList.value[0].fields.MemorizedList0.value[0].fields.Ready; });
  const zero=variant(r => { r.fields.ClassList.value[0].fields.MemorizedList0.value[0].fields.Ready.value=0; });
  assert.equal(missing.character.complete,true); assert.equal(compare(missing,zero).success,false);
  const reordered=variant(r => { r.fields.ClassList.value[0].fields.MemorizedList0.value.reverse(); });
  assert.equal(compare(original,reordered).success,false);
  const wrongList=variant(r => { r.fields.ClassList.value[0].fields.KnownList0=F(0,0); });
  assert.equal(wrongList.character.complete,false);
});

test('actual level-history spells and progression fields are included as available ordered typed records',() => {
  assert.equal(original.character.canonical.progression.LvlStatList.value.length,15);
  const changed=variant(r => { r.fields.LvlStatList.value[0].fields.KnownList0.value[0].fields.Spell.value++; });
  assert.equal(compare(original,changed).success,false);
  const missing=variant(r => { delete r.fields.LvlStatList; });
  assert.equal(missing.character.complete,true); assert.equal(compare(original,missing).success,false);
});

test('historical selected-field v1 proof cannot silently certify newly required spell coverage',() => {
  const historical=roundtrip(original);
  historical.character.coverage.scope='selected-stable-character-fields-v1';
  const result=compare(historical,historical);
  assert.equal(result.availableEqual,true); assert.equal(result.comparablePolicy,false); assert.equal(result.success,false);
});

test('nested bag contents participate recursively with independent runtime-ID omission',() => {
  const make = n => variant(r => {
    const potion = structuredClone(inventory(r)[1]);
    potion.fields.StackSize.value = n;
    inventory(r)[0].fields.ItemList.value.push(potion);
  });
  assert.equal(compare(make(3),make(4)).success,false);
  const moved = variant(r => {
    const potion = structuredClone(inventory(r)[1]);
    potion.fields.ObjectId.value++;
    inventory(r)[0].fields.ItemList.value.push(potion);
  });
  assert.equal(compare(make(3),moved).success,true);
});

test('raw localized text, language, reference and GFF type remain significant; no TLK lookup',() => {
  const named = variant(r => { r.fields.FirstName.value.entries[0].text = 'Éléonore'; });
  assert.equal(named.character.canonical.identity.FirstName.value.entries[0].text,'Éléonore');
  const language = variant(r => { r.fields.FirstName.value.entries[0].languageId = 1; });
  const reference = variant(r => { r.fields.FirstName.value.strRef = 1234; });
  const width = variant(r => { r.fields.Subrace = F(11,''); });
  for (const p of [named,language,reference,width]) assert.equal(compare(original,p).success,false);
});

test('available uncommon item data retain exact uint64, bytes, and list multiplicity',() => {
  const extra = number => variant(r => {
    const fields = inventory(r)[0].fields;
    fields.ProofInteger = F(6,number);
    fields.ProofBytes = F(13,Uint8Array.of(0,128,255));
  });
  const p = extra(18446744073709551615n);
  const bag = p.character.canonical.inventory.value.find(i => i.fields.ProofInteger);
  assert.deepEqual(bag.fields.ProofInteger.value,{decimal:'18446744073709551615'});
  assert.deepEqual(bag.fields.ProofBytes.value,{hex:'0080ff'});
  assert.equal(compare(p,extra(18446744073709551614n)).success,false);
  assert.doesNotThrow(() => JSON.stringify(p));
});

test('chain compares both actual transfer edges and reports initial server changes without masking',() => {
  const changed = variant(r => { r.fields.Gold.value++; });
  const stable = chain({downloadA:changed,downloadB:changed,finalExport:changed,initial:original});
  assert.equal(stable.success,true); assert.equal(stable.initialComparison.success,false);
  assert.equal(stable.initialComparison.required,false); assert.ok(stable.initialComparison.differenceCount > 0);
  assert.equal(chain({downloadA:changed,downloadB:changed,finalExport:changed,initial:original,requireInitial:true}).success,false);
  assert.equal(chain({downloadA:original,downloadB:changed,finalExport:original}).success,false);
  assert.throws(() => chain({downloadA:original,downloadB:original,finalExport:original,requireInitial:true}),/without initial/);
});

test('projection does not mutate parsed source and returned proof mutation cannot affect another',() => {
  const parsed = parseGff(bytes,'BIC '), before = sha(writeGff('BIC ',typedGff(parsed.root)));
  const a = projectHandoffCharacter(parsed); a.canonical.identity.FirstName.value.entries[0].text = 'Changed';
  assert.equal(sha(writeGff('BIC ',typedGff(parsed.root))),before);
  assert.equal(projectHandoffCharacter(parsed).canonical.identity.FirstName.value.entries[0].text,'Spectorial');
  assert.throws(() => compare(a,original),/hash does not match/);
});

test('rejects malformed/wrong-kind bytes, plain character DTOs and lost parser metadata',() => {
  assert.throws(() => readHandoffCharacter(bytes.subarray(0,40)),/header/);
  const bad = Buffer.from(bytes); bad.write('UTC ');
  assert.throws(() => readHandoffCharacter(bad),/Expected BIC/);
  assert.throws(() => readHandoffCharacter({Race:1}),/bytes/);
  assert.throws(() => projectHandoffCharacter({fileType:'BIC ',version:'V3.2',root:{Race:1}}),/metadata/);
  assert.throws(() => projectHandoffCharacter(roundtrip(parseGff(bytes,'BIC '))),/metadata/);
});

test('installed public preset is unchanged after all proof and negative cases',() => {
  assert.equal(sha(fs.readFileSync(presetPath)),sourceHash);
});
