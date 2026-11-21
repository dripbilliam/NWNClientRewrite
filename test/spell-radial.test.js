import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parse2da} from '../src/area.js';
import {createSpellClassState} from '../src/spell_book.js';
import {buildSpellRadial,radialSpellCastRequest,radialSpellTargetAllowed} from '../src/spell_radial.js';

test('radial target masks and selected cast fields match untouched native client instructions',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-radial-observations.json',import.meta.url))),actor={id:99,areaId:1};
  for(const {case:c,result} of oracle.rows){
    const target=c.type===null?null:{id:c.self&&c.type===5?99:100,objectType:c.type};
    assert.equal(Number(radialSpellTargetAllowed(c.missing?null:{targetType:c.mask},actor,target,c.filter)),result,JSON.stringify(c));
  }
  for(const {case:c,calls} of oracle.selections){
    const request=radialSpellCastRequest(c,actor,{id:99},[1.25,2.5,3.75]);
    const {spellId,classIndex,domainLevel,metamagic,spontaneous,targetId,position}=request;
    assert.deepEqual([{spellId,classIndex,domainLevel,metamagic,spontaneous,targetId,position}],calls,JSON.stringify(c));
  }
  assert.equal(radialSpellCastRequest({spellId:0,classIndex:0,metamagic:0,domainLevel:0},actor,null,[0,0,0]).location,0);
  const ground=radialSpellCastRequest({spellId:0,classIndex:0,metamagic:0,domainLevel:0},actor,null,[1,2,3]);
  assert.equal(ground.targetId,0x7f000000);assert.equal(ground.location,1);
});

function fixture(){
  const rules={classes:parse2da('2DA V2.0\n\nSpellCaster MemorizesSpells SpellbookRestricted CanCastSpontaneously Icon\n0 0 0 0 0 fighter\n1 1 1 1 1 cleric\n2 1 0 1 0 sorcerer'),
    spells:parse2da('2DA V2.0\n\nIconResRef TargetType MetaMagic SpontaneouslyCast Master Innate SubRadSpell1 SubRadSpell2\n0 light 3 63 0 0 0 **** ****\n1 heal 3 63 1 1 1 **** ****\n2 parent 3 63 0 2 1 3 4\n3 child1 3 63 0 2 1 **** ****\n4 child2 4 63 0 2 1 **** ****\n5 item 8 63 0 5 2 **** ****')};
  const actor={id:1,objectType:5,areaId:2,authored:{ClassList:[{Class:0},{Class:1}]},nativeTalentClasses:[createSpellClassState(),createSpellClassState()]};
  const state=actor.nativeTalentClasses[1],uses=new Map([[0,2],[1,0],[2,1],[5,1]]),feats=new Set([12]);
  const book={metamagicCost:meta=>meta===2?1:0,uses:(_o,id)=>uses.get(id)??0,level:()=>1};
  const p={name:(table,id)=>`${table} ${id}`,hasFeat:(_o,id)=>feats.has(id),spellGain:()=>1,
    readyForConversion:(_o,index,level)=>actor.nativeTalentClasses[index].memorized[level].some(row=>row&&row.ready!==0&&row.domain===0)};
  state.memorized[1]=[{id:0,metamagic:0,domain:0,ready:1},{id:0,metamagic:0,domain:0,ready:1},
    {id:1,metamagic:0,domain:0,ready:0},{id:2,metamagic:0,domain:0,ready:1}];
  state.memorized[2]=[{id:5,metamagic:2,domain:1,ready:1}];
  return {rules,actor,state,book,p,uses,feats,build:(target=actor)=>buildSpellRadial(actor,target,rules,book,p)};
}
const child=(menu,slot)=>menu.entries.find(e=>e.slot===slot).children();

test('item radial keeps ordinary class grouping and applies native item-only filter8 to live spell choices',()=>{
 const f=fixture(),item={id:9,objectType:6},root=buildSpellRadial(f.actor,item,f.rules,f.book,f.p,{filter:8});
 assert.equal(root.entries.find(e=>e.slot===4).label,'classes 1');
 const ordinary=child(child(root,4),1);assert.ok(ordinary.entries.filter(e=>e.binding).every(e=>e.disabled));
 const itemSpell=child(child(root,4),2).entries.find(e=>e.binding?.spellId===5);
 assert.equal(itemSpell.disabled,false);assert.equal(itemSpell.binding.classIndex,1);assert.equal(itemSpell.binding.domainLevel,1);
 f.uses.set(5,0);assert.equal(child(child(buildSpellRadial(f.actor,item,f.rules,f.book,f.p,{filter:8}),4),2).entries.find(e=>e.binding?.spellId===5).disabled,true);
});
test('live radial retains native class slots, domain context, children and conversion eligibility',()=>{
  const f=fixture(),root=f.build();
  assert.deepEqual(root.entries.map(e=>e.slot),[4,0,6]);
  const level=child(child(root,4),1);
  assert.equal(level.entries.filter(e=>e.binding?.spellId===0).length,1,'duplicate prepared slots collapse to one choice');
  const converted=level.entries.find(e=>e.binding?.spellId===1);
  assert.equal(converted.binding.classIndex,1);assert.equal(converted.binding.spontaneous,1);assert.equal(converted.disabled,false);
  const children=level.entries.find(e=>e.children).children();
  assert.equal(children.entries[0].binding.spellId,3);assert.equal(children.entries[0].disabled,false);assert.equal(children.entries[1].disabled,true);
  const meta=child(child(root,0),6),domain=child(meta,2).entries[0];
  assert.deepEqual(domain.binding,{spellId:5,classIndex:1,metamagic:2,domainLevel:1,spontaneous:0});assert.equal(domain.disabled,true,'item-only spell disabled on self');
  for(const row of f.state.memorized[1])row.ready=0;
  assert.equal(child(child(f.build(),4),1).entries.find(e=>e.binding?.spellId===1).disabled,true,'reopening uses changed live resources');
  f.rules.spells.orderedRows[5].TargetType='1';
  // Ordered cells own parsing when available, so replace the active table,
  // just as a new resolver supplies a new physical resource.
  f.rules.spells=parse2da('2DA V2.0\n\nIconResRef TargetType MetaMagic Master Innate\n0 light 3 63 0 0\n1 heal 3 63 1 1\n2 parent 3 63 2 1\n3 child1 3 63 2 1\n4 child2 4 63 2 1\n5 item 1 63 5 2');
  assert.equal(child(child(child(f.build(),0),6),2).entries[0].disabled,false);
});

test('nonmemorizing caster uses active known pools and spell gain; high levels paginate through native slot7',()=>{
  const f=fixture();f.actor.authored.ClassList=[{Class:2}];f.actor.nativeTalentClasses=[createSpellClassState()];
  const state=f.actor.nativeTalentClasses[0];state.known[1]=[0,1,2];
  let gain=1;f.p.spellGain=()=>gain;
  assert.equal(child(child(f.build(),5),1).entries.length,3);
  gain=0;assert.equal(child(child(f.build(),5),1).entries.length,0);
  gain=1;state.known[7]=[0,1,2,3,4,5,0,1,2];state.known[8]=[0,1];
  assert.equal(child(child(f.build(),5),7).entries.length,6,'duplicate IDs collapse across levels7–9');
});
