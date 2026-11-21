import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-curse-ethereal-v1.json',report={checks:[]};
try{
  const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)});
  await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
  const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0],actor=s.player,observer=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==actor&&o.areaId===actor.areaId);assert.ok(observer);
  const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);return(await s.vm.run(parseNcs(ncs,'effects_'+name),actor.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0]?.value;};
  const advance=async()=>{s.scheduler.advance(100);s.worldTimer.snapshot();await s.combat.updateTimer(actor,100);if(actor.objectActionState.list.count)await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));await s.scheduler.pump();};
  const scripts=[],runScript=s.runScript.bind(s);s.runScript=(name,id,options)=>{scripts.push({name,id});return runScript(name,id,options);};
  const scores=()=>{s.refreshCombat(actor);return ['Str','Dex','Con','Int','Wis','Cha'].map(n=>actor.stats.equippedAbilities[n]);};
  const before=scores(),curse=await invoke('EffectCurse',[2,2,2,2,2,2]);assert.equal(curse.type,45);
  await invoke('ApplyEffectToObject',[2,curse,actor.id,0]);
  assert.ok(actor.effects.some(e=>e.id===curse.id&&e.type===45));assert.ok(!actor.effects.some(e=>e.id===curse.id&&e.type===37&&e.integers[0]===2));
  const immediate=scores();assert.equal(immediate[2],before[2]);assert.equal(immediate[0],before[0]-2);
  await s.scheduler.pump();
  const after=scores();assert.deepEqual(after,before.map(n=>Math.max(3,n-2)));assert.ok(actor.effects.some(e=>e.id===curse.id&&e.type===37&&e.integers[0]===2));assert.ok(actor.nativeEffectIcons778.records.some(e=>e.iconId===22));
  await s.effects.remove(actor.id,curse.id);assert.ok(!actor.effects.some(e=>e.id===curse.id));assert.deepEqual(scores(),before);assert.ok(!actor.nativeEffectIcons778.records.some(e=>e.iconId===22));
  report.checks.push({check:'NCS-Curse-six-attributes-deferred-CON-and-shared-ID-cleanup',before,immediate,after});
  observer.perception.set(actor.id,1);observer.attackActionTargetId=actor.id;observer.nativeField700=1;const ethereal=await invoke('EffectEthereal',[]);assert.equal(ethereal.type,63);assert.equal(ethereal.integers[5],0);
  await invoke('ApplyEffectToObject',[2,ethereal,actor.id,0]);assert.equal(observer.perception.get(actor.id)&12,4);assert.equal(observer.nativeField700,0);assert.ok(s.module.nativeInvisibleCreatureIds330.includes(actor.id));assert.ok(actor.nativeEffectIcons778.records.some(e=>e.iconId===107));
  await s.effects.remove(actor.id,ethereal.id);assert.ok(!s.module.nativeInvisibleCreatureIds330.includes(actor.id));assert.ok(!actor.nativeEffectIcons778.records.some(e=>e.iconId===107));report.checks.push({check:'NCS-Ethereal-no-save-pacify-visibility-icon-cleanup'});
  const enemy=[...s.registry.objects.values()].find(o=>o.objectType===5&&/goblin/i.test(o.tag)&&!o.plot&&!s.isDead(o)&&s.aiReaction(actor,o.id)===2);assert.ok(enemy,'Installed hostile goblin is required');
  const enemyArea=s.registry.get(enemy.areaId);assert.ok(enemyArea);await s.enterArea(enemyArea.resRef,[...enemy.position]);
  s.scheduler.events=[];scripts.length=0;actor.perception.set(enemy.id,1);
  for(const [script,type] of [['nw_s0_bescurse',45],['x0_s0_ether',63]]){
    const spellId=s.characterRules.spells.orderedRows.findIndex(row=>String(row.ImpactScript).toLowerCase()===script);assert.ok(spellId>=0);let found=false;const attempts=[];
    const target=type===45?enemy:actor;
    report.checks.push({check:'untouched-installed-impact-script-through-native-cheat-cast-action',spellId,script,targetId:target.id,targetTag:target.tag,area:enemyArea.resRef,attempts});
    for(let seed=1;seed<=8&&!found;seed++){
      s.random.seed(seed);const baseline=runtimeDiagnostics.records.length;
      await invoke('ActionCastSpellAtObject',[spellId,target.id,0,1]);
      for(let n=0;n<200;n++){await advance();if(!actor.objectActionState.list.count)break;}
      const effects=target.effects.filter(e=>e.spellId===spellId),parent=effects.find(e=>e.type===type);attempts.push({seed,parent:Boolean(parent),effectTypes:effects.map(e=>e.type),scripts:scripts.splice(0),diagnostics:runtimeDiagnostics.records.slice(baseline)});
      if(parent){found=true;await s.scheduler.pump();await s.effects.remove(target.id,parent.id);assert.ok(!target.effects.some(e=>e.id===parent.id));}
    }
    assert.ok(found,`${script} did not produce its native parent effect`);
  }
  assert.equal(s.registry.nextObjectId[0],cursor);report.diagnostics=runtimeDiagnostics.records.slice(begin);
  const failures=report.diagnostics.filter(r=>r.severity==='error');report.knownLoadFailures=failures.filter(r=>r.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&r.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.');report.newFailures=failures.filter(r=>!report.knownLoadFailures.includes(r));assert.deepEqual(report.newFailures,[]);
  report.validation='PASS';report.limits='Installed Prelude/cleric, actual NCS constructors/application, real ability caches and shared-ID removal; ordinary action/timing with explicit native script cheat casts through untouched Bestow Curse/Ethereal scripts and hostile goblin SpellCastAt callback. Initial observer perception/attack and caster visibility are authored deterministic fixtures. Normal self-target Bestow Curse is rejected by the installed friendly-target script; a visible hostile goblin is used. Deterministic RNG permits normal saving throws. Startup/periodic AI isolated; queued area-entry events discarded. Known absent plc_w02.pwk remains recorded separately. No prepared-slot, renderer, full campaign/network acceptance claim.';
  await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>({check:c.check,script:c.script,attempts:c.attempts?.length})),diagnostics:report.diagnostics.length}));
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
