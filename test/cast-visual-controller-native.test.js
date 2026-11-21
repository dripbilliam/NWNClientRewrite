import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {createCastVisualController,clearCastVisuals,castVisualDoneFade,releaseCastVisuals,startConjureVisuals,updateCastVisualController,driveCastVisualController} from '../src/cast_visual_controller.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-visual-controller-observations.json',import.meta.url)));
for(const op of ['ctor','release','start','clear','callback','tick','driver'])test(`native cast visuals ${op}: field state and ordered lower calls`,()=>{
 const rows=capture.rows.filter(r=>r.case.op===op);assert.ok(rows.length);
 for(const row of rows){
  const c=row.case,state=createCastVisualController(),calls=[],old=Array.from({length:7},(_,i)=>({name:'old'+i})),name=o=>o?.name??null;let created=0;
  state.conjure=old.slice(0,3).map((m,i)=>c.slots&(1<<i)?c.alias?old[0]:m:null);state.cast=old.slice(3,6).map((m,i)=>c.slots&(1<<(i+3))?m:null);
  [state.conjureTime,state.castTime,state.released]=c.timers??[0,0,0];state.done=[...(c.done??[0,0,0])];
  const source={name:'actor',position:[1,2,3]},actor={source,visuals:state,animation:c.animation??15,spellId:42,previousCasting:c.previous??0,suppressSound:c.suppress??0,race:c.soundSet??0,gender:c.female??0};
  const p={
   create:(resource,category)=>{const index=created++;calls.push(['create',resource,category]);return c.fail&(1<<index)?null:{name:'new'+index};},
   attach:(model,parent,part,flags)=>{calls.push(['attach',name(model),name(parent),part,flags]);if(c.detachNull&&!parent)for(const group of [state.conjure,state.cast])for(let i=0;i<3;i++)if(group[i]===model)group[i]=null;},
   destroy:model=>calls.push(['destroy',name(model),1]),play:(model,clip,speed,flags,time)=>calls.push(['play',name(model),clip,0x3f800000,flags,time]),
   listen:(model,event,callback,context)=>{assert.equal(callback,castVisualDoneFade);assert.equal(context,state);calls.push(['listen',name(model),event,'controller']);},
   sourceModel:(_source,part,flags)=>{calls.push(['source',part,flags]);return (c.model??1)?{name:'source'}:null;},
   nodePose:(model,part,position)=>{calls.push(['pose',name(model),part]);if(c.pose??1)position.splice(0,3,7,8,9);return c.pose??1;},
   oneShot:(sound,position,priority,gain)=>calls.push(['sound',sound,position,0x3fc00000,priority,0,0]),
   spell:id=>{calls.push(['spell',id>>>0]);return(c.spell??1)?{conjure:['head','hand','ground'],conjureSoundMale:'male',conjureSoundFemale:'female',conjureSound:'generic'}:null;}
  };
  if(op==='ctor')Object.assign(state,createCastVisualController());
  else if(op==='release')releaseCastVisuals(state,c.refs,source,p);
  else if(op==='start')startConjureVisuals(state,c.refs,c.sounds,source,p);
  else if(op==='clear')clearCastVisuals(state,c.group,p);
  else if(op==='callback')castVisualDoneFade(old[c.which],c.context?state:null);
  else if(op==='tick')updateCastVisualController(state,c.elapsed,p);
  else driveCastVisualController(actor,c.elapsed,p);
  const actual={...state,conjure:state.conjure.map(name),cast:state.cast.map(name)};
  assert.deepEqual({state:actual,calls,previous:actor.previousCasting,spellId:actor.spellId,suppress:actor.suppressSound},{state:row.state,calls:row.calls,previous:row.previous,spellId:row.spellId,suppress:row.suppress},JSON.stringify(c));
 }
});
