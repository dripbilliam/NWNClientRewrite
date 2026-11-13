import test from 'node:test';import assert from 'node:assert/strict';
import {writeGff,gffField as field,gffRecord as record} from '../../src/gff_writer.js';
import {parseGff,getGffStructType,getGffFieldTypes} from '../../src/gff.js';
import proof from '../tools/native-creation-class-proof.cjs';
function fixture(){
 const prepared=count=>field(15,Array.from({length:count},()=>record({Spell:field(2,65535)},0)));
 const cls=record({Class:field(5,2),ClassLevel:field(3,1),Domain1:field(0,0),Domain2:field(0,1),MemorizedList0:prepared(3),MemorizedList1:prepared(3)},0);
 const bytes=writeGff('BIC ',record({ClassList:field(15,[cls])}));
 const root=parseGff(bytes,'BIC ').root;
 return {shape:proof.snapshot(root,getGffStructType,getGffFieldTypes),expected:{classId:2,domains:[0,1],divineCreation:{version:1,classId:2,memorizes:1,learnScroll:0,post:{PickDomains:1,SpellbookRestricted:0},slots:[3,3,0,0,0,0,0,0,0,0]}}};
}
test('actual GFF typed class/Domain/WORD rows preserve the original divine source shape',()=>{
 const f=fixture();assert.equal(proof.verifySource(f.shape,f.expected).success,true);assert.equal(f.shape.fields.Domain1,0);assert.equal(f.shape.type,0);assert.equal(f.shape.levels[0].memorized[0].fields.Spell,2);
 assert.equal(proof.verifySource(undefined,f.expected).success,false);
});
test('wrong class, duplicate Domain, field widths, source book/flags and budget changes fail',()=>{
 for(const change of [f=>f.shape.classId=4,f=>f.shape.fields.Class=0,f=>f.shape.domains=[0,0],f=>f.shape.fields.Domain1=2,f=>f.shape.schoolPresent=true,f=>f.shape.dailyUsesPresent=true,f=>f.shape.familiarPresent=true,f=>f.shape.levels[0].knownPresent=true,f=>f.shape.levels[0].memorized[0].type=3,f=>f.shape.levels[0].memorized[0].spell=7,f=>f.shape.levels[0].memorized[0].fields.Ready=0,f=>f.expected.divineCreation.slots[1]=2,f=>f.expected.divineCreation.post.SpellbookRestricted=1]){const f=fixture();change(f);assert.equal(proof.verifySource(f.shape,f.expected).success,false);}
});
test('independent server class/list structure and readiness normalization is accepted without fabricating a known book',()=>{
 const f=fixture();f.shape.type=2;for(const row of f.shape.levels)for(const value of row.memorized){value.type=3;value.fields.Ready=0;value.fields.SpellMetaMagic=0;}
 f.shape.levels[0].known.push({spell:7,type:3,fields:{Spell:2}});f.shape.levels[0].knownPresent=true;
 assert.equal(proof.verifyExport(f.shape,f.expected).success,true);
 f.shape.domains=[1,0];assert.equal(proof.verifyExport(f.shape,f.expected).success,false);
});
