import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';
import {parse2da} from '../src/area.js';
import {isSpellFamily,spellFamilyChildren,spellFamilyContains,spellShortcutChoice,spellChoiceBindings} from '../src/spell_family.js';
import {quickbarChoiceMenu} from '../src/quickbar_menu.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {networkSpellUsesLeft,networkSpellLikeShortcutUses} from '../src/network_spellbook.js';
import {buildSpellRadial} from '../src/spell_radial.js';
import {buildSpellLikeRadial} from '../src/spell_like_radial.js';

function fixture(){
 const spells=parse2da('2DA V2.0\n\nName IconResRef Master Innate Wizard TargetType MetaMagic SubRadSpell1 SubRadSpell2 SubRadSpell3 SubRadSpell4\n0 100 parent 0 1 1 3 63 1 2 3 4\n1 101 good 0 1 **** 3 63 **** **** **** ****\n2 102 evil 0 1 **** 3 63 **** **** **** ****\n3 103 law 0 1 **** 3 63 **** **** **** ****\n4 104 chaos 0 1 **** 3 63 **** **** **** ****\n5 105 nested 5 1 1 3 63 6 7 **** ****\n6 106 leaf 5 1 **** 3 63 **** **** **** ****\n7 107 subgroup 5 1 **** 3 63 8 9 **** ****\n8 108 leaf2 5 1 **** 1 63 **** **** **** ****\n9 109 cycle 5 1 **** 3 63 5 -1 999 ****\n'),classes=parse2da('2DA V2.0\n\nSpellCaster MemorizesSpells SpellbookRestricted SpellTableColumn PickDomains\n0 1 1 1 Wizard 1\n'),domains=parse2da('2DA V2.0\n\nLevel_1\n0 0\n1 5\n'),rules={spells,classes,domains},actor={id:7,objectType:5,areaId:1,replicated:{position:[1,2,3],stats:{classes:[{id:0,level:5,domains:[0,1]}]}},playerState:{spellbooks:{0:{memorized:{1:[{spell:0,metamagic:0,domain:0,ready:1}],2:[{spell:0,metamagic:2,domain:1,ready:1}]}}},specialAbilities:[{spell:0,level:5,state:1}]}};
 rules.ruleset=parse2da('2DA V2.0\n\nValue\n0 0\n');return{rules,actor};
}
test('active family rows preserve all four variants, nested groups, gaps and invalid/cyclic definitions',async()=>{
 const {rules}=fixture();assert.deepEqual(spellFamilyChildren(rules,0),[1,2,3,4]);assert.equal(isSpellFamily(rules,0),true);assert.equal(isSpellFamily(rules,1),false);assert.equal(spellFamilyContains(rules,5,8),true);assert.equal(spellFamilyContains(rules,5,5),false);
 const binding={type:2,intParam:0,classIndex:2,metamagic:2,domainLevel:1},choice=await spellShortcutChoice(rules,binding,async id=>({label:'Spell '+id}));assert.equal(choice.binding,undefined);assert.deepEqual([...spellChoiceBindings([choice])],[1,2,3,4].map(intParam=>({...binding,intParam})));
 const nested=await spellShortcutChoice(rules,{...binding,intParam:5},async id=>({label:String(id)}));assert.deepEqual([...spellChoiceBindings([nested])].map(b=>b.intParam),[6,8]);const radial=quickbarChoiceMenu(choice.label,choice.children,'spell.variant');assert.ok(radial.entries.every(e=>e.action==='spell.variant'&&e.binding.intParam!==0));
 const other={...rules,spells:parse2da('2DA V2.0\n\nMaster SubRadSpell1 SubRadSpell2\n0 0 2 ****\n1 1 **** ****\n2 0 **** ****')};assert.deepEqual(spellFamilyChildren(other,0),[2]);assert.deepEqual(spellFamilyChildren(rules,0),[1,2,3,4]);
});
test('a family parent only opens the chooser; only selected children can reach casting',async()=>{
 const {rules,actor}=fixture(),world={localObjectId:actor.id,registry:new Map([[actor.id,actor]])},sent=[],chosen=[],binding={type:2,intParam:0,classIndex:0,metamagic:2,domainLevel:1},before=structuredClone(actor),t=new NetworkSpellTargeting({world:()=>world,tables:()=>rules,context:()=>({areaGeneration:1}),chooseFamily:async b=>{chosen.push(b);return{choosingVariant:true};},submit:async request=>sent.push(request)});
 await t.begin(binding);assert.deepEqual(chosen,[binding]);assert.equal(t.active,false);assert.deepEqual(sent,[]);
 await assert.rejects(t.radial({spellId:0},actor,[0,0,0]),/variant/);await assert.rejects(t.radialInnate({spellId:0},actor,[0,0,0]),/variant/);
 await t.begin({...binding,intParam:3});await t.select(actor,[1,2,3]);assert.equal(sent[0].spellId,3);assert.equal(sent[0].classIndex,0);assert.equal(sent[0].metamagic,2);assert.equal(sent[0].domainLevel,1);assert.deepEqual(actor,before);
});
test('variant shortcuts read the shared prepared/innate pool without adding or spending uses',()=>{
 const {rules,actor}=fixture(),before=structuredClone(actor);
 for(const id of [1,2,3,4])assert.equal(networkSpellUsesLeft(actor,rules,id,0,0,0),1);
 for(const id of [1,2,3,4])assert.equal(networkSpellLikeShortcutUses(actor,rules,id,5),1);
 assert.deepEqual(actor,before);actor.playerState.spellbooks[0].memorized[1][0].ready=0;actor.playerState.specialAbilities[0].state=0;
 for(const id of [1,2,3,4]){assert.equal(networkSpellUsesLeft(actor,rules,id,0,0,0),0);assert.equal(networkSpellLikeShortcutUses(actor,rules,id,5),0);}
});
test('ordinary and innate radials descend into families while leaves keep source class/domain/metamagic',()=>{
 const {rules,actor}=fixture(),native={...actor,authored:{ClassList:[{Class:0}]},nativeTalentClasses:[{memorized:Array.from({length:10},(_,level)=>level===1?[{id:0,metamagic:0,domain:0,ready:1},{id:5,metamagic:0,domain:0,ready:1}]:[]),known:Array.from({length:10},()=>[])}],nativeSpellLikeAbilities:[{id:0,casterLevel:5,remaining:1}]},p={name:(_table,id)=>String(id),hasFeat:()=>false,spellGain:()=>1,readyForConversion:()=>false},book={uses:()=>1,metamagicCost:()=>0,level:()=>1};
 const menu=buildSpellRadial(native,native,rules,book,p).entries.find(e=>e.slot===5).children().entries.find(e=>e.slot===1).children(),family=menu.entries[0];assert.equal(family.action,undefined);assert.deepEqual(family.children().entries.map(e=>e.binding.spellId),[1,2,3,4]);assert.equal(family.children().entries[2].binding.classIndex,0);
 const nested=menu.entries[1].children().entries[1].children().entries[0];assert.equal(nested.binding.spellId,8);
 const innate=buildSpellLikeRadial(native,native,rules,p).entries[0];assert.equal(innate.action,undefined);assert.deepEqual(innate.children().entries.map(e=>e.binding.spellId),[1,2,3,4]);assert.ok(innate.children().entries.every(e=>e.binding.domainLevel===5));
});

