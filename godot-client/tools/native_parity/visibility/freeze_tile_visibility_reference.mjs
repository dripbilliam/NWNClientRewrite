// Frozen differential data ONLY; this is not imported by the game/transport.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {projectNativeTileVisibility as project} from '../../../../src/native_tile_visibility.js';
const root=process.cwd(),target=path.resolve(process.argv[2]??'');
const boundary=path.join(root,'godot-client/.cache/native-presentation-parity/render-agent')+path.sep;
if(!target.startsWith(boundary)||fs.existsSync(target))throw Error('Fresh owned target required');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const reference=path.join(root,'src/native_tile_visibility.js');
if(sha(reference)!=='d9bc7d33dfabfe1b35b785fe87073429721ebe636dc299f458b64492f927c70f')throw Error('Reference source changed');
const rows=[],add=(name,input)=>rows.push({name,input,expected:project(input)});
const base=(previous,change,width=3,height=2)=>({previous,change,width,height});
add('delta-repeated',base([0,0,1,0,0,0],{mode:[0,0],points:[{state:1,x:1,y:0},{state:0,x:1,y:0},{state:1,x:1,y:0},{state:1,x:2,y:0}]}));
add('full-hide-before-listed-reveal',base([1,0,0,0,0,0],{mode:[1,0],points:[{x:0,y:0},{x:2,y:1}]}));
add('full-reveal-all',base([1,0,0,0,1,0],{mode:[true,false],points:[]}));
add('partial-packed-tail',base(Array(12).fill(1),{mode:[0,1],bytes:[129]},4,3));
add('both-true-native-packed',base([0,0,0,0,0,0],{mode:[1,1],bytes:[41],points:'ignored'}));
add('empty-packed',base([1,0,1,0,1,0],{mode:[true,true],bytes:[]}));
add('out-of-area-points',base([0,0,0,0,0,0],{mode:[0,0],points:[{state:1,x:3,y:0},{state:1,x:2,y:1},{state:0,x:255,y:255}]}));
add('native-integer-old',base([2,-1,0,0,0,0],{mode:[0,0],points:[{state:1,x:0,y:0},{state:0,x:1,y:0}]}));
add('scoped-evidence',{...base([0,0,0,0,0,0],{mode:[0,0],points:[{state:true,x:0,y:0}]}),delivery:{scope:'connection7/area4/observer8',serial:92,ignored:'not-copied'}});
let seed=0x850120;
const random=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n;};
for(let n=0;n<80;n++){
 const width=1+random(4),height=1+random(4),previous=Array.from({length:width*height},()=>[-1,0,1,2][random(4)]),mode=[random(2),random(2)];
 const change={mode};
 if(mode[1])change.bytes=Array.from({length:random(4)},()=>random(256));
 else change.points=Array.from({length:random(7)},()=>({state:random(2),x:random(width+2),y:random(height+2)}));
 add(`seeded-${n}`,{previous,change,width,height,delivery:{scope:'fixture-only/area2',serial:n}});
}
const valid=base([0,0,0,0,0,0],{mode:[0,0],points:[]});
for(const [name,input] of [
 ['missing-input',null],['missing-states',{...valid,previous:null}],['short-states',{...valid,previous:[0]}],['invalid-old',{...valid,previous:[0,0,null,0,0,0]}],
 ['zero-width',{...valid,width:0}],['oversized-grid',{...valid,width:65536,height:2}],['missing-mode',{...valid,change:{}}],['string-mode',{...valid,change:{mode:['0',0],points:[]}}],
 ['missing-point-state',{...valid,change:{mode:[0,0],points:[{x:0,y:0}]}}],['bad-coordinate',{...valid,change:{mode:[0,0],points:[{state:1,x:-1,y:0}]}}],
 ['bad-packed',{...valid,change:{mode:[0,1],bytes:[256]}}],['missing-packed',{...valid,change:{mode:[0,1]}}],['empty-scope',{...valid,delivery:{scope:'',serial:1}}],['negative-serial',{...valid,delivery:{scope:'x',serial:-1}}]
])add(name,input);
const xy=[];
const floatWord=value=>{const bytes=Buffer.alloc(4);bytes.writeFloatLE(value);return bytes.readUInt32LE();};
for(const center of [[0,0],[5,5],[155,255],[-5,-15]]){
 const half=Math.fround(5.0001),lo=center.map(x=>Math.fround(Math.fround(x)-half)),hi=center.map(x=>Math.fround(Math.fround(x)+half));
 for(const position of [[center[0],center[1],999],[lo[0],lo[1],-999],[hi[0],hi[1],null],[lo[0]-.00001,center[1]],[hi[0]+.00001,center[1]],[center[0],hi[1]+.00001]]){
  const p=position.slice(0,2).map(Math.fround);xy.push({center,position,expected:{available:true,contains:p[0]>=lo[0]&&p[0]<=hi[0]&&p[1]>=lo[1]&&p[1]<=hi[1],minimum_native_xy:lo,maximum_native_xy:hi,reason:'native-inclusive-xy'},minimum_f32_words:lo.map(floatWord),maximum_f32_words:hi.map(floatWord)});
 }
}
const output={kind:'frozen-standalone-node-reference-not-native-oracle',reference:{path:'src/native_tile_visibility.js',sha256:sha(reference)},native_evidence:{path:'godot-client/tools/native_parity/visibility/evidence/native-tile-reveal-owner-v1.json',sha256:sha(path.join(root,'godot-client/tools/native_parity/visibility/evidence/native-tile-reveal-owner-v1.json')),binary_sha256:'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'},generator_sha256:sha(new URL(import.meta.url)),rows,xy_cases:xy};
fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({target,rows:rows.length,xy_cases:xy.length,sha256:sha(target),scope:output.kind}));
