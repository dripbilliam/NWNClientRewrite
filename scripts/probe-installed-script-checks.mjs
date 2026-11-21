import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {skillNameReference} from '../src/script_checks.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-script-checks-v1.json',report={queries:[],authored:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),character=await fs.readFile(`${install}/data/lcv/cleric.bic`);
 for(const mode of['queries','resist','copy-and-remove','hardcore-destroy','already-ruined']){
  const messages=[],s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize([],{character});
  const target=s.player,caster=s.byTag('M1Q0D19Goblin').find(o=>!o.plot&&!s.isDead(o));assert.ok(caster);await s.enterArea(s.registry.get(caster.areaId).resRef,[caster.position[0]+2,caster.position[1],caster.position[2]]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
  const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r?.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const bytes=Buffer.alloc(20);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(20,9);bytes.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);const result=await s.vm.run(parseNcs(bytes,'script_check_probe'),target.id,{situation:{pc:13,bp:0,stack:frame.stack}});assert.equal(result.stack.length,1);return result.stack[0].value;};
  const begin=runtimeDiagnostics.records.length;
  if(mode==='queries'){
   for(const r of s.equippedItems(target)){const item=s.registry.get(r.id),expected=item.passiveProperties.reduce((n,p)=>(n+((p.type&65535)===1?p.costValue&65535:0))|0,item.nativeBaseArmor35c);assert.equal(await invoke('GetItemACValue',[item.id]),expected);report.queries.push({kind:'item-ac',id:item.id,value:expected});}
   assert.equal(await invoke('GetItemACValue',[target.id]),0);assert.equal(await invoke('GetItemACValue',[0x12345678]),0);
   const item=s.registry.get(s.equippedItems(target)[0].id),before=await invoke('GetItemACValue',[item.id]);item.passiveProperties.push({type:1,costValue:2},{type:1,costValue:3},{type:2,costValue:99});assert.equal(await invoke('GetItemACValue',[item.id]),before+5);item.passiveProperties.splice(-3);assert.equal(await invoke('GetItemACValue',[item.id]),before);report.queries.push({kind:'live-passive-pool',before,after:before+5});
   const skill=3,rank=await s.combat.skill(target,skill,null,0),dice=s.random.dice;let rolls=0;const cursor=s.registry.nextObjectId[0];
   for(const[id,sk,dc,roll,expected,classification]of[[target.id,skill,rank+1,1,1,1],[target.id,skill,rank+20,1,0,0],[target.id,skill,rank+21,20,0,3],[target.id,skill,rank+20,20,1,1],[target.id,254,1,1,1,1],[0x12345678,skill,0,1,1,null],[s.currentArea.id,skill,1,1,0,null],[target.id,255,-1,1,1,null],[target.id,256,1,1,0,null]]){
    const start=messages.length,priorRolls=rolls;s.random.dice=(n,d)=>{assert.deepEqual([n,d],[1,20]);rolls++;return roll;};assert.equal(await invoke('GetIsSkillSuccessful',[id,sk,dc]),expected);const skillMessages=messages.slice(start).filter(m=>m.type===9);
    if(classification!==null){const actualRank=await s.combat.skill(target,sk,null,0);assert.equal(rolls,priorRolls+1);assert.ok(skillMessages.length);for(const message of skillMessages){assert.deepEqual(message.data.objects,[target.id]);assert.deepEqual(message.data.integers,[skillNameReference(s.characterRules.skills,sk),roll,actualRank,dc,0,classification]);}}
    else{assert.equal(rolls,priorRolls);assert.equal(skillMessages.length,0);}report.queries.push({kind:'skill-check',id,skill:sk,rank:classification!==null?await s.combat.skill(target,sk,null,0):null,roll,dc,result:expected,classification});
   }
   s.random.dice=dice;assert.equal(s.registry.nextObjectId[0],cursor);report.queryDiagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.queryDiagnostics.filter(d=>d.severity==='error'),[]);continue;
  }
  const armor=s.registry.get(s.equipmentSlot(target,2)?.id),weapon=s.registry.get(s.equippedItems(caster).find(r=>r.slot===16)?.id);assert.ok(armor);assert.ok(weapon);armor.locals.setInt('ruin_copy_marker',23);if(mode==='already-ruined')armor.locals.setInt('X2_L_BEB_RUINED',1);if(mode==='hardcore-destroy')s.module.locals.setInt('X2_SWITCH_BEBILITH_HARDCORE_RUIN_ARMOR',1);
  const rank=await s.combat.skill(target,3,null,0),dc=(await s.commands.GetBaseAttackBonus([caster.id]))+(await s.commands.GetAbilityModifier([0,caster.id]))+8-(await invoke('GetItemACValue',[weapon.id]));assert.ok(dc>0);assert.ok(rank+1<dc&&rank+20>=dc,`Fixture rank${rank}/DC${dc} must exercise both real outcomes`);
  const rolls=[];s.random.dice=(n,d)=>{assert.equal(n,1);assert.ok([4,20].includes(d));const value=d===20?(mode==='resist'?20:1):1;rolls.push({n,d,value});return value;};const spell=s.spellBook.castingSpell(756);assert.equal(spell.impactScript.toLowerCase(),'x2_s3_ruinarmor');
  const beforeIds=new Set(s.registry.objects.keys());s.combat.enqueueEvent(19,caster.id,caster.id,0,{spellId:spell.id,casterId:caster.id,targetId:target.id,itemId:weapon.id,featId:65535,casterLevel:1,position:[target.position[0],-target.position[2],target.position[1]],script:spell.impactScript});await s.scheduler.pump();
  const copied=[...s.registry.objects.values()].filter(o=>o.objectType===6&&!beforeIds.has(o.id)&&o.tag===armor.tag);
  if(mode==='resist'||mode==='already-ruined'){assert.equal(s.registry.get(armor.id),armor);assert.equal(s.equipmentSlot(target,2),armor);assert.equal(copied.length,0);}
  else{assert.equal(s.registry.get(armor.id),undefined);assert.equal(s.equipmentSlot(target,2),null);if(mode==='copy-and-remove'){assert.equal(copied.length,1);assert.equal(copied[0].possessorId,target.id);assert.ok([...target.nativeRepository.ids()].includes(copied[0].id));assert.ok(!target.nativeEquipment.contains(copied[0]));assert.equal(copied[0].locals.getInt('ruin_copy_marker'),23);assert.equal(copied[0].locals.getInt('X2_L_BEB_RUINED'),0);}else assert.equal(copied.length,0);}
  const diagnostics=runtimeDiagnostics.records.slice(begin);report.authored.push({mode,script:spell.impactScript,caster:caster.id,target:target.id,armor:armor.id,copies:copied.map(i=>i.id),dc,rank,rolls,messages:messages.filter(m=>m.type===9||m.type===11||m.type==='inventory-unequipped'),diagnostics});assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
 }
 report.validation='PASS';report.limits='Installed Prelude/cleric/goblin/live item passive pools and effective skill ranks, actual VM queries and untouched installed ruin-armor NCS through event19. Four script outcomes use controlled dice, module switch and item locals; general AI/startup isolated. No per-spell outcome JS, save/protocol/render/full campaign acceptance. All diagnostics retained.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,queries:report.queries.length,authored:report.authored.map(r=>r.mode),error:report.error}));