test('production local cast entry opens the family chooser before targeting and leaves item input on its own route',async()=>{
 const source=await fs.readFile(new URL('../src/main.js',import.meta.url),'utf8');
 const handler=name=>source.slice(source.indexOf(`function ${name}(`),source.indexOf('\nfunction ',source.indexOf(`function ${name}(`)+1));
 const {rules}=fixture(),opened=[],notices=[],plans=[],errors=[],session={characterRules:rules,player:{id:7,areaId:1},registry:new Map([[20,{id:20}]]),report:error=>errors.push(error)};
 const context={moduleSession:session,isSpellFamily,spellShortcutChoice,quickbarChoiceMenu,cancelSpellTarget:()=>{},canvas:{getBoundingClientRect:()=>({left:0,top:0,width:800,height:600})},radialMenu:{open:(...args)=>opened.push(args)},gameUi:{ruleName:(_table,id)=>String(id),notify:message=>notices.push(message),state:{}},prepareSpellTarget:(_player,request)=>{plans.push(request);return{mode:'unavailable'};},spellTargetProviders:()=>({}),isPlayerInventoryItem:()=>true,runtimeDiagnostics:{record:()=>{}}};
 vm.createContext(context);vm.runInContext(handler('beginSpellCast')+'\n'+handler('beginItemUse'),context);
 const request={action:'spell.cast',actorId:7,areaId:1,spellId:0,classIndex:0,metamagic:2,domainLevel:1};context.beginSpellCast(request);
 await new Promise(resolve=>setImmediate(resolve));assert.deepEqual(errors,[]);assert.equal(plans.length,0);assert.equal(opened.length,1);assert.equal(opened[0][3].request,request);assert.deepEqual(opened[0][0].entries.map(e=>e.binding.intParam),[1,2,3,4]);
 context.beginSpellCast({...request,spellId:3});assert.equal(plans.length,1);assert.equal(plans[0].spellId,3);
 assert.doesNotThrow(()=>context.beginItemUse({actorId:7,areaId:1,itemId:20,propertyIndex:255}));assert.equal(opened.length,1);assert.match(notices.at(-1),/item shortcut/i);
 // A delayed family lookup must not open after changing the session/area.
 context.beginSpellCast(request);context.moduleSession={...session};await new Promise(resolve=>setImmediate(resolve));assert.equal(opened.length,1);
});
