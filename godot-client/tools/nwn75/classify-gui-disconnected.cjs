'use strict';
// Static graph triage only: a missing literal connector is not a runtime claim.
const fs=require('node:fs'),path=require('node:path');
const directory=__dirname;
const files=fs.readdirSync(directory).filter(name=>name.endsWith('ledger.json'));
const edges=files.flatMap(file=>{const data=JSON.parse(fs.readFileSync(path.join(directory,file)));return (data.edges??[]).filter(edge=>edge.from&&edge.to).map(edge=>({...edge,file}));});
const adjacency=new Map(),incoming=new Map();
for(const edge of edges){if(!adjacency.has(edge.from))adjacency.set(edge.from,new Set());adjacency.get(edge.from).add(edge.to);if(!incoming.has(edge.to))incoming.set(edge.to,[]);incoming.get(edge.to).push(edge);}
const root='0x140c11bdc',seen=new Set([root]),queue=[root];
for(let i=0;i<queue.length;i++)for(const next of adjacency.get(queue[i])??[])if(!seen.has(next)){seen.add(next);queue.push(next);}
const selected=new Set(['gui-presentation-ledger.json','loadscreen-gui-owner-ledger.json','active-gui-text-render-ledger.json']);
const nodes=[...new Set(edges.filter(edge=>selected.has(edge.file)&&!seen.has(edge.from)).map(edge=>edge.from))];
const result=nodes.map(node=>({node,outgoing:(adjacency.get(node)??new Set()).size,incoming:(incoming.get(node)??[]).map(edge=>({from:edge.from,file:edge.file,kind:edge.kind,condition:edge.condition})).slice(0,6)}));
result.sort((a,b)=>a.incoming.length-b.incoming.length||b.outgoing-a.outgoing||a.node.localeCompare(b.node));
const query=process.argv.slice(2);
if(query.length){console.log(JSON.stringify({root,query:query.map(node=>({node,reachable:seen.has(node),incoming:(incoming.get(node)??[]).map(edge=>({from:edge.from,file:edge.file,kind:edge.kind})).slice(0,12),outgoing:[...(adjacency.get(node)??new Set())].slice(0,12)}))},null,2));}
else console.log(JSON.stringify({root,selectedFiles:[...selected],disconnectedSourceNodes:nodes.length,roots:result.filter(row=>row.incoming.length===0),sample:result.slice(0,35)},null,2));
