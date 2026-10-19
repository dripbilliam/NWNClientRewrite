import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyEntangle,removeEntangle,applyCutsceneImmobile} from '../src/entangle_effect.js';
import {ModuleSession} from '../src/module_session.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-entangle-effect-observations.json',import.meta.url)));
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,exposed:Number(e.exposed),showIcon:e.showIcon,integers:e.integers});
test('entangle matches original child preallocation, immunity, floaty and NPC visibility removal',async()=>{
  assert.equal(data.rows.length,1373);assert.equal(data.copyConstructorExecutions,884);
  for(const row of data.rows){const c=row.case,s=new ModuleSession(null),actor={id:99,nativeField89c:c.pc??0},source={},calls=[];let output=null,result=0;
    if(c.mode.startsWith('constructor')){const e=s.effects.create(c.mode==='constructorImmobile'?94:18,98,[],8);e.id='0000000000000065';output=snapshot(e);calls.push(['creator',98],['push']);if(c.push===0)result=-638;}
    else{const e=s.effects.create(c.mode==='immobile'?94:18,98,Array.from({length:8},(_,i)=>100+i),8);Object.assign(e,{id:'000000000000004d',durationType:c.durationType??2,spellId:11,casterLevel:7,showIcon:c.showIcon??1,exposed:c.exposed??1,bypassImmunity:c.bypass??0});
      const p={dead:()=>{calls.push(['dead']);return c.dead??0;},asCreature:()=>{calls.push(['creature']);return c.creature===false?null:actor;},creature:id=>{calls.push(['source',id]);return c.source===false?null:source;},
        immunity:(o,kind,from,flag)=>{calls.push(['immunity',kind,from?'source':null,flag]);return c.immune??0;},plot:()=>c.plot??0,feedback:(o,n,d)=>calls.push(['feedback',o===source?'source':'actor',n,d]),
        clearActions:()=>calls.push(['clearActions']),copyConstruct:(e,icons)=>{calls.push(['copy',icons]);return s.effects.copyConstruct(e,icons);},apply:(o,e,l)=>calls.push(['apply',snapshot(e),l>>>0]),floaty:(o,id)=>calls.push(['floaty',id,o.id]),
        possessed:()=>{calls.push(['possessed']);return c.possessed??0;},clearVisible:()=>calls.push(['clearVisible']),updateVisible:()=>calls.push(['updateVisible'])};
      result=c.mode==='immobile'?await applyCutsceneImmobile(actor,e,p,c.loading??0):c.mode==='apply'?await applyEntangle(actor,e,p,c.loading??0):await removeEntangle(c.nullObject?null:actor,e,p);
    }
    assert.deepEqual({result,calls,output},{result:row.result,calls:row.calls,output:row.output},JSON.stringify(c));
  }
});
