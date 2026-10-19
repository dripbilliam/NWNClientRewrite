import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {advanceLocalClocks,advanceToEffectExpiry} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {parseGff} from '../src/gff.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {intEntry} from '../src/combat_stats.js';

const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const owner=s.byTag('M1Q0D19Goblin').find(o=>o.objectType===5),player=s.player;
await s.enterArea(s.registry.get(owner.areaId).resRef,[owner.position[0]+2,owner.position[1],owner.position[2]]);
await s.combat.updatePerception(player,owner,1);s.scheduler.events=[];
let template;
for(const e of [...s.resolver.key.resources.values()].filter(e=>e.resourceType===RESOURCE_TYPE.UTI&&/^nw_cloth/.test(e.resref)).sort((a,b)=>a.resref.localeCompare(b.resref))){
 const data=parseGff(await s.resolver.getResource(e.resref,RESOURCE_TYPE.UTI),'UTI ').root;
 if(data.BaseItem===16&&!data.PropertiesList?.length){template=e.resref;break;}
}
assert.ok(template,'installed plain clothing fixture');
const itemId=await s.createItem(template,owner.id,1,''),item=s.registry.get(itemId),start=runtimeDiagnostics.records.length;
const gear=async equip=>{await s.combat.clearActions(owner);owner.combatRound.started=false;await s.commands[equip?'ActionEquipItem':'ActionUnequipItem'](equip?[itemId,1]:[itemId],{self:owner.id});await s.combat.runActions(owner,...Object.values(s.worldTimer.time()));assert.equal(s.equipmentSlot(owner,2),equip?item:null);};
await gear(true);const baseline=s.commands.GetAC([owner.id]),impactScript='x2_s0_magcvest',spell=s.characterRules.spells.orderedRows.map((_,id)=>s.spellBook.castingSpell(id)).find(v=>v?.impactScript.split('\0')[0].toLowerCase()===impactScript);assert.ok(spell);
const impacts=[],animations=[],errors=[],run=s.runScript.bind(s);
const engineCalls=[],names=new Set([...(await s.program(impactScript)).instructions.values()].filter(i=>i.op===5).map(i=>s.vm.api[i.command]?.name));
for(const name of names){const original=s.commands[name];if(typeof original==='function')s.commands[name]=async(args,...rest)=>{const result=await original(args,...rest);engineCalls.push({name,args,result:result?.type!==undefined?{type:result.type,integers:result.integers}:result});return result;};}
s.runScript=async(name,id,options)=>{if(String(name).split('\0')[0].toLowerCase()===impactScript)impacts.push({name,id,at:s.scheduler.time});return run(name,id,options);};
// Magic Vestment's active row targets items. Cast the owner's carried armor
// through its public scripted-casting form, preserving ordinary item admission.
await s.commands.ActionCastSpellAtObject([spell.id,itemId,0,1,0,0,0,-1,0],{self:owner.id});
for(let n=0;n<200;n++){
 s.scheduler.advance(100);s.worldTimer.snapshot();
 try{await s.combat.runActions(owner,...Object.values(s.worldTimer.time()));}catch(e){errors.push(e.message);break;}
 animations.push(owner.animationState);
 while(s.scheduler.events[0]?.due<=s.scheduler.time){const event=s.scheduler.events.shift();try{await s.dispatch(event);}catch(e){errors.push(e.message);}}
 if(!owner.objectActionState.list.count&&impacts.length)break;
}
const properties=item.effects.filter(e=>e.type===91&&e.spellId===spell.id),linked=owner.effects.filter(e=>e.creatorId===itemId),after=s.commands.GetAC([owner.id]);
const report={template,itemId,ownerId:owner.id,spell,baseline,after,impacts,animations:[...new Set(animations)],errors,engineCalls,properties:structuredClone(properties),linked:structuredClone(linked),limits:'Installed clothing and authored Magic Vestment NCS via scripted cheat=1 request, queued gear actions and real stat/expiry owners. Startup/AI isolated; not memorized UI or full campaign acceptance. All diagnostic warnings retained.'};
const save=()=>fs.writeFile(process.argv.find(a=>a.startsWith('--output='))?.slice(9)??'backups/animations/live-authored-armor-buff.json',JSON.stringify({...report,diagnostics:runtimeDiagnostics.records.slice(start)},null,2));await save();console.log(JSON.stringify(report,null,2));
assert.deepEqual(errors,[]);assert.equal(impacts.length,1);assert.equal(owner.objectActionState.list.count,0);assert.equal(properties.length,1);assert.deepEqual(linked.map(e=>e.type),[48,67]);assert.equal(linked[1].integers[0],35);assert.equal(linked[0].id,linked[1].id);
const property=properties[0],expected=intEntry(await s.items.costTable(2),property.integers[3]&65535,'Value').value;
assert.equal(after,baseline+expected);assert.equal(linked[0].propertyId,property.propertyId);assert.equal(linked[0].integers[0],s.items.baseInfo(item).acEnchant);
await gear(false);assert.equal(owner.effects.filter(e=>e.creatorId===itemId).length,0);await gear(true);assert.equal(s.commands.GetAC([owner.id]),baseline+expected);
advanceToEffectExpiry(s,property);await s.effects.updateObject(item);assert.ok(item.effects.includes(property));advanceLocalClocks(s,1);await s.effects.updateObject(item);assert.ok(!item.effects.includes(property));assert.equal(s.commands.GetAC([owner.id]),baseline);assert.equal(owner.effects.filter(e=>e.creatorId===itemId).length,0);
report.cleanup={unequipReequip:true,exactExpiryRetained:true,expired:true,restoredAC:s.commands.GetAC([owner.id])};await save();
assert.deepEqual(runtimeDiagnostics.records.slice(start).filter(d=>d.severity==='error'),[]);
