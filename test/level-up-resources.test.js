import test from 'node:test';
import assert from 'node:assert/strict';
import {loadLevelUpRules} from '../src/character_level_up.js';
const empty='2DA V2.0\n\nLabel\n0 ****\n';
function resolver({missing=null}={}){
 const calls=[],state={active:0,peak:0};return{calls,state,async getResource(name){calls.push(name);state.active++;state.peak=Math.max(state.peak,state.active);try{await new Promise(r=>setImmediate(r));if(name===missing)throw Error('Missing '+name);if(name==='classes')return new TextEncoder().encode('2DA V2.0\n\nStatGainTable SkillsTable FeatsTable PreReqTable\n'+Array.from({length:36},(_,i)=>`${i} gains skill${i} FEATS missing_prerequisite`).join('\n'));return new TextEncoder().encode(empty);}finally{state.active--;}}};
}
test('wizard loads only progression dependencies, deduplicates custom class tables and bounds concurrency',async()=>{
 const r=resolver(),rules=await loadLevelUpRules(r);assert.equal(rules.classTables.size,38);assert.equal(r.calls.filter(n=>n==='gains').length,1);assert.equal(r.calls.filter(n=>n==='feats').length,1);assert.ok(r.state.peak>1&&r.state.peak<=12);assert.ok(!r.calls.includes('missing_prerequisite'));for(const name of ['baseitems','appearance','iprp_costtable','visualeffects','savingthrowtypes'])assert.ok(!r.calls.includes(name),name);
});
test('failed required progression tables reject instead of displaying inferred rules',async()=>{await assert.rejects(loadLevelUpRules(resolver({missing:'skill17'})),/Missing skill17/);});
test('optional domain/school behavior remains available to nondependent classes',async()=>{const rules=await loadLevelUpRules(resolver({missing:'domains'}));assert.equal(rules.domains,null);assert.ok(rules.spellschools);});
