// Actual active race feat resources and shared innate vision effect lifecycle.
// Constructor/context checks are direct APIs; no full polymorph cast is claimed.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {isFirstLevelRacialFeat} from '../src/racial_effect.js';
import {parseNcs} from '../src/ncs.js';
const [install,modulePath,output='backups/animations/installed-polymorph-effects-v1.json']=process.argv.slice(2),report={races:[],constructors:[]};
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)}),o=s.player,root=o.creatureData,stats=o.stats,identity=o.id,authoredRace=root.Race;
await s.enterArea('m0q1d',o.position);report.loadDiagnostics=[...runtimeDiagnostics.records];const start=runtimeDiagnostics.records.length;s.scheduler.events=[];
try{
 o.nativeSpellClass22c=0;o.nativeSpellFeat23c=65535;o.nativeSpellMetamagic22d=0;o.nativeSpellDomain21c=0;
 const classType=root.ClassList[0].Class,ability=s.spellBook.classAbility(classType);
 for(const args of [[44],[44,1],[44,0,-1,-1,0],[44,-1,85,2,17],[-1,0,999,5,-1]]){
  const e=s.commands.EffectPolymorph(args,{self:o.id});assert.equal(e.type,62);assert.equal(e.creatorId,o.id);assert.equal(e.integers[0],args[0]);assert.equal(e.integers[6],args.length>2&&args[3]>=0&&args[3]<=5?args[3]:ability);report.constructors.push({args,effect:structuredClone(e)});
 }
 // Owned bytecode verifies actual VM argument order and typed return using
 // the installed API declaration, independently of the direct command calls.
 const ordinal=s.vm.api.findIndex(v=>v?.name==='EffectPolymorph');assert.equal(ordinal,463);const args=[44,0,-1,2,17],code=[];
 for(const n of [...args].reverse())code.push(4,3,n>>>24&255,n>>>16&255,n>>>8&255,n&255);
 code.push(5,0,ordinal>>>8,ordinal&255,args.length,0x20,0);const bytes=new Uint8Array(13+code.length);bytes.set(new TextEncoder().encode('NCS V1.0'));bytes[8]=0x42;new DataView(bytes.buffer).setUint32(9,bytes.length);bytes.set(code,13);
 const result=await s.vm.run(parseNcs(bytes,'owned_polymorph_constructor'),o.id);assert.equal(result.stack.length,1);assert.equal(result.stack[0].type,0x10);assert.deepEqual(result.stack[0].value.integers,[44,0,0,1,-1,1,2,17]);report.ownedBytecodeConstructor=result.stack[0].value;
 const initial=structuredClone(o.effects),loops=structuredClone(o.nativeLoopingVisuals160.records),vision=o.visionFlags;
 for(let race=0;race<Math.min(7,s.characterRules.racialtypes.orderedRows.length);race++){
  const list=await s.effects.raceFeats(race);assert.equal(await s.effects.raceFeats(race),list);const dark=isFirstLevelRacialFeat(list,228),low=isFirstLevelRacialFeat(list,354),parent=s.effects.create(68,o.id,[race],8);parent.durationType=4;
  await s.effects.applyNative(parent,o.id);const applied=o.effects.filter(e=>e.id===parent.id),filters=applied.filter(e=>e.type===69),visuals=applied.filter(e=>e.type===30);
  assert.equal(applied.filter(e=>e.type===68).length,1);assert.deepEqual(filters.map(e=>e.integers[0]),[...(dark?[2]:[]),...(low?[1]:[])]);assert.deepEqual(visuals.map(e=>e.integers[0]),[...(dark?[182]:[]),...(low?[243]:[])]);
  for(const e of applied){assert.equal(e.creatorId,o.id);assert.equal(e.durationType,4);assert.equal(e.spellId,parent.spellId);assert.equal(e.casterLevel,parent.casterLevel);if(e.type!==68)assert.equal(e.exposed,false);}
  assert.equal(root.Race,authoredRace);assert.equal(o.visionFlags,vision,'Native racial filters are visual children; do not invent a vision flag mutation');
  report.races.push({physicalRace:race,featCount:list.length,darkVision:dark,lowLight:low,effects:structuredClone(applied),looping:structuredClone(o.nativeLoopingVisuals160.records)});
  await s.effects.remove(o.id,parent.id);assert.deepEqual(o.effects,initial);assert.deepEqual(o.nativeLoopingVisuals160.records,loops);assert.equal(s.registry.get(identity),o);assert.equal(o.creatureData,root);assert.equal(o.stats,stats);
 }
 report.canonicalIdentityPreserved=true;
}catch(error){report.failure={message:error.message,stack:error.stack};}
report.diagnostics=runtimeDiagnostics.records.slice(start);report.errors=report.diagnostics.filter(r=>!['info','warning'].includes(r.severity));await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({races:report.races.length,constructors:report.constructors.length,failure:report.failure,errors:report.errors}));if(report.failure||report.errors.length)process.exitCode=1;
