import fs from 'node:fs/promises';
import {SourceMap} from 'node:module';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const version=process.argv[2]??'v14';assert.match(version,/^[a-z0-9-]+$/);
const dir=new URL('../backups/animations/',import.meta.url),read=async name=>JSON.parse(await fs.readFile(new URL(name,dir)));
const requestedManifest=process.argv[3];if(requestedManifest&&!/^[a-z0-9-]+\.json$/.test(requestedManifest))throw Error('Invalid source manifest');
const report=await read(`dense-local-${version}.json`),manifest=await read(requestedManifest??'creation-performance-entry-source-v1.json');assert.equal(report.bundle,manifest.bundle);
const mapBytes=await fs.readFile(new URL(manifest.map,dir));assert.equal(createHash('sha256').update(mapBytes).digest('hex'),manifest.mapSha256);const map=new SourceMap(JSON.parse(mapBytes));
const output=[];
for(const item of report.profiles.filter(p=>p.name.startsWith('steady'))){
 const p=await read(item.file),nodes=new Map(p.nodes.map(n=>[n.id,n])),parents=new Map(),labels=new Map(),rows=new Map();
 for(const n of p.nodes){for(const child of n.children??[])parents.set(child,n.id);const f=n.callFrame;let source=f.url,name=f.functionName,line=f.lineNumber+1;if(f.url.endsWith('/'+manifest.bundle)){const e=map.findEntry(f.lineNumber,f.columnNumber);if(e.originalSource!==undefined){source=e.originalSource;name=e.name??name;line=e.originalLine+1;}}labels.set(n.id,{source,name,line});}
 for(let i=0;i<p.samples.length;i++){
  const first=labels.get(p.samples[i]);if(!['updateMatrixWorld','updateWorldMatrix','updateMatrix','compose','multiplyMatrices','traverseVisible'].includes(first.name))continue;
  let id=p.samples[i];const trail=[];while(id!==undefined){const label=labels.get(id);trail.push(`${label.source}:${label.line} ${label.name}`);id=parents.get(id);}
  const caller=trail.findIndex(t=>!t.includes('three.core.js')&&!t.includes('three.module.js'));const stack=trail.slice(Math.max(0,caller),Math.max(0,caller)+5),key=JSON.stringify(stack),row=rows.get(key)??{stack,ms:0};row.ms+=p.timeDeltas[i]/1000;rows.set(key,row);
 }
 output.push({phase:item.name,callers:[...rows.values()].sort((a,b)=>b.ms-a.ms).map(r=>({...r,ms:+r.ms.toFixed(3)}))});
}
await fs.writeFile(new URL(`dense-local-${version}-transform-summary.json`,dir),JSON.stringify(output,null,2)+'\n');console.log(JSON.stringify(output.map(r=>({...r,callers:r.callers.slice(0,12)}))));
