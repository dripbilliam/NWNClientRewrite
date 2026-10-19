import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {copyNativeItem} from '../src/item_copy.js';
import {getItemPartColor,setItemPartColor} from '../src/item_part_colors.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-copy-observations.json',import.meta.url)));
test('complete item copy matches original selective fields, metadata, ordering and populated-container rejection',async()=>{
 assert.equal(data.rows.length,436);
 for(const row of data.rows){const c=row.case,d=structuredClone(row.before),s=structuredClone(row.source),trace=[];s.repo=c.repo===false?null:{count:c.count??0,width:7,height:5,boundary:35};let id=100;
  const cell=(o,kind,key,value)=>{if(value!==undefined)o[kind][key]=structuredClone(value);return o[kind][key];},p={repository:o=>o.repo,repositoryCount:r=>r.count,localized:(o,k,v)=>{if(v!==undefined)trace.push(['localized',k,k]);return cell(o,'localized',k,v);},string:(o,k,v)=>cell(o,'strings',k,v),scalar:(o,k,v)=>cell(o,'scalars',k,v),byte:(o,k,v)=>cell(o,'bytes',k-0x350,v),appearance:(o,k,i,v)=>cell(o,k,i,v),
   removeTag:(o,text)=>trace.push(['removeTag',o.id,text]),addTag:(o,text)=>trace.push(['addTag',o.id,text]),constructRepository:(o,r)=>trace.push(['repository',o.id,r.width,r.height,r.boundary,0]),copyVariables:()=>trace.push(['variables']),properties:(o,active)=>Array(o.properties[active?0:1]).fill(0),assignProperties:(o,a,active)=>{o.properties[active?0:1]=a.length;trace.push(['properties',active?0x368:0x378,a.length]);},effects:o=>o.effects,copyEffectFresh:e=>{trace.push(['effect',++id,e,0]);return id;},hasPartColors:(o,ch)=>o.partColors[ch]!==null,getPartColor:getItemPartColor,setPartColor:setItemPartColor,updateVisual:()=>trace.push(['visual'])};
  assert.equal(await copyNativeItem(d,c.nullSource?null:s,c.copyVars??1,p),row.result,JSON.stringify(c));delete d.repo;assert.deepEqual(d,row.after,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('per-part palettes match native BYTE indices, absent255, lazy channel allocation and retained channels',()=>{
 assert.equal(data.palettes.length,300);
 for(const row of data.palettes){const c=row.case,o={partColors:structuredClone(row.before.partColors)};assert.equal(getItemPartColor(o,c.channel,c.part),row.prior,JSON.stringify(c));setItemPartColor(o,c.channel,c.part,c.value);assert.equal(getItemPartColor(o,c.channel,c.part),row.value,JSON.stringify(c));assert.deepEqual(o.partColors,row.after.partColors,JSON.stringify(c));}
});
