'use strict';
// Deterministic mutation/ownership model for the private pair-volume BVH.
// This checks relation semantics and query membership; compiled engine and
// pixel/timing gates are separate and still required.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const sourceRoot=path.join(root,'.cache/nwn74/engine-source-a/servers/rendering');
const cpp=fs.readFileSync(path.join(sourceRoot,'renderer_scene_cull.cpp'),'utf8');
const header=fs.readFileSync(path.join(sourceRoot,'renderer_scene_cull.h'),'utf8');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
for(const text of ['INDEXER_PAIR_VOLUMES','pair_volume_indexer_id','nwn74_consumer_pair_index_requested'])assert(cpp.includes(text)||header.includes(text),'Private source missing '+text);
const seedInitial=0x9e3779b9;let seed=seedInitial;
function rand(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return seed>>>0;}
const size=148;
function makeNode(id){const kind=id<64?'geometry':id<144?'light':id%2?'voxel':'lightmap';return{id,kind,scenario:id%3,visible:true,indexed:false,pairIndexed:false,x:rand()%240,y:rand()%240,z:rand()%40,range:kind==='light'?35:kind==='geometry'?5:50,layer:1<<(rand()%4),mask:rand()%16,shadow:kind==='light'&&id%17===0,projector:kind==='light'&&id%31===0,soft:kind==='light'&&id%43===0,cacheShadow:false,cacheProjector:false,cacheSoft:false,first:true};}
const initial=Array.from({length:size},(_,id)=>makeNode(id));
class World{
 constructor(candidate,clustered=true){this.candidate=candidate;this.clustered=clustered;this.nodes=structuredClone(initial);this.pairs=new Set();this.stats={primaryVisits:0,pairVisits:0,indexInsert:0,indexUpdate:0,indexRemove:0,peakLeaves:0,repairs:0};this.queue=[];}
 key(a,b){return a.id<b.id?a.id+':'+b.id:b.id+':'+a.id;}
 consumer(n){return n.cacheShadow||n.cacheProjector||n.cacheSoft;}
 shouldIndex(n){return n.kind!=='geometry'&&(n.kind!=='light'||this.consumer(n));}
 intersect(a,b){return Math.abs(a.x-b.x)<a.range+b.range&&Math.abs(a.y-b.y)<a.range+b.range&&Math.abs(a.z-b.z)<a.range+b.range;}
 meaningful(a,b){return (a.kind==='geometry'&&b.kind!=='geometry')||(b.kind==='geometry'&&a.kind!=='geometry')||a.kind==='light'&&b.kind==='voxel'||a.kind==='voxel'&&b.kind==='light';}
 filter(a,b){if(!this.clustered)return true;const light=a.kind==='geometry'&&b.kind==='light'?b:b.kind==='geometry'&&a.kind==='light'?a:null;return !light||this.consumer(light);}
 enqueue(n){if(!this.queue.includes(n.id))this.queue.push(n.id);}
 unpair(n){for(const key of [...this.pairs])if(key.startsWith(n.id+':')||key.endsWith(':'+n.id))this.pairs.delete(key);if(n.pairIndexed){n.pairIndexed=false;this.stats.indexRemove++;}n.indexed=false;}
 repair(n){this.stats.repairs++;if(!n.visible)return;
  if(n.kind==='light'){n.cacheShadow=n.shadow;if(n.first){n.cacheProjector=n.projector;n.cacheSoft=n.soft;}}
  n.first=false;n.indexed=true;
  if(this.candidate&&this.clustered&&n.kind!=='geometry'){
   const include=this.shouldIndex(n);
   if(include&&!n.pairIndexed){n.pairIndexed=true;this.stats.indexInsert++;}
   else if(include)this.stats.indexUpdate++;
   else if(n.pairIndexed){n.pairIndexed=false;this.stats.indexRemove++;}
  }
  const found=[];
  for(const other of this.nodes){
   if(other===n||!other.indexed||!other.visible||other.scenario!==n.scenario||!this.meaningful(n,other))continue;
   if(n.kind==='geometry'&&other.kind!=='geometry'){
    this.stats.primaryVisits++;
    if(this.candidate&&this.clustered&&!other.pairIndexed)continue;
    this.stats.pairVisits++;
   }
   const geometry=n.kind==='geometry'?n:other.kind==='geometry'?other:null;
   const light=n.kind==='light'?n:other.kind==='light'?other:null;
   if(!this.intersect(n,other)||!this.filter(n,other)||(geometry&&light&&!(geometry.layer&light.mask)))continue;
   found.push(this.key(n,other));
  }
  for(const key of [...this.pairs])if((key.startsWith(n.id+':')||key.endsWith(':'+n.id))&&!found.includes(key))this.pairs.delete(key);
  for(const key of found)this.pairs.add(key);
  this.stats.peakLeaves=Math.max(this.stats.peakLeaves,this.nodes.filter(v=>v.pairIndexed).length);
 }
 drain(){while(this.queue.length)this.repair(this.nodes[this.queue.shift()]);}
 mutate(op,id,value){const n=this.nodes[id];
  if(op==='move'){n.x=value[0];n.y=value[1];n.z=value[2];this.enqueue(n);}
  else if(op==='visible'){if(n.visible!==value){if(!value)this.unpair(n);n.visible=value;if(value)this.enqueue(n);}}
  else if(op==='scenario'){if(n.scenario!==value){this.unpair(n);n.scenario=value;this.enqueue(n);}}
  else if(op==='base'){this.unpair(n);n.first=true;this.enqueue(n);}
  else if(op==='shadow'||op==='projector'||op==='soft'){n[op]=value;this.enqueue(n);}
  else if(op==='layer'||op==='mask'){n[op]=value;this.unpair(n);this.enqueue(n);}
  else throw Error(op);
 }
 observe(){const pairs=[...this.pairs].sort();const camera=[...this.nodes].filter(n=>n.indexed&&n.visible&&n.kind!=='geometry').map(n=>n.id).sort((a,b)=>a-b);const effects=this.nodes.filter(n=>n.kind==='geometry').map(g=>({id:g.id,lights:pairs.filter(key=>key.startsWith(g.id+':')||key.endsWith(':'+g.id)).map(key=>this.nodes[Number(key.split(':').find(id=>Number(id)!==g.id))]).filter(n=>n.kind==='light').length,projectors:pairs.filter(key=>key.startsWith(g.id+':')||key.endsWith(':'+g.id)).map(key=>this.nodes[Number(key.split(':').find(id=>Number(id)!==g.id))]).filter(n=>n.kind==='light'&&n.cacheProjector).length,soft:pairs.filter(key=>key.startsWith(g.id+':')||key.endsWith(':'+g.id)).map(key=>this.nodes[Number(key.split(':').find(id=>Number(id)!==g.id))]).filter(n=>n.kind==='light'&&n.cacheSoft).length}));return{pairs,camera,effects};}
}
let checks=0;
function compare(a,b,label){assert.deepEqual(b.observe(),a.observe(),label);checks++;}
const cases=[];
for(const clustered of [true,false]){
 const a=new World(false,clustered),b=new World(true,clustered);
 for(const world of [a,b]){for(const node of world.nodes)world.enqueue(node);world.drain();}
 compare(a,b,'initial clustered='+clustered);
 for(let frame=0;frame<360;frame++){
  const ops=5+rand()%14;
  for(let j=0;j<ops;j++){
   const id=rand()%size,kind=rand()%8;
   const op=kind===0?'move':kind===1?'visible':kind===2?'scenario':kind===3?'base':kind===4?'layer':kind===5?'mask':kind===6?'shadow':'projector';
   const value=op==='move'?[rand()%240,rand()%240,rand()%40]:op==='scenario'?rand()%3:op==='layer'?1<<(rand()%4):op==='mask'?rand()%16:op==='base'?null:!!(rand()%2);
   for(const world of [a,b])world.mutate(op,id,value);
  }
  if(frame%7===0){const id=64+rand()%80,value=!!(rand()%2);for(const world of [a,b])world.mutate('soft',id,value);}
  for(const world of [a,b])world.drain();compare(a,b,'frame '+frame+' clustered='+clustered);
 }
 cases.push({clustered,control:a.stats,candidate:b.stats,finalRelations:a.pairs.size,finalCameraVolumes:a.observe().camera.length});
}
const result={issue:'NWN-74',private:true,scope:'Source-bound mutation/ownership model. Equality covers pair records, consumed geometry light/projector/soft counts and full camera-volume membership after inserts, removals, transforms, layer/mask/consumer changes, scenario changes and 360 frames per renderer gate. It does not prove compiled-engine callback order, pixels, timing or memory.',checks,cases,source:{cppSha256:sha(Buffer.from(cpp)),headerSha256:sha(Buffer.from(header))},seed:seedInitial};
const file=path.join(root,'.cache/nwn74/pair-index-a/oracle.json');fs.writeFileSync(file,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file,sha256:sha(fs.readFileSync(file)),checks,cases:cases.map(row=>({clustered:row.clustered,relations:row.finalRelations,controlVisits:row.control.primaryVisits,candidateVisits:row.candidate.pairVisits,peakPairLeaves:row.candidate.peakLeaves}))}));
