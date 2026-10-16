import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {selectInstalledLearnableScrolls} from './select-installed-scrolls.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {intEntry} from '../src/combat_stats.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-spell-preparation-v1.json',report={rows:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];const actor=s.player,choice=(await selectInstalledLearnableScrolls(s))[0];report.choice=choice;report.playerId=actor.id;
 const itemId=await s.createItem(choice.template,actor.id,1,'');s.scheduler.events=[];await s.items.inputLearn({itemId});assert.equal(s.items.lastLearnScroll.result,1);
 const pool=actor.nativeTalentClasses[choice.classIndex].memorized[choice.level];assert.ok(pool.length);const length=pool.length,capacity=actor.nativeTalentClasses[choice.classIndex].memorizedCapacity[choice.level];
 assert.ok(s.spellBook.preparationSpells(actor,choice.classIndex,choice.level).some(row=>row.id===choice.spellId));
 const input=async request=>{const start=runtimeDiagnostics.records.length,p=s.queuePlayerSpellPreparation(request);await s.drainPlayerInputs();assert.equal(await p,0);const errors=runtimeDiagnostics.records.slice(start).filter(r=>r.severity==='error');assert.deepEqual(errors,[]);report.rows.push({request,slots:structuredClone(pool),diagnostics:runtimeDiagnostics.records.slice(start)});};
 await input({clear:true,classIndex:choice.classIndex,level:choice.level,slot:0});assert.equal(pool[0],null);assert.equal(pool.length,length);assert.equal(actor.nativeTalentClasses[choice.classIndex].memorizedCapacity[choice.level],capacity);
 await input({classIndex:choice.classIndex,spellId:choice.spellId,slot:0,domainLevel:0,metamagic:0});assert.deepEqual(pool[0],{id:choice.spellId,ready:0,metamagic:0,domain:0});
 const before=structuredClone(pool);await input({classIndex:choice.classIndex,spellId:choice.spellId,slot:255,domainLevel:0,metamagic:0});assert.deepEqual(pool,before);
 const sources=[];for(let level=0;level<10;level++)sources.push({level,spells:s.spellBook.preparationSpells(actor,choice.classIndex,level)});report.sources=sources;
 report.divine=[];
 for(const preset of ['cleric','druid','paladin','ranger']){
  const divine=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/${preset}.bic`)}),actor=divine.player,rows=[];
  for(const [index,c]of (actor.creatureData??actor.authored).ClassList.entries()){
   if(intEntry(divine.characterRules.classes,c.Class,'MemorizesSpells').value===0)continue;
   for(let level=0;level<10;level++){const spells=divine.spellBook.preparationSpells(actor,index,level);if(spells.length)rows.push({index,type:c.Class,level,spells});}
  }
  assert.ok(rows.length,`${preset} must expose active class spells`);
  const domains=rows.flatMap(row=>row.spells.filter(s=>s.domain!==0).map(spell=>({...spell,index:row.index,level:row.level})));
  if(preset==='cleric'){assert.ok(domains.length);const spell=domains.find(s=>s.level>0&&actor.nativeTalentClasses[s.index].memorized[s.level].length);assert.ok(spell);
   const input=divine.queuePlayerSpellPreparation({classIndex:spell.index,spellId:spell.id,slot:0,domainLevel:spell.level,metamagic:0});await divine.drainPlayerInputs();assert.equal(await input,0);assert.deepEqual(actor.nativeTalentClasses[spell.index].memorized[spell.level][0],{id:spell.id,ready:0,metamagic:0,domain:1});
  }
  report.divine.push({preset,rows,domains});
 }
 report.limits='Unchanged installed wizard and scroll selected from active rules, shared creation/acquisition/learning, new known source, queued native clear/set, preserved slot storage and unready new preparation. General AI/startup/module events isolated. Rest, renderer, cast-after-rest, save/reload, native GUI/packet equivalence and campaign remain separate acceptance gates.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({choice:report.choice,playerId:report.playerId,rows:report.rows.length,failure:report.failure}));if(report.failure)process.exitCode=1;
