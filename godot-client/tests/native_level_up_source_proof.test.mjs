import test from 'node:test';
import assert from 'node:assert/strict';
import proof from '../tools/native-level-up-source-proof.cjs';
import {levelSourceCase,xpOnlyLevelSourceCharacter} from '../tools/native-level-up-source-fixture.mjs';
import {writeGff,gffField as field,gffRecord as record} from '../../src/gff_writer.js';
import {parseGff} from '../../src/gff.js';

test('only current actual source panes can satisfy source UI evidence',()=>{
 const valid={sourceActive:true,genericVisible:false,runtimeOwns:true,paneVisible:true,ready:true,wanted:true,frontend:'res://systems/native_level_up_frontend.gd',identity:[1,2147483649,4294967295],navigationTicket:[1,2147483649,4294967295,7,2,'class'],ticket:[1,2147483649,4294967295,7,2,'class',3,'class'],token:7,stage:'class',pane:proof.SOURCE_PANES.class};
 assert.equal(proof.sourcePresentation(valid),true);
 for(const change of [v=>v.sourceActive=false,v=>v.genericVisible=true,v=>v.runtimeOwns=false,v=>v.paneVisible=false,v=>v.ready=false,v=>v.wanted=false,v=>v.ticket[3]++,v=>v.ticket[0]++,v=>v.navigationTicket[0]++,v=>v.ticket.pop(),v=>v.stage='summary',v=>v.pane='res://systems/server_level_up.gd',v=>{v.stage='generic';v.ticket[5]='generic';delete v.pane},v=>v.token='7']){const bad=structuredClone(valid);change(bad);assert.equal(proof.sourcePresentation(bad),false);}
});
test('XP fixture preserves typed unrelated fields, original bytes and exact workload class',()=>{
 const input=writeGff('BIC ',record({ClassList:field(15,[record({Class:field(5,10),ClassLevel:field(3,15)},2)]),Experience:field(4,105000),Str:field(0,10),Description:field(12,{strRef:0xffffffff,entries:[{languageId:0,text:'Installed fixture text'}]})}));
 const before=Uint8Array.from(input),rows=Array.from({length:17},()=>({XP:'0'}));rows[16]={XP:'136000'};
 const built=xpOnlyLevelSourceCharacter(input,{orderedRows:rows},'wizard-multiclass');
 assert.deepEqual(input,before);assert.equal(parseGff(built.bytes,'BIC ').root.Experience,136000);assert.equal(built.metadata.onlyFieldChanged,'Experience');assert.deepEqual(built.metadata.classes,[10,4]);
 assert.throws(()=>xpOnlyLevelSourceCharacter(input,{orderedRows:rows},'sorcerer-caster'),/exact installed/);
 for(const value of ['****','136000x',-1,0,105000,2**32]){const bad=structuredClone(rows);bad[16]={XP:value};assert.throws(()=>xpOnlyLevelSourceCharacter(input,{orderedRows:bad},'wizard-multiclass'));}
 assert.throws(()=>levelSourceCase('legacy'));
});
test('received advancement evidence rejects optimism, stale actor and wrong scalar deltas',()=>{
 const before={actorId:7,classes:[{id:10,level:15}],abilities:[10,14,14,19,10,12],skills:[3,4],feats:[1],spellbooks:{}};
 const after={...structuredClone(before),classes:[{id:10,level:16}],abilities:[10,14,14,20,10,12],skills:[4,4],feats:[1,40]};
 const proposal={classId:10,ability:3,hitDie:3,skills:[1,0],feats:[40]};
 assert.equal(proof.advancement(before,after,proposal).success,true);assert.equal(proof.advancement(before,before,proposal).success,false);
 for(const change of [v=>v.actorId++,v=>v.classes[0].level++,v=>v.abilities[3]++,v=>v.skills[0]++,v=>v.feats.pop()]){const bad=structuredClone(after);change(bad);assert.equal(proof.advancement(before,bad,proposal).success,false);}
});
