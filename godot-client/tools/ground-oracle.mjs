import fs from 'node:fs/promises';import {findWalkableHeight} from '../../src/walkmesh.js';
const output=process.argv.find(a=>a.startsWith('--output='))?.slice(9);if(!output)throw Error('Provide unused --output');
const triangles=[[[0,0,0],[10,1,0],[0,2,10]],[[10,1,0],[10,3,10],[0,2,10]],[[0,5,0],[10,6,0],[0,7,10]],[[10,6,0],[10,8,10],[0,7,10]],[[0,0,0],[0,0,0],[0,0,0]],[[10,3,0],[20,3,0],[10,3,10]],[[100000010,2,0],[100000020,2,0],[100000010,2,10]]];
let seed=8193;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;},queries=[];
for(let i=0;i<1500;i++){const x=Math.fround(i%100===0?10:random()*24-2),y=Math.fround(-random()*14+2),z=Math.fround(random()*10-1),value=findWalkableHeight(triangles.map(vertices=>({vertices})),x,-y,z);queries.push({position:[x,y,z],height:value??z});}
await fs.writeFile(output,JSON.stringify({scope:'Authored layered/sloped/degenerate/index-boundary ground; existing exact barycentric query as reference',triangles,queries})+'\n',{flag:'wx'});console.log(JSON.stringify({queries:queries.length,output}));
