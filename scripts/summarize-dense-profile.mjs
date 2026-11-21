import fs from 'node:fs/promises';
import {SourceMap} from 'node:module';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const version=process.argv[2]??'v1';if(!/^[a-z0-9-]+$/.test(version))throw Error('Invalid version');
const dir=new URL('../backups/animations/',import.meta.url),hash=b=>createHash('sha256').update(b).digest('hex');
const report=JSON.parse(await fs.readFile(new URL(`dense-local-${version}.json`,dir)));
const requestedManifest=process.argv[3];if(requestedManifest&&!/^[a-z0-9-]+\.json$/.test(requestedManifest))throw Error('Invalid source manifest');
let manifest=JSON.parse(await fs.readFile(new URL(requestedManifest??'creation-performance-entry-source-v1.json',dir)));
for(const name of ['resident-palette-source-v1.json','cached-root-matrix-source-v1.json','frame-work-baseline-source-v1.json','frame-work-candidate-source-v1.json','material-reuse-candidate-source-v1.json','material-reuse-baseline-source-v1.json','light-uniforms-matrices-source-v1.json','light-uniforms-rejected-source-v1.json','light-uniforms-baseline-source-v1.json','managed-matrices-baseline-source-v1.json','main-batches-rejected-source-v1.json','main-batches-baseline-source-v1.json','model-geometry-baseline-source-v1.json','shadow-instances-baseline-source-v1.json','model-batch-baseline-source-v1.json','dense-local-baseline-source-v1.json']){if(manifest.bundle===report.bundle)break;try{manifest=JSON.parse(await fs.readFile(new URL(name,dir)));}catch(error){if(error.code!=='ENOENT')throw error;}}
assert.equal(report.bundle,manifest.bundle);const mapBytes=await fs.readFile(new URL(manifest.map,dir)),map=new SourceMap(JSON.parse(mapBytes));assert.equal(hash(mapBytes),manifest.mapSha256);
const results=[];
for(const item of report.profiles){
 const bytes=await fs.readFile(new URL(item.file,dir)),p=JSON.parse(bytes),nodes=new Map(p.nodes.map(n=>[n.id,n])),parents=new Map(),labels=new Map(),functions=new Map(),sources=new Map();
 for(const n of p.nodes)for(const id of n.children??[])parents.set(id,n.id);
 for(const n of p.nodes){const f=n.callFrame;let source=f.url||'<native or VM>',line=f.lineNumber,name=f.functionName||'<anonymous>';if(f.url.endsWith('/'+manifest.bundle)){const e=map.findEntry(f.lineNumber,f.columnNumber);if(e.originalSource!==undefined){source=e.originalSource;line=e.originalLine;name=e.name??name;}}if(['(idle)','(garbage collector)','(program)','(root)'].includes(name))source=name;labels.set(n.id,{source,line:line+1,name});}
 const add=(t,k,label)=>{const row=t.get(k)??{...label,selfMs:0,inclusiveMs:0};t.set(k,row);return row;};
 for(let i=0;i<p.samples.length;i++){const ms=p.timeDeltas[i]/1000;let id=p.samples[i],first=true;const seen=new Set(),fnSeen=new Set();while(id!==undefined){const label=labels.get(id),key=JSON.stringify(label);if(!fnSeen.has(key)){const row=add(functions,key,label);row.inclusiveMs+=ms;if(first)row.selfMs+=ms;fnSeen.add(key);}if(!seen.has(label.source)){const row=add(sources,label.source,{source:label.source});row.inclusiveMs+=ms;if(first)row.selfMs+=ms;seen.add(label.source);}first=false;id=parents.get(id);}}
 const sorted=t=>[...t.values()].sort((a,b)=>b.selfMs-a.selfMs).map(r=>({...r,selfMs:+r.selfMs.toFixed(3),inclusiveMs:+r.inclusiveMs.toFixed(3)}));
 results.push({phase:item.name,sha256:hash(bytes),durationMs:(p.endTime-p.startTime)/1000,topSelfSources:sorted(sources).slice(0,30),topSelfFunctions:sorted(functions).slice(0,35),topInclusiveSources:sorted(sources).sort((a,b)=>b.inclusiveMs-a.inclusiveMs).slice(0,20)});
}
await fs.writeFile(new URL(`dense-local-${version}-cpu-summary.json`,dir),JSON.stringify({scope:'Renderer CPU stack samples, not GPU timings; inclusive times overlap',bundle:manifest.bundle,results},null,2)+'\n');
console.log(JSON.stringify(results.map(r=>({phase:r.phase,durationMs:r.durationMs,sources:r.topSelfSources.slice(0,12),functions:r.topSelfFunctions.slice(0,12)}))));
