import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {prepareFeatTarget} from '../src/feat_targeting.js';
test('client feat targeting preserves native mode routing, auto-self and signed child selector',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-feat-target-observations.json',import.meta.url)));
 for(const {case:c,result,calls,lookups,types}of oracle.rows){
  const actual=[],packed=((c.featId??257)&65535)|((c.auxiliary??0)<<16),p={feat:id=>{actual.push(['feat',id]);return c.missingFeat?null:{targetSelf:c.targetSelf??0,spellId:c.spellId??10};},
   spell:id=>{id>>>=0;actual.push(['spell',id]);if(c.missingSpell||id===11&&c.missingChild)return null;return id===10?{targetType:c.mask??3,children:c.childCount?[11]:[]}:id===11?{targetType:c.childMask??1,children:[],featId:(c.childFeat??0)<<16}:null;}};
  const plan=prepareFeatTarget({featId:packed},p,{autoSelf:c.autoSelf??1});assert.deepEqual(actual,lookups,JSON.stringify(c));
  if(plan.mode==='mode'){assert.equal(result,0);assert.deepEqual(calls,[['mode',plan.modeId]]);}
  else if(plan.mode==='self'){assert.equal(result,0);assert.deepEqual(calls,[['feat',packed>>>0,99]]);}
  else{assert.equal(result,1);if(plan.mode==='target')assert.deepEqual(plan.targetTypes.map(type=>[type,c.spellId===-1?37:29]),types,JSON.stringify(c));else assert.deepEqual(types,[]);}
 }
});
