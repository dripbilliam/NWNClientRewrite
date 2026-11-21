import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {prepareSpellTarget,spellCreatureTargetVeto} from '../src/spell_targeting.js';
import {radialSpellCastRequest} from '../src/spell_radial.js';

test('client target preparation and creature veto match original first-child, self and inventory owners',()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-targeting-observations.json',import.meta.url))),actor={id:99,areaId:1,objectType:5};
  function providers(c,lookups){return {spell:id=>{
    id>>>=0;lookups.push(id);
    if(id===10&&!c.missingParent)return {id,targetType:c.mask??3,children:c.childCount?[c.childId??11]:[]};
    if(id===((c.childId??11)>>>0)&&!c.missingChild)return {id,targetType:c.childMask??2,children:[]};
    return null;
  }};}
  for(const {case:c,result,lookups,types,calls,callback}of oracle.rows){
    const actualLookups=[],plan=prepareSpellTarget(c.controlled===false?null:actor,{spellId:c.spellId??10},providers(c,actualLookups),{autoSelf:c.autoSelf??1,inventoryMode:c.inventoryMode??null,containerMode:c.containerMode??null});
    assert.deepEqual(actualLookups,lookups,JSON.stringify(c));
    assert.equal(plan.mode==='self',result===0,JSON.stringify(c));
    if(plan.mode==='target'){
      assert.deepEqual(plan.targetTypes.map(type=>[type,29]),types,JSON.stringify(c));
      assert.equal(callback,c.ability?'0x140704420':'0x140704300');
      assert.equal(calls.at(-1)[0],'preview');
      assert.equal(calls.at(-1)[4],plan.definition.id);
    }else if(plan.mode==='self'){
      assert.equal(plan.request.spellId,(c.spellId??10)&65535);
      assert.equal(calls[0][0],c.ability?'ability':'cast');
      assert.equal(calls[0][1],plan.request.spellId,'metadata substitution must not replace submitted parent ID');
    }else{assert.deepEqual(types,[]);assert.deepEqual(calls,[]);}
  }
  for(const {case:c,result,lookups}of oracle.gates){
    const actualLookups=[],target=c.creature?{id:c.self?99:100,objectType:5}:null;
    assert.equal(spellCreatureTargetVeto(10,actor,target,providers(c,actualLookups)),result,JSON.stringify(c));
    assert.deepEqual(actualLookups,lookups);
  }
  for(const {case:c,calls}of oracle.selections){
    const r=radialSpellCastRequest({...c,spellId:10},actor,actor,[1.25,2.5,3.75]);
    assert.deepEqual([['cast',r.spellId,r.targetId,r.position,r.classIndex,r.domainLevel,r.metamagic,r.spontaneous]],calls);
  }
});
