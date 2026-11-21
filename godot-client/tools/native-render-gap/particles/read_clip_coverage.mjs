import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),file=path.resolve(process.argv[2]??path.join(project,'reports/render-gap-resident-legacy-v7-c-a.native.json')),output=path.join(project,'.cache/native-render-gap/particles/clip-coverage-resident-a.json');
if(fs.existsSync(output))throw Error('Retain earlier cold coverage');
const raw=fs.readFileSync(file),data=JSON.parse(raw),found=[],stack=[{key:'root',value:data}];
while(stack.length){const {key,value}=stack.pop();if(!value||typeof value!=='object')continue;if(value.kind==='native-render-gap-particle-source-census')found.push({key,census:value});if(Array.isArray(value)){for(let n=0;n<value.length;++n)if(value[n]&&typeof value[n]==='object')stack.push({key:key+'['+n+']',value:value[n]});}else for(const [name,child] of Object.entries(value))if(child&&typeof child==='object')stack.push({key:key+'.'+name,value:child});}
const rows=found.map(({key,census})=>{
 const cohorts=new Map();let present=0,allEmpty=0,selectedEmpty=0;
 for(const row of census.rows){if(row.compiled_source_all_clips_empty!==undefined)++present;if(row.compiled_source_all_clips_empty)++allEmpty;if(row.selected_channels===0)++selectedEmpty;const label=[row.chunk?'chunk':'sprite',row.clock,row.compiled_source_all_clips_empty?'all-empty':'other'].join('/');cohorts.set(label,(cohorts.get(label)??0)+1);}
 return {key,members:census.rows.length,fieldsPresent:present,compiledSourceAllEmpty:allEmpty,selectedEmpty,counts:census.counts,cohorts:[...cohorts].sort((a,b)=>b[1]-a[1])};
});
const result={file,sha256:crypto.createHash('sha256').update(raw).digest('hex'),rows,scope:'Existing post-timing cold GDScript compiled-source hint only. Actual private native copied clips and skip activation require dispatch22 in the separate empty-clips prototype. No runtime/clock/controller/Node call performed.'};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,...result},null,2));
