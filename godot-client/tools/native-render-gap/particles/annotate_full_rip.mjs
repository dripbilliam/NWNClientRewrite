import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [capturePath,engineIndexPath,kernelIndexPath,label]=process.argv.slice(2);
if(!capturePath||!engineIndexPath||!kernelIndexPath||!label||!/^[a-z0-9-]+$/.test(label))throw Error('Usage: annotate_full_rip.mjs CAPTURE ENGINE-UNWIND-INDEX KERNEL-INDEX FRESH-LABEL');
const output=path.join(project,'.cache/native-render-gap/particles',label);
if(fs.existsSync(output))throw Error('Retain earlier annotation');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
const readJson=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const input=path.resolve(capturePath),engineFile=path.resolve(engineIndexPath),kernelFile=path.resolve(kernelIndexPath);
const raw=fs.readFileSync(input),capture=JSON.parse(raw),engine=readJson(engineFile),kernel=readJson(kernelFile);
if(hash(fs.readFileSync(engine.binary.file))!==engine.binary.sha256||hash(fs.readFileSync(kernel.binary))!==kernel.binarySha256)throw Error('Exact mapped engine/kernel image drift');
if(hash(fs.readFileSync(engine.map.file))!==engine.map.sha256||hash(fs.readFileSync(kernel.map))!==kernel.mapSha256)throw Error('Retained exact MAP/index drift');
const engineModule=capture.modules.findIndex(row=>row.sha256===engine.binary.sha256),kernelModule=capture.modules.findIndex(row=>row.sha256===kernel.binarySha256);
if(engineModule<0||kernelModule<0||engineModule===kernelModule)throw Error('Both exact mapped images must be observed as distinct captured modules');
const c=Object.fromEntries(capture.columns.map((name,index)=>[name,index]));
for(const name of ['status','module_index','module_rva','began_us'])if(c[name]===undefined)throw Error('Missing capture column '+name);
const engineColumns=Object.fromEntries(engine.columns.map((name,index)=>[name,index]));
for(const name of ['begin_rva','end_rva','exact_begin_names'])if(engineColumns[name]===undefined)throw Error('Engine exact unwind schema missing '+name);
const engineFragments=engine.unwindFragments??engine.rows.map(row=>({begin:row[engineColumns.begin_rva],end:row[engineColumns.end_rva],owner_rva:row[engineColumns.begin_rva]}));
const engineNames=new Map();
for(const row of engine.rows)engineNames.set(row[engineColumns.begin_rva],row[engineColumns.exact_begin_names]);
const kernelNames=new Map(kernel.functions.map(row=>[row.rva,row.aliases]));
if(!kernel.unwindFragments)throw Error('Kernel recursive chained-unwind index is required');
function prepareFragments(rows){
 const result=[...rows].sort((a,b)=>a.begin-b.begin);
 for(let n=1;n<result.length;++n)if(result[n-1].end>result[n].begin)throw Error('Overlapping exact runtime functions');
 return result;
}
const exact={engine:prepareFragments(engineFragments),kernel:prepareFragments(kernel.unwindFragments)};
function containing(rows,rva){
 let lo=0,hi=rows.length-1,found=null;
 while(lo<=hi){const mid=(lo+hi)>>1,row=rows[mid];if(row.begin<=rva){found=row;lo=mid+1;}else hi=mid-1;}
 return found&&rva<found.end?found:null;
}
function classify(row){
 const module=row[c.module_index],rva=row[c.module_rva];
 const kind=module===engineModule?'engine':module===kernelModule?'kernel':'other';
 if(kind==='other')return {kind,module,physicalStart:null,names:[],range_source:'Module only; no function attribution'};
 const fragment=containing(exact[kind],rva);
 if(!fragment)return {kind,module,physicalStart:null,names:[],range_source:'No exact runtime-function coverage; deliberately unresolved'};
 const owner=fragment.owner_rva??fragment.begin,names=(kind==='engine'?engineNames:kernelNames).get(owner)??[];
 return {kind,module,physicalStart:owner,names,range_source:names.length?'Exact runtime-function fragment/root and exact-begin name':'Exact runtime-function fragment/root; function name unresolved',fragment};
}
function aggregate(rows){
 const modules=new Map(),groups=new Map();
 for(const row of rows){
  const hit=classify(row),rva=row[c.module_rva],key=hit.kind==='other'?'module:'+hit.module:hit.kind+':'+hit.physicalStart;
  modules.set(hit.module,(modules.get(hit.module)??0)+1);
  let group=groups.get(key);
  if(!group){group={kind:hit.kind,moduleIndex:hit.module,physicalStart:hit.physicalStart,names:hit.names,range_source:hit.range_source,count:0,points:new Map(),blocks:new Map(),fragments:new Map()};groups.set(key,group);}
  ++group.count;group.points.set(rva,(group.points.get(rva)??0)+1);const block=rva&~63;group.blocks.set(block,(group.blocks.get(block)??0)+1);
  if(hit.fragment)group.fragments.set(hit.fragment.begin,hit.fragment);
 }
 const functions=[...groups.values()].sort((a,b)=>b.count-a.count).map(group=>({...group,allSampleFraction:rows.length?group.count/rows.length:0,points:[...group.points].sort((a,b)=>b[1]-a[1]).map(([rva,count])=>({rva,count})),blocks:[...group.blocks].sort((a,b)=>b[1]-a[1]).map(([rva,count])=>({rva,end_rva:rva+64,count})),fragments:[...group.fragments.values()]}));
 return {validSamples:rows.length,modules:[...modules].sort((a,b)=>b[1]-a[1]).map(([index,count])=>({index,count,allSampleFraction:rows.length?count/rows.length:0,descriptor:capture.modules[index]??null})),functions};
}
const valid=capture.samples.filter(row=>row[c.status]===0),middle=valid.filter(row=>row[c.began_us]>=5000000&&row[c.began_us]<25000000);
const full=aggregate(valid),mid=aggregate(middle);
const result={version:1,scope:'Whole owned-main-thread leaf RIP attribution using exact observed engine/DLL images and runtime-function boundaries only. No nearest-label or next-symbol function claims.',capture:{file:input,sha256:hash(raw),columns:capture.columns,totalSamples:capture.samples.length,validSamples:valid.length,invalidSamples:capture.samples.length-valid.length},engine:{index:engineFile,indexSha256:hash(fs.readFileSync(engineFile)),imageSha256:engine.binary.sha256,moduleIndex:engineModule},kernel:{index:kernelFile,indexSha256:hash(fs.readFileSync(kernelFile)),imageSha256:kernel.binarySha256,moduleIndex:kernelModule},full,middle:mid,middleIntervalUs:[5000000,25000000],limitations:['These are leaf samples, not call stacks or inclusive subsystem time. Engine callees may be called from particle, animation, scripts, or another subsystem.','Exact physical functions with no exact-begin name remain unnamed; no preceding public linker label is assigned.','Functions with identical-code-fold aliases remain ambiguous.','Main-thread/process/window/steady-interval qualification belongs to the independent capture receipt; this tool does not infer steady rendering from a file name.','The middle subset is [5,25) seconds relative to capture began_us, not process age.']};
fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'annotation.json'),JSON.stringify(result,null,2)+'\n');
const compact=summary=>({validSamples:summary.validSamples,modules:summary.modules.map(row=>({index:row.index,count:row.count,allSampleFraction:row.allSampleFraction})),top:summary.functions.slice(0,16).map(({kind,moduleIndex,physicalStart,names,range_source,count,allSampleFraction,blocks})=>({kind,moduleIndex,physicalStart:physicalStart===null?null:'0x'+physicalStart.toString(16),names:names.map(name=>name.length>200?name.slice(0,200)+'...':name),range_source,count,allSampleFraction,blocks:blocks.slice(0,3)}))});
console.log(JSON.stringify({output,sha256:hash(fs.readFileSync(path.join(output,'annotation.json'))),full:compact(full),middle:compact(mid)},null,2));
