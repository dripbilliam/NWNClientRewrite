import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadVisualCurve,restartVisualCurve,loadVisualTransform,visualTransformClockProviders} from '../src/object_visual_transform.js';
import {WorldTimer} from '../src/world_timer.js';
import {objectVisualDataGffProviders} from '../src/object_visual_data.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-visual-transform-observations.json',import.meta.url)));
const number=value=>({nan:NaN,inf:Infinity,negativeInf:-Infinity}[value]??value);
const normalize=value=>typeof value==='number'&&!Number.isFinite(value)?Number.isNaN(value)?'nan':value>0?'inf':'negativeInf':Array.isArray(value)?value.map(normalize):value&&typeof value==='object'?Object.fromEntries(Object.entries(value).map(([k,v])=>[k,normalize(v)])):value;

test('curve load, timer restart and complete10-property transform match original field bytes and clock call ordering',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],out=new Uint8Array(c.mode==='transform'?640:64).fill(c.seed??165),v=new DataView(out.buffer);let clocks=0,worldCalls=0;
  if(c.mode==='restart'){
   for(const[offset,value]of[[0,c.timer??0],[12,c.lerp??1],[24,123456],[28,-7]])v.setInt32(offset,value,true);
   for(const[offset,value]of[[4,c.to??3],[8,c.from??1],[16,c.duration??.1],[20,.25]])v.setFloat32(offset,number(value),true);
  }
  const p={
   read:(record,kind,key,fallback)=>{calls.push(['read',record,kind,key,fallback]);const result=record==='root'?c.properties?.[key]?.direct:c.properties[record].fields?.[key],entry=result??{status:0,value:fallback};return{...entry,value:kind==='float'?Math.fround(number(entry.value)):entry.value};},
   struct:(_record,name)=>{calls.push(['struct',name]);return{status:c.properties?.[name]?.structStatus??0,value:name};},
   clock:()=>{const value=BigInt.asUintN(64,BigInt(c.clockBase??'1000000')+17n*BigInt(clocks++));calls.push(['clock',String(value)]);return value;},
   worldTimer:()=>{calls.push(['worldTimer']);return c.world===false?null:'world';},
   worldSeconds:(_world,duration)=>{calls.push(['worldSeconds',duration]);return c.delta??500;},
   worldTime:()=>{const times=c.worldTimes??[[42,1234]],[day,time]=times[Math.min(worldCalls++,times.length-1)];calls.push(['worldTime',day,time]);return{day,time};},
   addWorld:(_world,now,delta)=>{calls.push(['addWorld',now.day,now.time,delta.day,delta.time]);return{status:c.addStatus??0,day:(now.day+2)>>>0,time:(now.time+delta.time)>>>0};},
  };
  if(c.mode==='curve')assert.equal(await loadVisualCurve(out,'root',c.name??'ScaleX',c.fallback??1,p),out);
  else if(c.mode==='restart')await restartVisualCurve(out,p);
  else assert.equal(await loadVisualTransform(out,'root',p,new Uint8Array(64).fill(c.seed??165)),out);
  const label=JSON.stringify(c);assert.deepEqual(normalize(calls),row.calls,label);assert.equal(Buffer.from(out).toString('hex'),row.bytes,label);
 }
 assert.equal(native.rows.length,474);
});

test('parsed transform fields use typed scalar precedence, nested curves, clock restart and distinct defaults',async()=>{
 const data=parseGff(writeGff('UTP ',R({ScaleX:F(14,R({TimerType:F(5,0),ValueTo:F(8,3),LerpType:F(5,1),ValueFrom:F(8,2),LerpDuration:F(8,.25),LerpProgress:F(8,.125),BehaviorFlags:F(5,99),RepeatsRemaining:F(5,23)})),ScaleY:F(8,4),ScaleZ:F(5,99)}))).root;
 let clock=100n;const p={...objectVisualDataGffProviders(),clock:()=>clock++},bytes=new Uint8Array(640),v=new DataView(bytes.buffer);
 await loadVisualTransform(bytes,data,p);
 assert.equal(v.getFloat32(4,true),3);assert.equal(v.getFloat32(8,true),2);assert.equal(v.getFloat32(16,true),.25);
 assert.equal(v.getBigUint64(32,true),101n);assert.equal(v.getBigUint64(48,true),250101n);assert.equal(clock,102n);
 assert.equal(v.getInt32(24,true),0);assert.equal(v.getInt32(28,true),0,'read behavior/repeat values are discarded by the original');
 assert.equal(v.getFloat32(0x40+4,true),4);assert.equal(v.getFloat32(0x40+8,true),4);assert.equal(v.getInt32(0x40+12,true),0);
 assert.equal(v.getFloat32(0x80+4,true),1,'wrong scalar type is not guessed');
 assert.equal(v.getFloat32(0xc0+4,true),0);assert.equal(v.getFloat32(0x240+4,true),1);
 assert.equal(v.getBigUint64(0x40+32,true),100n,'scratch clock slot survives an inactive following value');
});

test('concrete visual clock bridge uses original world-time rollover and stored pause state',async()=>{
 const timer=new WorldTimer(()=>1000n);timer.setMinutesPerHour(1);timer.setTime(77,timer.dayLength-500);
 const curve=new Uint8Array(64),v=new DataView(curve.buffer);v.setInt32(0,1,true);v.setFloat32(4,2,true);v.setFloat32(8,1,true);v.setInt32(12,1,true);v.setFloat32(16,2,true);
 const p=visualTransformClockProviders(timer,()=>{throw new Error('World-timed curves must not query the real-time clock');});
 await restartVisualCurve(curve,p);assert.equal(v.getUint32(40,true),77);assert.equal(v.getUint32(44,true),timer.dayLength-500);assert.equal(v.getUint32(56,true),78);assert.equal(v.getUint32(60,true),1500);
 timer.paused=1;timer.pausedDay=90;timer.pausedTime=12;await restartVisualCurve(curve,p);
 assert.equal(v.getUint32(40,true),90);assert.equal(v.getUint32(44,true),12);assert.equal(v.getUint32(56,true),90);assert.equal(v.getUint32(60,true),2012);
 assert.equal(v.getBigUint64(32,true),0n);assert.equal(v.getBigUint64(48,true),0n);
});
