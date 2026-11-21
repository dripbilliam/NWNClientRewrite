import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {assignVisualTransforms,loadObjectVisualTransforms,zeroVisualTransforms,equalVisualTransforms} from '../src/object_visual_transform.js';
import {ModuleSession} from '../src/module_session.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-transform-map-observations.json',import.meta.url)));
const number=value=>({nan:NaN,inf:Infinity,negativeInf:-Infinity}[value]??value);
function bytes(entry){const raw=new Uint8Array(640).fill(entry.seed??0),v=new DataView(raw.buffer);for(const[offset,value]of Object.entries(entry.ints??{}))v.setInt32(Number(offset),value,true);for(const[offset,value]of Object.entries(entry.floats??{}))v.setFloat32(Number(offset),number(value),true);return raw;}
const entries=rows=>new Map((rows??[]).map(entry=>[entry.scope??0,bytes(entry)]));
const snapshot=map=>[...map].sort((a,b)=>a[0]-b[0]).map(([key,value])=>[key,Buffer.from(value).toString('hex')]);
const clone=map=>new Map([...map].map(([key,value])=>[key,value.slice()]));

test('complete scoped transform load and assignment match native short circuits, copies, assertions and equipped-hand propagation',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],labels=new Map(),creature={},hands=new Map([[0xab0,new Map()],[0xac0,new Map()]]),o={possessorId:c.possessor??123,nativeVisualTransforms2b0:c.current===undefined||c.current===null?null:entries(c.current)};
  if(o.nativeVisualTransforms2b0)labels.set(o.nativeVisualTransforms2b0,'current');
  const incoming=c.alias?o.nativeVisualTransforms2b0:entries(c.incoming);if(!c.alias)labels.set(incoming,'incoming');
  const p={
   constructMap:kind=>{calls.push(['construct',kind]);const map=new Map();labels.set(map,kind);return map;},
   clearMap:map=>{calls.push(['clear',labels.get(map)]);map.clear();},
   copyMap:(dst,src)=>{calls.push(['copy',labels.get(dst),labels.get(src),snapshot(src)]);for(const[key,value]of src)dst.set(key,value.slice());},
   releaseMap:map=>{calls.push(['release',labels.get(map),snapshot(map)]);map.clear();},
   asItem:()=>{calls.push(['asItem']);return c.item?o:null;},creature:id=>{calls.push(['creature',id]);return c.creature===false?null:creature;},
   equipmentSlot:(actor,item)=>{assert.equal(actor,creature);assert.equal(item,o);calls.push(['slot']);return c.slot??0;},
   copyHand:(actor,offset,map)=>{assert.equal(actor,creature);calls.push(['hand',offset,snapshot(map)]);hands.set(offset,clone(map));},
   list:(_data,name)=>{calls.push(['list',name]);return{status:c.listStatus??0,value:'list'};},
   struct:(_data,name)=>{calls.push(['struct',name]);return{status:c.legacyStatus??0,value:'legacy'};},
   count:()=>{calls.push(['count']);return c.rows?.length??0;},element:(_list,index)=>{calls.push(['element',index]);return{status:c.rows[index].status??1,value:index};},
   read:(index,kind,name,fallback)=>{assert.equal(kind,'int');assert.equal(name,'Scope');calls.push(['scope',index,fallback]);return c.rows[index].scope??{status:0,value:0};},
   loadTransform:(dst,index)=>{calls.push(['load',index]);dst.set(bytes(index==='legacy'?c.legacy??{}:c.rows[index].value??{}));},
   assertFailure:(...args)=>calls.push(['assert',...args]),
  };
  p.assignTransforms=(object,map)=>assignVisualTransforms(object,map,p);
  const mode=c.mode??'assign';let result=null;
  if(mode==='zero')result=Number(zeroVisualTransforms(incoming));
  else if(mode==='equal')result=Number(equalVisualTransforms(o.nativeVisualTransforms2b0,incoming));
  else if(mode==='load')await loadObjectVisualTransforms(o,'root',p);
  else await assignVisualTransforms(o,incoming,p);
  const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);
  assert.deepEqual(o.nativeVisualTransforms2b0===null?null:snapshot(o.nativeVisualTransforms2b0),row.current,label);assert.equal(labels.get(o.nativeVisualTransforms2b0)??null,row.currentLabel,label);
  assert.deepEqual(Object.fromEntries([...hands].map(([key,map])=>[key,snapshot(map)])),row.hands,label);
 }
 assert.equal(native.rows.length,399);
});

test('canonical visual ownership initializes once, shares FLOAT268 and releases around UUID destruction',async()=>{
 const s=new ModuleSession(null),o=s.register('placeable','visual-ownership',{authored:{},deferTagLookup:true,areaId:0x7f000000}),id=o.id,next=s.registry.nextObjectId[0];
 assert.equal(o.nativeVisualTransforms2b0,null);assert.deepEqual(o.nativeMiscVisualFields,{0x254:-1,0x258:-1,0x25c:-1,0x260:-1,0x268:45,0x26c:15,0x270:0,0x278:''});
 for(const offset of[0x2b8,0x2c8,0x2d8])assert.deepEqual(o.nativeVisualPools[offset],{records:[],capacity:0});
 o.nativeMiscVisualFields[0x268]=77;assert.equal(o.nativeProjectileRange268,77);o.nativeProjectileRange268=.1;assert.equal(o.nativeMiscVisualFields[0x268],Math.fround(.1));
 const map=o.nativeVisualTransforms2b0=entries([{floats:{4:2}}]);
 for(const pool of Object.values(o.nativeVisualPools)){pool.records=[new Uint8Array(34)];pool.capacity=16;}o.nativeMiscVisualFields[0x278]='bubble';
 const destroy=s.uuids.destroy.bind(s.uuids);let uuid=false;s.uuids.destroy=object=>{assert.equal(object,o);assert.equal(map.size,0);assert.equal(o.nativeVisualTransforms2b0,null);assert.equal(o.nativeVisualPools[0x2d8].records.length,1);uuid=true;return destroy(object);};
 await s.lifecycle.destroy(o);assert.equal(uuid,true);assert.equal(s.registry.get(id),undefined);assert.equal(s.registry.nextObjectId[0],next);
 for(const pool of Object.values(o.nativeVisualPools))assert.deepEqual(pool,{records:[],capacity:0});assert.equal(o.nativeMiscVisualFields[0x278],'');
});
