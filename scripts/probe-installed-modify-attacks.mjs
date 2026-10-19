import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {initializeNumberOfAttacksAsync,initializeAttackActions} from '../src/combat_round.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {creatureRoot} from '../src/creature_rules.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-modify-attacks-v1.json',report={checks:[]};
try{
  const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)});
  await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
  const actor=s.player,cursor=s.registry.nextObjectId[0],begin=runtimeDiagnostics.records.length,originalObjects=new Map(s.registry.objects),initialEquipment=s.equippedItems(actor).map(i=>i.id).sort((a,b)=>a-b),initialBonus=creatureRoot(actor).ClassList.map(c=>[...c.bonusSpellSlots]);
  const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const f={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(f,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'bonus_attacks_'+name),actor.id,{situation:{pc:13,bp:0,stack:f.stack}})).stack[0]?.value;};
  assert.equal(s.vm.api[485].name,'EffectModifyAttacks');
  const attackActions=async()=>{const round=actor.combatRound;round.actions=[];round.additionalAttacks=0;round.length=6000;const count=await initializeNumberOfAttacksAsync(round,actor,s.equippedItems(actor),s.characterRules,(...a)=>s.combat.setCombatMode(...a));initializeAttackActions(round,actor,actor.id);const scheduled=round.actions.filter(a=>a.nativeActionType===1).reduce((n,a)=>n+a.count,0);assert.equal(scheduled,count);const result={count,scheduled,bonus:round.bonusEffectAttacks,groups:round.actions.filter(a=>a.nativeActionType===1).map(a=>({at:a.time,count:a.count}))};round.actions=[];return result;};
  const baseline=await attackActions(),left=await invoke('EffectModifyAttacks',[2]),right=await invoke('EffectModifyAttacks',[4]);assert.equal(left.type,44);
  await invoke('ApplyEffectToObject',[2,left,actor.id,0]);const two=await attackActions();assert.equal(two.count,baseline.count+2);
  await invoke('ApplyEffectToObject',[2,right,actor.id,0]);const capped=await attackActions();assert.equal(capped.bonus,5);assert.equal(capped.count,baseline.count+5);
  await s.effects.remove(actor.id,left.id);const remaining=await attackActions();assert.equal(remaining.bonus,4);assert.equal(remaining.count,baseline.count+4);
  await s.effects.remove(actor.id,right.id);assert.deepEqual(await attackActions(),baseline);
  const invalid=await invoke('EffectModifyAttacks',[6]);assert.equal(invalid.type,0);report.checks.push({check:'NCS-bonus-attacks-stacking-cap-removal-and-real-round-action-groups',baseline,two,capped,remaining});
  const worn=s.registry.get(initialEquipment[0]);assert.ok(worn);const cls=creatureRoot(actor).ClassList[0],oldBonus=cls.bonusSpellSlots[1],oldSlots=actor.nativeTalentClasses[0].memorized[1].length;
  const bonusSlot=await invoke('ItemPropertyBonusLevelSpell',[cls.Class,1]);assert.equal(bonusSlot.type,91);assert.equal(bonusSlot.integers[0],13);
  await invoke('AddItemProperty',[1,bonusSlot,worn.id,60]);assert.equal(cls.bonusSpellSlots[1],oldBonus+1);const addedSlots=actor.nativeTalentClasses[0].memorized[1].length;assert.equal(addedSlots,oldSlots+1);
  await invoke('RemoveItemProperty',[worn.id,bonusSlot]);await s.scheduler.pump();assert.equal(cls.bonusSpellSlots[1],oldBonus);assert.equal(actor.nativeTalentClasses[0].memorized[1].length,oldSlots);assert.ok(!worn.effects.some(e=>e.id===bonusSlot.id));
  report.checks.push({check:'NCS-equipped-bonus-slot-property-add-and-queued-remove',itemId:worn.id,classType:cls.Class,oldBonus,oldSlots,addedSlots});
  const scripts=[],authoredCreations=[],run=s.runScript.bind(s);s.runScript=(name,id,options)=>{scripts.push({name,id});return run(name,id,options);};
  const createItem=s.commands.CreateItemOnObject;s.commands.CreateItemOnObject=async(args,frame)=>{const id=await createItem(args,frame);authoredCreations.push({id,resource:args[0],owner:args[1],script:frame.program.name,pc:frame.pc});return id;};
  const advance=async()=>{s.scheduler.advance(100);s.worldTimer.snapshot();await s.combat.updateTimer(actor,100);if(actor.objectActionState.list.count)await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));await s.scheduler.pump();};
  for(const script of ['nw_s0_divpower','nw_s0_tenstrans']){
    const spellId=s.characterRules.spells.orderedRows.findIndex(row=>String(row.ImpactScript).toLowerCase()===script);assert.ok(spellId>=0);const ids=new Set(actor.effects.map(e=>e.id));
    s.random.seed(1);await invoke('ActionCastSpellAtObject',[spellId,actor.id,0,1]);for(let n=0;n<200;n++){await advance();if(!actor.objectActionState.list.count)break;}
    const effects=actor.effects.filter(e=>!ids.has(e.id)),bonus=effects.filter(e=>e.type===44),row={check:'untouched-installed-impact-through-native-cheat-cast-action',script,spellId,effectTypes:effects.map(e=>e.type),bonus:bonus.map(e=>e.integers[0]),round:await attackActions(),scripts:scripts.splice(0)};report.checks.push(row);
    assert.ok(bonus.length,`${script} must exercise its bonus-attacks constructor`);assert.equal(actor.combatRound.bonusEffectAttacks,Math.min(5,bonus.reduce((n,e)=>(n+e.integers[0])|0,0)));
    for(const id of new Set(effects.filter(e=>(e.durationType&7)!==3).map(e=>e.id)))await s.effects.remove(actor.id,id);
    if(actor.effects.some(e=>e.type===62&&e.spellId===spellId)){s.scheduler.advance(501);s.worldTimer.snapshot();await s.effects.updateObject(actor);await s.scheduler.pump();}
    row.afterRemoval=actor.effects.filter(e=>!ids.has(e.id)).map(e=>({type:e.type,duration:e.durationType,spellId:e.spellId,creatorId:e.creatorId,propertyId:e.propertyId}));
    assert.equal(actor.combatRound.bonusEffectAttacks,0);assert.ok(!actor.effects.some(e=>e.spellId===spellId&&(e.durationType&7)!==3));
    assert.deepEqual(creatureRoot(actor).ClassList.map(c=>c.bonusSpellSlots),initialBonus);assert.deepEqual(s.equippedItems(actor).map(i=>i.id).sort((a,b)=>a-b),initialEquipment);
  }
  for(const [id,object] of originalObjects)assert.equal(s.registry.get(id),object);const remainingNewObjects=[...s.registry.objects.keys()].filter(id=>!originalObjects.has(id));report.canonicalIds={before:cursor,after:s.registry.nextObjectId[0],originalObjectIdentitiesPreserved:true,originalEquipmentRestored:true,authoredCreations,remainingNewObjects:remainingNewObjects.map(id=>{const o=s.registry.get(id);return{id,kind:o.kind,tag:o.tag,template:o.templateResRef,possessor:o.possessorId};})};
  for(const id of remainingNewObjects)assert.ok(authoredCreations.some(c=>c.id===id),'Remaining objects must come from explicit installed-script creation, not leaked form equipment');
  report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);
  report.validation='PASS';report.limits='Installed Prelude and unchanged cleric BIC; actual NCS effect/property constructors, equipped bonus-slot add and queued removal, real combat-round count and attack action-group scheduling, stack cap/removal, ordinary native script cheat cast actions and untouched Divine Power/Tenser scripts. Divine Power produces zero bonus attacks for this preset; Tenser produces two. Initial bonus-slot counters derive from the existing equipment import; runtime mutations use the new native owner. Tenser restoration advances501ms for native delayed removal; original equipment and bonus counters restored, original canonical objects retain identity. Explicit installed-script creation and temporary polymorph equipment advance the canonical cursor. Remaining new objects must have a captured authored CreateItemOnObject call; their complete later lifetime is not proven here. Startup/periodic AI isolated, deterministic seed1. Existing presentation/cache approximation diagnostics retained. No prepared-slot, attack hits/damage/animation, renderer, transport or complete campaign acceptance.';
  await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(x=>({check:x.check,script:x.script,bonus:x.bonus})),diagnostics:report.diagnostics.length}));
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
