import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {curseEffect,applyCurse} from '../src/curse_effect.js';
import {etherealEffect} from '../src/sanctuary_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-curse-effects-observations.json',import.meta.url)));
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,exposed:Number(e.exposed),showIcon:e.showIcon,integers:e.integers});

test('Curse apply/remove matches full original handler, copied payloads and deferred CON order',async()=>{
  assert.equal(oracle.rows.length,662);assert.equal(oracle.copyConstructorExecutions,756);
  for(const row of oracle.rows.filter(r=>['apply','remove'].includes(r.case.mode))){
    const c=row.case,s=new ModuleSession(null),actor={id:99},source={},calls=[];
    const e=s.effects.create(45,98,c.values??[1,2,3,4,5,6],8);Object.assign(e,{id:'000000000000004d',durationType:c.durationType??2,spellId:11,casterLevel:7,showIcon:c.showIcon??1,bypassImmunity:c.bypass??0});
    const p={dead:()=>{calls.push(['dead']);return c.dead??0;},asCreature:()=>{calls.push(['creature']);return c.creature===false?null:actor;},plot:()=>c.plot??0,
      creature:id=>{calls.push(['source',id]);return c.source===false?null:source;},immunity:(o,kind,from,flag)=>{calls.push(['immunity',kind,from?'source':null,flag]);return c.immune??0;},
      feedback:(o,code,data)=>calls.push(['feedback',o===source?'source':'actor',code,data]),copyConstruct:(...a)=>s.effects.copyConstruct(...a),
      apply:(o,e,loading)=>calls.push(['apply',snapshot(e),loading]),enqueue:(o,id,e)=>calls.push(['event',0,0,e.creatorId,o.id,id,snapshot(e)])};
    const result=c.mode==='remove'?1:await applyCurse(actor,e,p,c.loading??0);
    assert.deepEqual({result,calls,output:null},{result:row.result,calls:row.calls,output:row.output},JSON.stringify(c));
  }
});

test('Curse and Ethereal constructors match original defaults, signed magnitudes and VM boundaries',()=>{
  for(const row of oracle.rows.filter(r=>['curse','ethereal'].includes(r.case.mode))){
    const c=row.case,calls=[];let result=0,output=null;
    const count=c.mode==='curse'&&(c.argc??6)>0?6:0;for(let n=1;n<=count;n++){calls.push(['pop']);if(c.failPop===n){result=-639;break;}}
    if(result===0){
      const s=new ModuleSession(null),p={create:(...args)=>{const e=s.effects.create(...args);e.id='0000000000000065';calls.push(['creator',e.creatorId]);return e;}};
      const e=c.mode==='curse'?curseEffect(count?c.values??Array(6).fill(1):[],98,p):etherealEffect(98,p);
      output=snapshot(e);calls.push(['push']);if(c.push===0)result=-638;
    }
    assert.deepEqual({result,calls,output},{result:row.result,calls:row.calls,output:row.output},JSON.stringify(c));
  }
});
