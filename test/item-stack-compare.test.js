import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {compareStackItems,nativeItemTag} from '../src/item_stack_compare.js';

function item(){return{identified:1,activeProperties:[{type:15,subtype:1,costTable:2,costValue:3,param1:4,param1Value:5,usesPerDay:255,remaining:0,chance:0,durationType:0,propertyId:0n}],
  passiveProperties:[{costValue:0}],plot:0,charges:50,baseItem:49,stolen:0,stackSize:1,droppable:0,location:0,price:0,
  tag:'Potion',tagLength:6,modelParts:[1,2,3],armorParts:Array.from({length:19},(_,i)=>i+1),colors:[1,2,3,4,5,6]};}

test('stack comparison matches1080 complete native executions across compared and ignored fields',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-item-stack-compare-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.observations.length,1080);
  for(const {case:c,result} of oracle.observations){
    const a=item(),b=item(),[group,key]=c.mutation.split('.');
    if(['modelParts','armorParts','colors'].includes(group))b[group][key]^=1;
    else if(group==='active')b.activeProperties[0][key]=key==='propertyId'?1n:b.activeProperties[0][key]^1;
    else if(group==='passiveValue')b.passiveProperties[0].costValue=1;
    else if(group==='activeCount')b.activeProperties=[];
    else if(group==='passiveCount')b.passiveProperties=[];
    else if(group==='tagContent')b.tag='Qotion';
    else if(group==='tagLength')b.tagLength=7;
    else if(group!=='same')b[group]^=1;
    const p={baseInfo:()=>c.validBase?{stacking:c.stacking,modelType:c.modelType}:null,tag:o=>({...nativeItemTag(o.tag),length:o.tagLength})};
    assert.equal(compareStackItems(a,b,p),result,JSON.stringify(c));
  }
});

test('native tag comparison is byte/case sensitive, stops at NUL after length comparison and honors a null left buffer',()=>{
  const a=item(),b=item(),p={baseInfo:()=>null,tag:o=>nativeItemTag(o.tag)};
  a.tag='€';b.tag='\x80';assert.equal(compareStackItems(a,b,p),1);
  a.tag='A';b.tag='a';assert.equal(compareStackItems(a,b,p),0);
  a.tag='a\0x';b.tag='a\0y';assert.equal(compareStackItems(a,b,p),1);
  b.tag='a\0yz';assert.equal(compareStackItems(a,b,p),0);
  assert.equal(compareStackItems(a,b,{...p,tag:o=>o===a?{length:4,present:false,bytes:[]}:{length:4,present:true,bytes:[120,121,122,0]}}),1);
  assert.throws(()=>nativeItemTag('🦊'),/encoding is unavailable/);
});
