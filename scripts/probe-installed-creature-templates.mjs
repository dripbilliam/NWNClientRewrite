import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {parse2da} from '../src/area.js';
import {typedGff,writeGff,gffField as F,gffRecord as R} from '../src/gff_writer.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {featAbilityDeltas} from '../src/feat_ability_bonuses.js';
import {rulesetInt} from '../src/combat_stats.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {readItemGffField} from '../src/item_gff_load.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-creature-templates-v1.json',report={created:[]},abilities=['Str','Dex','Con','Int','Wis','Cha'];
try{
 const bic=await fs.readFile(`${root}/data/lcv/wizard.bic`),s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:bic});
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,construct=()=>s.register('creature',`runtime:creature:${s.registry.nextObjectId[0]}`,{tag:'',authored:{},inventory:[],deferTagLookup:true,registerAI:true,isPC:false,isDM:false});
 const resources=[...s.resolver.key.resources.values()].filter(r=>r.resourceType===2027).slice(0,4);assert.equal(resources.length,4);const declaredItemReferences=new Set();
 const delta=data=>featAbilityDeltas(data.FeatList??[],0,{hasFeat:(list,id)=>Number(list.some(entry=>(entry.Feat&65535)===id)),rule:(label,fallback)=>rulesetInt(s.characterRules,label,fallback)});
 const checkReady=o=>{let count=0;for(const state of o.nativeTalentClasses)for(const level of state.memorized)for(const slot of level)if(slot){assert.equal(slot.ready,1);count++;}return count;};
 const destroy=async o=>{const children=[...o.inventory],next=s.registry.nextObjectId[0];await s.lifecycle.destroy(o);assert.equal(s.registry.get(o.id),undefined);for(const id of children)assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);return children;};
 for(const resource of resources){
  const data=parseGff(await s.resolver.getResource(resource.resref,2027),'UTC ').root,o=construct(),tag=`LoadedUTC_${o.id}`,deltas=delta(data);
  for(const entry of[...data.Equip_ItemList??[],...data.ItemList??[]]){let ref=readItemGffField(entry,'resref','EquippedRes','');if(ref.status===0)ref=readItemGffField(entry,'resref','InventoryRes','');if(ref.status!==0)declaredItemReferences.add(ref.value.toLowerCase());}
  assert.equal(await s.loadCreatureTemplate(o,resource.resref,tag),1);assert.equal(o.tag,tag);assert.equal(o.templateResRef,resource.resref);assert.equal(o.areaId,OBJECT_INVALID);assert.equal(s.byTag(tag)[0],o);assert.equal(o.nativeStatsIsPCb0,0);
  assert.deepEqual(abilities.map(name=>o.creatureData[name]),abilities.map((name,i)=>(data[name]+deltas[i])&255));const slots=checkReady(o),children=await destroy(o);report.created.push({id:o.id,reference:resource.resref,slots,children});
 }
 // RAM-only UTC fixture built from the installed wizard BIC. This exercises
 // template's force-NPC flag, active feat bonus, unready authored slots, tag
 // override before PostProcess lookup and typed locals with real equipment.
 const fixture=typedGff(parseGff(bic).root),name='utc_owner_probe',tag='New UTC Tag!',sourceTag='Old UTC Tag!';
 fixture.fields.IsPC=F(0,1);fixture.fields.Tag=F(10,sourceTag);fixture.fields.UUID=F(10,'01234567-89ab-cdef-0123-456789abcdef');fixture.fields.ScriptSpawn=F(4,123);
 fixture.fields.VarTable=F(15,[R({Name:F(10,'LoadedUTC'),Type:F(4,1),Value:F(5,17)})]);
 const feats=fixture.fields.FeatList??=F(15,[]);if(!feats.value.some(row=>row.fields.Feat.value===814))feats.value.push(R({Feat:F(2,814)}));
 let unready=0;for(const c of fixture.fields.ClassList.value)for(let level=0;level<10;level++)for(const slot of c.fields[`MemorizedList${level}`]?.value??[]){slot.fields.Ready=F(0,0);unready++;}assert.ok(unready);
 const bytes=writeGff('UTC ',fixture),data=parseGff(bytes).root,get=s.resolver.getResource.bind(s.resolver),savedRules=s.characterRules.ruleset;s.resolver.getResource=(ref,type)=>ref===name&&type===2027?Promise.resolve(bytes):get(ref,type);
 s.characterRules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 EPIC_GREAT_STAT_BONUS 2');
 const o=construct(),deltas=delta(data);o.scripts={spawn:'keep_spawn'};assert.equal(await s.loadCreatureTemplate(o,name,tag),1);assert.equal(o.scripts.spawn,'keep_spawn');assert.equal(o.tag,'NewUTCTag');assert.equal(s.byTag('NewUTCTag')[0],o);assert.equal(s.byTag('OldUTCTag').length,0);assert.equal(o.nativeStatsIsPCb0,0);assert.equal(o.creatureData.IsPC,0);assert.equal(o.authored.IsPC,1);assert.equal(o.locals.getInt('LoadedUTC'),17);assert.equal(o.nativeUUID.value,'','Template owner does not import generic UUID');
 assert.deepEqual(abilities.map(name=>o.creatureData[name]),abilities.map((name,i)=>(data[name]+deltas[i])&255));const ready=checkReady(o);assert.equal(ready,unready);const children=await destroy(o);s.characterRules.ruleset=savedRules;report.fixture={id:o.id,ready,authoredUnready:unready,deltas,children,forceNonPC:true,oldTagNotInserted:true,uuidNotImported:true,wrongTypedScriptRetainsExisting:true};
 report.expectedMissingItems=[];
 for(const error of runtimeDiagnostics.records.slice(begin).filter(row=>row.severity==='error')){
  assert.equal(error.context.operation,'native-item-template');assert.ok(declaredItemReferences.has(error.context.resource));assert.equal(s.registry.get(error.context.objectId),undefined);
  await assert.rejects(s.resolver.getResource(error.context.resource,2025),failure=>failure.code==='RESOURCE_NOT_FOUND');report.expectedMissingItems.push({resource:error.context.resource,id:error.context.objectId});
 }
 report.diagnostics=runtimeDiagnostics.records.slice(begin);report.validation='PASS';report.limits='Four installed UTC templates plus RAM-only wizard UTC fixture; canonical IDs, active great-ability rule, forced NPC stats, template tag/locals/spell readiness and destruction. Module-specific item references unavailable in Prelude are independently rechecked against the active resolver, reported and cleaned up. Native AI/startup disabled. Does not bind CreateObject243, place/render these creatures, or prove complete ReadStats/PostProcess/creature-data import or campaign parity. Generic UUID intentionally not imported by this template owner.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,created:report.created,fixture:report.fixture,failure:report.failure}));if(report.failure)process.exitCode=1;
