import {ResourceWorkerPool} from '../src/resource_worker_pool.js';
import {executeResourceTask} from '../src/resource_worker_tasks.js';
import {parseModel} from '../src/model_parser.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const check=(condition,message)=>{if(!condition)throw Error(message);};
const digest=model=>JSON.stringify(model,(_key,value)=>value instanceof Map?[...value]:value);
window.runResourceWorkersFixture=async bundle=>{
 const pool=new ResourceWorkerPool({size:4,createWorker:()=>new Worker(bundle,{type:'module'})}),report={success:false};
 try{
  const resolver={getResource:async(name,type)=>{const result=await window.creationFixture.resource(name,type);if(!result.ok)throw Error(result.message);return result.value;}},sources=new ModelSourceCache(resolver,{parse:bytes=>pool.decode('model',bytes)});
  const names=['plc_s04','plc_portal2','c_golstone','pmd0','ttr01_b01_01'],models=[];
  for(const name of names){const bytes=await resolver.getResource(name,2002),expected=parseModel(bytes),actual=await pool.decode('model',bytes);check(digest(actual)===digest(expected),'Model mismatch '+name);check(bytes.byteLength>0,'Detached resource '+name);models.push({name,nodes:actual.nodes.length,animations:actual.animations.length,bytes:bytes.byteLength});}
  const parent=await sources.load('c_golstone');check(parent.animations.length>0,'Supermodel animation inheritance failed');report.models=models;report.inheritedAnimations=parent.animations.length;
  const rulesBytes=await resolver.getResource('appearance',2017),rules=await pool.decode('2da',rulesBytes);check(digest(rules)===digest(parse2da(decodeResourceText(rulesBytes))),'Installed rule-table mismatch');report.rules={bytes:rulesBytes.byteLength,rows:rules.orderedRows.length};
  const palette=new Map([['pal_skin01',{width:256,height:1,data:new Uint8Array(1024).fill(173)}]]),plt=new Uint8Array(26);plt.set(new TextEncoder().encode('PLT V1  '));const pv=new DataView(plt.buffer);pv.setUint32(8,1,true);pv.setUint32(16,1,true);pv.setUint32(20,1,true);plt[24]=23;
  const colored=await pool.decode('plt',plt,{palettes:palette,rows:[0]});check(digest(colored)===digest(executeResourceTask('plt',{buffer:plt.buffer,palettes:palette,rows:[0]})),'PLT mismatch');check(palette.get('pal_skin01').data.byteLength===1024,'Detached shared palette');
  const bytes=new Uint8Array(18+1024*1024*3);bytes[2]=2;const header=new DataView(bytes.buffer);header.setUint16(12,1024,true);header.setUint16(14,1024,true);bytes[16]=24;for(let i=18;i<bytes.length;i++)bytes[i]=i%251;
  const reference=executeResourceTask('tga',{buffer:bytes.buffer}),image=await pool.decode('tga',bytes);check(digest(image)===digest(reference),'TGA mismatch');
  report.benchmarks=[];
  for(const mode of ['main','workers','main','workers']){
   const gaps=[];let last=performance.now();const timer=setInterval(()=>{const at=performance.now();gaps.push(at-last);last=at;},4);await wait(25);const started=performance.now();
   if(mode==='workers')await Promise.all(Array.from({length:16},()=>pool.decode('tga',bytes)));
   else for(let i=0;i<16;i++)executeResourceTask('tga',{buffer:bytes.buffer});
   const elapsedMs=performance.now()-started;await wait(25);clearInterval(timer);report.benchmarks.push({mode,jobs:16,elapsedMs,maxMainThreadGapMs:Math.max(...gaps)});
  }
  report.pool=pool.snapshot();report.success=true;sources.dispose();return report;
 }finally{pool.dispose();}
};
