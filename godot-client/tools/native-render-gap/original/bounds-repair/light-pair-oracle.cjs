'use strict';
// Mutation/callback-state model, source-bound to the private transformer.
// This deliberately does not claim compiled-engine or GPU acceptance.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {transform,MARKER}=require('./light-pair-filter.cjs'),reuse=require('./pair-reuse.cjs'),bone=require('./pair-guard.cjs');
const project=path.resolve(__dirname,'../../../..'),base=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const header=fs.readFileSync(path.join(base,'servers/rendering/renderer_scene_cull.h'),'utf8'),source=fs.readFileSync(path.join(base,'servers/rendering/renderer_scene_cull.cpp'),'utf8'),patched=transform(header,source);
class World{
 constructor(filter,layerFix){this.filter=filter;this.layerFix=layerFix;this.nodes=Array.from({length:18},(_,id)=>({id,type:id<10?'g':id<16?'l':id===16?'v':'m',visible:true,indexed:false,lo:0,hi:4,layer:1,mask:1,shadow:false,projector:false,soft:false,cs:false,cp:false,cf:false,cast:true,dirty:0,geomLights:new Set(),projectors:0,softs:0,gi:new Set(),captures:new Set()}));this.records=new Set();this.queue=[];this.excluded=0;}
 key(a,b){return[a.id,b.id].sort((x,y)=>x-y).join(',');}
 split(key){return key.split(',').map(x=>this.nodes[+x]);}
 gl(a,b){return a.type==='g'&&b.type==='l'?[a,b]:b.type==='g'&&a.type==='l'?[b,a]:null;}
 callback(add,a,b){const gl=this.gl(a,b);if(gl){const[g,l]=gl;if(!(g.layer&l.mask))return;if(add)g.geomLights.add(l.id);else g.geomLights.delete(l.id);if(g.cast)l.dirty=2;if(l.cp)g.projectors+=add?1:-1;if(l.cf)g.softs+=add?1:-1;}
  else{const g=a.type==='g'?a:b.type==='g'?b:null,o=g==a?b:a;if(g&&o.type==='v'){if(add)g.gi.add(o.id);else g.gi.delete(o.id);}if(g&&o.type==='m'){if(add)g.captures.add(o.id);else g.captures.delete(o.id);}}}
 enqueue(n){if(!this.queue.includes(n))this.queue.push(n);}
 unpair(n){for(const key of[...this.records]){const[a,b]=this.split(key);if(a===n||b===n){this.callback(false,n,a===n?b:a);this.records.delete(key);}}n.indexed=false;}
 meaningful(a,b){return !!this.gl(a,b)||(a.type==='g'&&['v','m'].includes(b.type))||(b.type==='g'&&['v','m'].includes(a.type))||(a.type==='l'&&b.type==='v')||(a.type==='v'&&b.type==='l');}
 keep(a,b){const gl=this.gl(a,b);if(!gl||!this.filter)return true;const l=gl[1];return l.cs||l.cp||l.cf;}
 repair(n){if(!n.visible)return;if(n.type==='l'){n.cs=n.shadow;n.dirty=2;if(!n.indexed){n.cp=n.projector;n.cf=n.soft;}}
  if(n.type==='g'&&n.cast)for(const id of n.geomLights)this.nodes[id].dirty=2;
  n.indexed=true;const found=[];for(const o of this.nodes){if(o===n||!o.indexed||!o.visible||!(n.lo<o.hi&&o.lo<n.hi)||!this.meaningful(n,o))continue;if(!this.keep(n,o)){this.excluded++;continue;}found.push(o);}
  const next=new Set(found.map(o=>this.key(n,o)));for(const key of[...this.records]){const[a,b]=this.split(key);if((a===n||b===n)&&!next.has(key)){this.callback(false,n,a===n?b:a);this.records.delete(key);}}
  for(const o of found){const key=this.key(n,o);if(!this.records.has(key)){this.callback(true,n,o);this.records.add(key);}}
 }
 drain(){while(this.queue.length)this.repair(this.queue.shift());}
 mutate(op,id,value){const n=this.nodes[id];if(op==='move'){n.lo=value;n.hi=value+4;this.enqueue(n);}else if(op==='visible'){if(n.visible!==value){if(!value)this.unpair(n);n.visible=value;if(value)this.enqueue(n);}}
  else if(op==='layer'){if(n.layer!==value){if(this.layerFix&&n.type==='g'){this.unpair(n);this.enqueue(n);}n.layer=value;if(n.cast)for(const lid of n.geomLights)this.nodes[lid].dirty=2;}}
  else if(op==='mask'){if(n.mask!==value){this.unpair(n);n.mask=value;this.enqueue(n);}}
  else if(op==='shadow'){n.shadow=value;this.enqueue(n);}
  else if(op==='projector'||op==='soft'){if(n[op]!==value){this.unpair(n);n[op]=value;this.enqueue(n);}}
  else if(op==='cast'){if(n.cast!==value){for(const lid of n.geomLights)this.nodes[lid].dirty=2;n.cast=value;this.enqueue(n);}}
  else if(op==='base'){this.unpair(n);this.enqueue(n);}
  else if(op==='draw'){for(const l of this.nodes.filter(x=>x.type==='l'&&x.shadow))l.dirty=Math.max(0,l.dirty-1);}
 }
 observe(){return this.nodes.map(n=>({id:n.id,projectors:n.projectors,softs:n.softs,gi:[...n.gi].sort(),captures:[...n.captures].sort(),shadowDirty:n.type==='l'&&n.shadow?n.dirty:null,clusterLight:n.type==='l'&&n.visible}));}
 requiredRecords(){return[...this.records].filter(key=>{const[a,b]=this.split(key),gl=this.gl(a,b);if(!gl)return true;const l=gl[1];return l.cs||l.cp||l.cf;}).sort();}
}
let seed=0xd1b54a32;function rand(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return seed>>>0;}
let comparisons=0,excluded=0;const cases=[];
function compare(a,b,label){assert.deepEqual(b.observe(),a.observe(),label+' consumed callback state');assert.deepEqual(b.requiredRecords(),a.requiredRecords(),label+' all required and GI/lightmap relations');comparisons++;}
for(let trial=0;trial<80;trial++){const a=new World(false,true),b=new World(true,true);for(const w of[a,b]){for(const n of w.nodes)w.enqueue(n);w.drain();}compare(a,b,'init');for(let step=0;step<120;step++){const which=rand()%12;let op,id,value;
 if(which<3){op='move';id=rand()%18;value=(rand()%100)/10;}
 else if(which===3){op='layer';id=rand()%10;value=rand()%4;}
 else if(which===4){op='mask';id=10+rand()%6;value=rand()%4;}
 else if(which===5){op='shadow';id=10+rand()%6;value=!!(rand()%2);}
 else if(which===6){op='projector';id=10+rand()%6;value=!!(rand()%2);}
 else if(which===7){op='soft';id=10+rand()%6;value=!!(rand()%2);}
 else if(which===8){op='cast';id=rand()%10;value=!!(rand()%2);}
 else if(which===9){op='visible';id=rand()%18;value=!!(rand()%2);}
 else if(which===10){op='base';id=rand()%18;value=0;}
 else{op='draw';id=0;value=0;}
 a.mutate(op,id,value);b.mutate(op,id,value);a.drain();b.drain();compare(a,b,'trial '+trial+' step '+step+' '+op);}
 excluded+=b.excluded;}
