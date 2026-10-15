import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {commandCastSpell,commandSpellLevel,commandSpellUses} from '../src/spell_cast_request.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-request-observations.json',import.meta.url)));
for(const mode of ['cast','level','uses'])test(`native spell ${mode} command matches original selection and stack outputs`,async()=>{
  for(const row of oracle.rows.filter(row=>(row.case.mode??'cast')===mode&&!row.case.truncate)){
    const c=row.case,calls=[],casts=[],actor={nativeFieldEc:c.commandable??1},p={spellCount:c.spellCount??64,
      object:id=>id===99?c.actor===false?null:actor:id===100&&c.target!==false?{}:null,
      creature:o=>c.kind===undefined||c.kind==='creature'?o:null,placeable:o=>c.kind==='placeable'?o:null,
      creatureById:()=>c.actor===false?null:actor,classes:()=>c.classes.map(cls=>cls.id),casterClass:id=>c.classes.find(cls=>cls.id===id)?.caster??1,
      memorizes:id=>c.classes.find(cls=>cls.id===id)?.memo??1,
      uses:(_o,id,index,domain,meta)=>{calls.push(['uses',id,index,domain,meta]);return c.classes[index].uses??1;},
      readyCount:(_o,index,id)=>{calls.push(['ready',index,id]);const cls=c.classes[index];return{count:cls.ready??1,level:cls.level??1,slot:cls.slot??0};},
      slotMetamagic:(_o,index,level,slot)=>{calls.push(['meta',index,level,slot]);return c.slotMeta??16;},
      abilityReady:(_o,id)=>{calls.push(['ability',id]);return c.ability??0;},
      abilityCasterLevel:(_o,id)=>{calls.push(['casterLevel',id]);return c.casterLevel??3;},
      spell:id=>(c.spellIds??[1,2]).includes(id)?{master:id===1?c.master??2:id,innate:c.innate??1}:null,
      level:(id,cls)=>{calls.push(['level',id,cls]);return c.levels?.[id]?.[cls]??c.level??1;},
      addCreatureCast:(_o,args)=>casts.push(['creature',args]),addPlaceableCast:(_o,args)=>casts.push(['placeable',args])};
    let outputs=[],result=0;
    if(mode==='cast')result=await commandCastSpell({ordinal:c.ordinal??48,argc:c.argc??9,self:99,spellId:c.id??1,targetId:100,position:[2,3,4],
      metamagic:c.meta??255,cheat:c.cheat??0,domainLevel:c.domain??0,path:c.path??0,instant:c.instant??0,classType:c.class??-1,spontaneous:c.spontaneous??0,executionContext:c.context??1},p);
    if(mode==='level')outputs=commandSpellLevel(c.class??0,c.id??1,p);
    if(mode==='uses')outputs=commandSpellUses(99,c.class??0,c.id??1,c.meta??255,c.domain??0,p);
    const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(outputs,row.outputs,label);assert.deepEqual(calls,row.calls,label);assert.deepEqual(casts,row.casts,label);
  }
});
