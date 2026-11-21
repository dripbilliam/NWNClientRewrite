import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellTimeConversion,scriptSavingThrow} from '../src/script_spell_support.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-script-support-observations.json',import.meta.url)));
test('save wrapper and duration conversions match original native execution',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[];let output;
    if(c.mode==='time')output=spellTimeConversion(c.ordinal,c.count??1,c.minutes??5);
    else{
      const args=[100,c.dc??10];if((c.argc??4)>2)args.push(c.category??0,c.versus??101);
      output=await scriptSavingThrow(c.ordinal,args,99,{categoryScratch:c.categoryScratch??0,object:()=>c.exists===false?null:{objectType:c.objectType??5},
        save:(_o,...args)=>{calls.push(args);return c.result??1;}});
    }
    assert.equal(output,row.output,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
test('uninitialized short save-wrapper category remains explicit in live dispatch',async()=>{
  await assert.rejects(scriptSavingThrow(108,[100,10],99,{object:()=>({objectType:5})}),/uninitialized save category/);
  await assert.rejects(scriptSavingThrow(108,[100,10,0],99,{object:()=>null}),/fourth VM argument/);
});
test('script 2DA queries resolve active physical cells, defaults and late recovery through the module resolver',async()=>{
  let requests=0,missing=true;const resolver={getResource:async(name,type)=>{
    requests++;assert.equal(name,'custom_spells');assert.equal(type,2017);
    if(missing)throw Object.assign(new Error('custom table missing'),{code:'RESOURCE_NOT_FOUND'});
    return new TextEncoder().encode('2DA V2.0\nDEFAULT: fallback\n\nValue Value\n999 module_override second').buffer;
  }};
  const s=new ModuleSession(resolver);
  assert.equal(await s.commands.Get2DAString(['CUSTOM_SPELLS','Value',0]),'');
  missing=false;
  assert.equal(await s.commands.Get2DAString(['custom_spells','value',0]),'module_override');
  assert.equal(await s.commands.Get2DAString(['custom_spells','Value',999]),'fallback');
  assert.equal(await s.commands.Get2DAString(['custom_spells','unknown',0]),'fallback');
  assert.equal(requests,2);assert.equal(await s.commands.Get2DAString(['','Value',0]),'');assert.equal(requests,2);
});
test('spell cast item and duration wrappers use actual authored API names and active world clock',()=>{
  const s=new ModuleSession(null),o=s.register('creature','caster',{}),item=s.register('item','focus',{});
  o.nativeSpellTarget818=item.id;
  assert.equal(s.commands.GetSpellCastItem([],{self:o.id}),item.id);
  s.worldTimer.setMinutesPerHour(3);assert.equal(s.commands.HoursToSeconds([2]),360);assert.equal(s.commands.RoundsToSeconds([2]),12);
  for(const [type,expected] of [[0,0],[6,0],[7,1],[8,1],[9,0],[65543,1]]){o.associateType=type;assert.equal(s.commands.GetIsDMPossessed([o.id]),expected);}
});