// The old Clustered layer setter misses an actual consumed relationship.
{const old=new World(false,false),fixed=new World(false,true),candidate=new World(true,true);for(const w of[old,fixed,candidate]){for(const n of w.nodes)n.visible=false;const g=w.nodes[0],l=w.nodes[10];g.visible=l.visible=true;l.mask=2;l.projector=true;l.shadow=true;w.enqueue(g);w.enqueue(l);w.drain();assert.equal(g.projectors,0);w.mutate('layer',0,2);w.drain();}
 assert.equal(old.nodes[0].projectors,0);assert.equal(fixed.nodes[0].projectors,1);assert.equal(candidate.nodes[0].projectors,1);compare(fixed,candidate,'old layer bug correctness control');cases.push({name:'Layer1→2 with cullmask2 and unchanged shadow/projector light',oldProjectors:0,fixedProjectors:1,filteredProjectors:1,scope:'Consumed specialization/callback state model, not pixels.'});}
// Legacy nonconsumer records preserve obsolete masked membership; both fixed
// worlds must discard that history before adding a shadow consumer.
{const a=new World(false,true),b=new World(true,true);for(const w of[a,b]){for(const n of w.nodes)n.visible=false;const g=w.nodes[0],l=w.nodes[10];g.visible=l.visible=true;w.enqueue(g);w.enqueue(l);w.drain();w.mutate('layer',0,2);w.drain();w.mutate('shadow',10,true);w.drain();w.mutate('move',0,.1);w.drain();}compare(a,b,'masked layer followed by shadow enable');cases.push({name:'Layer mismatch then nonshadow→shadow and geometry motion',pass:true});}
// Read-only composition guards: all three private transformations can be
// applied without losing baseline queries or either opt-in's state.
const combinations=[];for(const order of[[transform,reuse.transform,bone.transform],[reuse.transform,bone.transform,transform],[bone.transform,transform,reuse.transform]]){let x={header,source};for(const t of order)x=t(x.header,x.source);for(const marker of[MARKER,reuse.MARKER,bone.MARKER])assert(x.header.includes(marker)||x.source.includes(marker));assert.equal((x.header.match(/bvh->aabb_query\(instance->transformed_aabb, \*this\)/g)||[]).length,1);assert.equal((x.header.match(/bvh2->aabb_query\(instance->transformed_aabb, \*this\)/g)||[]).length,1);combinations.push({headerSha256:sha(x.header),sourceSha256:sha(x.source)});}
assert(patched.source.includes('light_pair_filter_consumers && light_pair_layer_repair_exact && geometry_instance_pair_mask == (1u << RSE::INSTANCE_VOXEL_GI)'));
const layerStart=patched.source.indexOf('void RendererSceneCull::instance_set_layer_mask('),layerEnd=patched.source.indexOf('void RendererSceneCull::instance_set_pivot_data(',layerStart),layer=patched.source.slice(layerStart,layerEnd);assert(layer.indexOf('_unpair_instance(instance);')<layer.indexOf('instance->layer_mask = p_mask;'));assert(layer.includes('|| clustered_layer_pair_repair'));
assert(patched.header.includes('instance->base_type == RSE::INSTANCE_LIGHT && ((1 << p_instance->base_type) & RSE::INSTANCE_GEOMETRY_MASK)'));
assert(patched.header.includes('p_instance->base_type == RSE::INSTANCE_LIGHT && ((1 << instance->base_type) & RSE::INSTANCE_GEOMETRY_MASK)'));
const result={version:1,scope:'Source-bound mutation and consumed callback-state model; not compiled engine, image, native instruction or FPS acceptance.',seed:'0xd1b54a32',trials:80,stepsPerTrial:120,comparisons,excludedCandidateVisits:excluded,cases,compositions:combinations,source:{headerSha256:sha(header),sourceSha256:sha(source),patchedHeaderSha256:sha(patched.header),patchedSourceSha256:sha(patched.source)},limitations:['Random bounds and synthetic query providers exercise ownership/mutation policy only.','Old→fixed layer behavior intentionally changes stale membership and requires a separate positive GPU correctness witness.','Both fixed-control and fixed+filter require --light-pair-layer-repair=exact; filter without this argument fails closed.','Same compiled-engine GPU fixture and actual target performance measurements remain required.']};
const label=process.argv[2]??'a';assert(/^[a-z0-9-]+$/.test(label));const output=path.join(project,'.cache/native-render-gap/original/bounds-repair/light-pair-oracle-'+label+'.json');assert(!fs.existsSync(output),'Keep prior oracle');fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,comparisons,excluded,sha256:sha(fs.readFileSync(output))}));
