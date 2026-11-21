import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [capturePath,indexPath,label,...flags]=process.argv.slice(2);
if(!capturePath||!indexPath||!label||!/^[a-z0-9-]+$/.test(label)||flags.some(flag=>flag!=='--disassemble'))throw Error('Usage: annotate_mapped_kernel.mjs CAPTURE INDEX FRESH-LABEL [--disassemble]');
const input=path.resolve(capturePath),indexFile=path.resolve(indexPath),output=path.join(project,'.cache/native-render-gap/particles',label);
if(fs.existsSync(output))throw Error('Prior annotation evidence retained');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const raw=fs.readFileSync(input),capture=JSON.parse(raw),indexBytes=fs.readFileSync(indexFile),index=JSON.parse(indexBytes),binary=fs.readFileSync(index.binary);
if(hash(binary)!==index.binarySha256||hash(fs.readFileSync(index.map))!==index.mapSha256)throw Error('Exact mapped image/MAP pin mismatch');
if(!index.unwindFragments)throw Error('Recursive chained-unwind index required');
const module=capture.modules.findIndex(row=>row.sha256===index.binarySha256);
if(module<0)throw Error('This exact mapped image was not observed in the capture');
const c=Object.fromEntries(capture.columns.map((name,index)=>[name,index]));
for(const column of ['status','module_index','module_rva','began_us'])if(c[column]===undefined)throw Error('Missing capture column '+column);
const all=capture.samples.filter(row=>row[c.status]===0),kernel=all.filter(row=>row[c.module_index]===module);
const middleAll=all.filter(row=>row[c.began_us]>=5000000&&row[c.began_us]<25000000);
const middle=kernel.filter(row=>row[c.began_us]>=5000000&&row[c.began_us]<25000000);
const fragments=[...index.unwindFragments].sort((a,b)=>a.begin-b.begin),functions=[...index.functions].sort((a,b)=>a.rva-b.rva),byStart=new Map(functions.map(row=>[row.rva,row]));
for(let n=1;n<fragments.length;++n)if(fragments[n-1].end>fragments[n].begin)throw Error('Overlapping runtime-function fragments');
function preceding(rows,rva,start){
 let lo=0,hi=rows.length-1,found=null;
 while(lo<=hi){const mid=(lo+hi)>>1,row=rows[mid];if(start(row)<=rva){found=row;lo=mid+1;}else hi=mid-1;}
 return found;
}
function lookup(rva){
 const fragment=preceding(fragments,rva,row=>row.begin);
 if(fragment&&rva<fragment.end){
  const symbol=byStart.get(fragment.owner_rva);
  return symbol?{symbol,range_source:'Exact PE x64 RUNTIME_FUNCTION fragment with recursive chained-unwind ownership'}:null;
 }
 const leaf=preceding(functions,rva,row=>row.rva);
 // A chained function's broad end spans holes. Never treat those holes as exact
 // ownership; only symbols without any pdata fragments get the leaf fallback.
 return leaf&&!leaf.ranges?.length&&rva<leaf.end_rva?{symbol:leaf,range_source:'Approximate next-MAP-symbol leaf/padding interval; no runtime-function fragment'}:null;
}
function aggregate(rows,total){
 const groups=new Map();
 for(const row of rows){
  const rva=row[c.module_rva],hit=lookup(rva),symbol=hit?.symbol,key=symbol?.rva??-1;
  let group=groups.get(key);
  if(!group){group={rva:key,end_rva:symbol?.end_rva??null,aliases:symbol?.aliases??[],range_source:hit?.range_source??'Unmapped or unnamed exact fragment',count:0,points:new Map(),blocks:new Map()};groups.set(key,group);}
  ++group.count;group.points.set(rva,(group.points.get(rva)??0)+1);const block=rva&~63;group.blocks.set(block,(group.blocks.get(block)??0)+1);
 }
 return [...groups.values()].sort((a,b)=>b.count-a.count).map(group=>({...group,allSampleFraction:total?group.count/total:0,kernelSampleFraction:rows.length?group.count/rows.length:0,points:[...group.points].sort((a,b)=>b[1]-a[1]).map(([rva,count])=>({rva,count})),blocks:[...group.blocks].sort((a,b)=>b[1]-a[1]).map(([rva,count])=>({rva,end_rva:rva+64,count}))}));
}
const full=aggregate(kernel,all.length),mid=aggregate(middle,middleAll.length),disassembly=[];
fs.mkdirSync(output,{recursive:true});
if(flags.includes('--disassemble')){
 const selected=full.filter(row=>row.rva>=0).slice(0,8);
 const dumpbin='C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/dumpbin.exe';
 const base=BigInt(index.imageBase);
 for(const row of selected){
  if(row.end_rva-row.rva>65536)throw Error('Disassembly request exceeds bounded physical range');
  const start='0x'+(base+BigInt(row.rva)).toString(16),end='0x'+(base+BigInt(row.end_rva-1)).toString(16);
  const result=spawnSync(dumpbin,['/nologo','/DISASM:BYTES','/RANGE:'+start+','+end,index.binary],{windowsHide:true,encoding:'utf8',maxBuffer:8*1024*1024,timeout:10000});
  if(result.status!==0)throw Error('Bounded disassembly failed');
  const file=path.join(output,'function-'+row.rva.toString(16)+'.asm.txt');fs.writeFileSync(file,result.stdout);
  const instructions=[];
  for(const line of result.stdout.split(/\r?\n/)){const match=/^\s+([0-9A-F]{16}):\s+(.+)$/.exec(line);if(match)instructions.push({rva:Number(BigInt('0x'+match[1])-base),line:match[2]});}
  const hot=row.points.slice(0,12).map(point=>{const at=instructions.findIndex(item=>item.rva===point.rva);return {...point,instructions:at>=0?instructions.slice(Math.max(0,at-2),at+3):[]};});
  disassembly.push({rva:row.rva,end_rva:row.end_rva,aliases:row.aliases,file,sha256:hash(fs.readFileSync(file)),hot});
 }
}
const receipt={version:2,scope:'Exact-image kernel leaf RIP annotation; not inclusive call stacks or FPS evidence',input,inputSha256:hash(raw),indexFile,indexSha256:hash(indexBytes),binarySha256:index.binarySha256,moduleIndex:module,allValid:all.length,kernelSamples:kernel.length,middleAllValid:middleAll.length,middleKernelSamples:middle.length,full,middle:mid,disassembly,limitations:['Only the captured owned main thread is sampled; engine callees leave the DLL, so DLL leaf fractions are not inclusive particle cost.','Identical-code-fold aliases remain ambiguous.','Exact recursive unwind fragments take precedence. Approximate leaf fallback never claims a gap inside a chained function.','Full capture and conservative [5,25) second subsets are retained; independent parent evidence must establish that the interval is steady rendering.']};
fs.writeFileSync(path.join(output,'annotation.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({output,allValid:all.length,kernelSamples:kernel.length,middleAllValid:middleAll.length,middleKernelSamples:middle.length,top:full.slice(0,10).map(({rva,end_rva,aliases,range_source,count,allSampleFraction,blocks})=>({rva:rva<0?null:'0x'+rva.toString(16),end_rva:end_rva===null?null:'0x'+end_rva.toString(16),aliases,range_source,count,allSampleFraction,blocks:blocks.slice(0,4)}))},null,2));
