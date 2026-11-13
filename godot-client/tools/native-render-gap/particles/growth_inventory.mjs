import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2]??'growth-inventory-a';
if(!/^[a-z0-9-]+$/.test(label))throw Error('Fresh audit label required');
const output=path.join(project,'.cache/prune-audit-20261108',label);
if(fs.existsSync(output))throw Error('Retain earlier audit evidence');
const rootPaths=(process.argv.includes('--production-only')?['.cache/native-presentation-parity/production-replay']:['.cache/native-render-gap','.cache/native-presentation-parity/production-replay']).map(relative=>path.join(project,relative));
const started=Date.now(),budgetMs=10000,cutoff=Date.parse('2026-11-08T14:00:00Z');
const totals={files:0,bytes:0,directories:0,symlinksSkipped:0,errors:0,complete:true},roots=[],large=[],generated=new Map(),extensions=new Map(),levels=new Map(),sameNameSize=new Map(),errors=[];
function add(map,key,bytes){const row=map.get(key)??{key,files:0,bytes:0};++row.files;row.bytes+=bytes;map.set(key,row);}
for(const root of rootPaths){
 if(!fs.existsSync(root)){roots.push({root,exists:false});continue;}
 const summary={root,exists:true,files:0,bytes:0,directories:0};roots.push(summary);const stack=[root];
 while(stack.length){
  if(Date.now()-started>budgetMs){totals.complete=false;summary.remainingDirectories=stack.length;break;}
  const directory=stack.pop();++totals.directories;++summary.directories;let entries;
  try{entries=fs.readdirSync(directory,{withFileTypes:true});}catch(error){++totals.errors;errors.push({file:directory,error:error.message});continue;}
  for(const entry of entries){
   const file=path.join(directory,entry.name);if(entry.isSymbolicLink()){++totals.symlinksSkipped;continue;}
   if(entry.isDirectory()){if(entry.name!=='.git')stack.push(file);continue;}
   if(!entry.isFile())continue;
   let stat;try{stat=fs.statSync(file);}catch(error){++totals.errors;errors.push({file,error:error.message});continue;}
   ++totals.files;++summary.files;totals.bytes+=stat.size;summary.bytes+=stat.size;
   const relative=path.relative(root,file).split(path.sep),rootName=path.relative(project,root).replaceAll('\\','/');
   for(const prefix of new Set([1,2,3].map(depth=>rootName+'/'+relative.slice(0,Math.min(depth,relative.length-1)).join('/'))))add(levels,prefix,stat.size);
   add(extensions,rootName+' | '+(path.extname(file).toLowerCase()||'<none>'),stat.size);
   const portable=file.replaceAll('\\','/'),shader=portable.indexOf('/.godot/shader_cache/'),imported=portable.indexOf('/.godot/imported/');
   if(shader>=0)add(generated,portable.slice(0,shader) + '/.godot/shader_cache',stat.size);
   if(imported>=0)add(generated,portable.slice(0,imported) + '/.godot/imported',stat.size);
   if(stat.size>=8*1024*1024){
    const row={file,bytes:stat.size,modifiedUtc:stat.mtime.toISOString(),links:stat.nlink,extension:path.extname(file).toLowerCase()};large.push(row);
    const key=entry.name.toLowerCase()+'|'+stat.size;let group=sameNameSize.get(key);if(!group){group={name:entry.name,bytesEach:stat.size,files:[]};sameNameSize.set(key,group);}group.files.push(row);
   }
  }
 }
 if(!totals.complete)break;
}
const sort=map=>[...map.values()].sort((a,b)=>b.bytes-a.bytes);
const duplicateHints=[...sameNameSize.values()].filter(row=>row.files.length>1).map(row=>({...row,count:row.files.length,totalBytes:row.files.length*row.bytesEach,potentialExtraLogicalBytes:(row.files.length-1)*row.bytesEach,proof:'Same basename and logical length only; content equality and physical allocation are not inferred'})).sort((a,b)=>b.potentialExtraLogicalBytes-a.potentialExtraLogicalBytes);
const compression=large.filter(row=>['.json','.jsonl'].includes(row.extension)&&Date.parse(row.modifiedUtc)<cutoff&&!row.file.replaceAll('\\','/').includes('/native-render-gap/engine/source/')).map(row=>({file:row.file,bytes:row.bytes,modifiedUtc:row.modifiedUtc,action:'ntfs-compress-only',delete:false,reviewRequired:true,scope:'Retain all bytes and paths. Candidate only; inactivity, existing compression and any frozen-source policy require parent review.'}));
const result={version:1,startedUtc:new Date(started).toISOString(),finishedUtc:new Date().toISOString(),roots,totals,topLevels:sort(levels),extensions:sort(extensions),generatedCaches:sort(generated),largestFiles:large.sort((a,b)=>b.bytes-a.bytes),sameNameSizeDuplicateHints:duplicateHints,errors,limitations:['Read-only logical-size inventory, not NTFS allocated size. Compression/sparse/hardlinks may change physical usage.','Directory junctions/symlinks are skipped. Enumeration is restricted to the two named cache roots and stops after10seconds.','Same-name/length duplicate hints are not hash equality proof.','No generated cache is declared deletable by this inventory; source/runtime/receipt pins and regeneration must be checked separately.']};
fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'inventory.json'),JSON.stringify(result,null,2)+'\n');fs.writeFileSync(path.join(output,'compression-candidates.json'),JSON.stringify(compression,null,2)+'\n');
console.log(JSON.stringify({output,elapsedMs:Date.now()-started,totals,roots,topLevels:result.topLevels.slice(0,25),extensions:result.extensions.slice(0,12),generatedCaches:result.generatedCaches.slice(0,12),duplicates:duplicateHints.slice(0,8).map(({name,count,bytesEach,potentialExtraLogicalBytes})=>({name,count,bytesEach,potentialExtraLogicalBytes})),compressionCount:compression.length,compressionLogicalBytes:compression.reduce((sum,row)=>sum+row.bytes,0)},null,2));
