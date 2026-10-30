import fs from 'node:fs/promises';
import {deliverObjectVisual} from '../../src/object_visual_delivery.js';
import {createAreaVisualState,loadAreaVisualEffect} from '../../src/area_visual_effect.js';
import {intEntry} from '../../src/combat_stats.js';import {nativeFloatEntry} from '../../src/movement_rate.js';import {nativeStringEntry} from '../../src/spell_metadata.js';
const routes=[],areas=[],INVALID=0x7f000000;
for(const type of ['','P','B'])for(const targetKind of ['present','invalid','missing','wrong-type'])for(const sourcePresent of [false,true])for(const duration of [0,1.25])for(const part of [0,1,12]){
 const targetId=targetKind==='invalid'?INVALID:1,objects=new Map();if(targetKind==='present')objects.set(1,{id:1,objectType:5});if(targetKind==='wrong-type')objects.set(1,{id:1,objectType:7});if(sourcePresent)objects.set(2,{id:2,objectType:9});
 const message={visualId:44,targetId,sourceId:2,position:[1.123456789,2,-3],sourcePosition:[4,5,6],flag:part,missMode:part,duration,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}},calls=[];let id=10;
 const providers={visualType:()=>({found:true,value:type}),object:key=>objects.get(key)??null,renderObject:object=>object,createDummy:(role,p,lifetime)=>{calls.push({role,position:p,lifetime});return role==='source'?null:{id:id++,objectType:5};},add:(actor,record)=>{calls.push({actor:actor.id,record:{...record,networkTransform:null}});return 1;}};
 routes.push({label:[type,targetKind,sourcePresent,duration,part].join(':'),type,message,objects:Object.fromEntries(objects),expected:{result:deliverObjectVisual(message,providers),calls}});
}
const fields=['Imp_HeadCon_Node','Imp_Impact_Node','Imp_Root_M_Node','Imp_Root_S_Node','Imp_Root_L_Node','Imp_Root_H_Node'];
for(const selected of [-1,0,1,2,3,4,5])for(const quality of [0,1])for(const shake of [0,1,2]){
 const row={OrientWithGround:'1',ShakeType:String(shake),ShakeDuration:'.75',ShakeDelay:'.125',LowQuality:'lowmodel'};for(let i=0;i<fields.length;i++)row[fields[i]]=i===selected?'chosen'+i:'';
 const table={columns:Object.keys(row),orderedRows:[row],defaultValue:''},state=createAreaVisualState({day:0,time:0}),query={integer:{},float:{},string:{}},warnings=[],resources={};
 const read=(kind,fn)=>(id,column)=>{const value=fn(table,id,column);query[kind][column]=value;return value;};
 const loaded=await loadAreaVisualEffect(state,0,{quality:()=>quality,int:read('integer',intEntry),float:read('float',nativeFloatEntry),string:read('string',nativeStringEntry),loadModel:async(e,name)=>{resources[name]=true;e.model={id:1,resource:name};return 1;},shake:(type,delay,duration)=>warnings.push({code:'visual.area-camera-shake-pending',type,delay,duration}),animationMode:()=>{},defaultAnimation:()=>{}});
 for(const column of ['SoundImpact','SoundDuration','SoundCessation'])query.string[column]=nativeStringEntry(table,0,column);
 state.instant190=1;state.destroy194=1;state.position=[.123456789,2,3].map(Math.fround);
 areas.push({label:[selected,quality,shake].join(':'),table,quality,message:{visualId:0,position:[.123456789,2,3]},expected:{loaded,state,query,warnings,resources:Object.keys(resources)}});
}
await fs.writeFile('godot-client/reports/native-point-effects-oracle-v1.json',JSON.stringify({routes,areas,scope:'Authored original-derived receiver/area-loader decisions; not fresh binary observation or live dummy packets'})+'\n',{flag:'wx'});console.log(JSON.stringify({routes:routes.length,areas:areas.length}));
