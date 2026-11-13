'use strict';
// Differential intrusive-list algorithm oracle. Source-bound model only;
// compile/GPU acceptance uses the real engine separately.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),{transform,MARKER}=require('./pair-reuse.cjs');
class Link{constructor(pair){this.pair=pair;this.root=null;this.next=null;this.prev=null;}remove(){if(this.root)this.root.remove(this);}}
class List{constructor(){this.first=null;this.last=null;}add(link){assert(!link.root);link.root=this;link.prev=null;link.next=this.first;if(this.first)this.first.prev=link;else this.last=link;this.first=link;}remove(link){assert.equal(link.root,this);if(link.next)link.next.prev=link.prev;if(link.prev)link.prev.next=link.next;if(this.first===link)this.first=link.next;if(this.last===link)this.last=link.prev;link.root=null;link.next=null;link.prev=null;}*links(){for(let e=this.first;e;e=e.next)yield e;}}
class Pair{constructor(a,b){this.a=a;this.b=b;this.la=new Link(this);this.lb=new Link(this);this.live=true;}}
class World{
 constructor(reuse){this.reuse=reuse;this.wrapped=false;this.pass=1n;this.nodes=Array.from({length:10},(_,id)=>({id,type:id<6?0:1,pairs:new List(),check:0n,sp:0n,ptr:null,visible:true,box:[id%4,id%4+2],mask:1}));this.events=[];this.alloc=0;this.free=0;this.reused=0;this.fallback=0;}
 other(pair,node){return pair.a===node?pair.b:pair.a;}
 allocate(a,b){this.alloc++;return new Pair(a,b);}
 destroy(pair){assert(pair.live);pair.lb.remove();pair.la.remove();pair.live=false;this.free++;}
 event(kind,a,b){this.events.push([kind,a.id,b.id]);}
 direct(a,b){const p=this.allocate(this.nodes[a],this.nodes[b]);p.a.pairs.add(p.la);p.b.pairs.add(p.lb);}
 unpair(id){const n=this.nodes[id];while(n.pairs.first){const p=n.pairs.first.pair;this.event('unpair',n,this.other(p,n));this.destroy(p);}}
 overlap(a,b){return a.box[0]<b.box[1]&&b.box[0]<a.box[1];}
 repair(id,queries){this.pass=BigInt.asUintN(64,this.pass+1n);if(this.pass===0n)this.wrapped=true;const stamp=this.pass,n=this.nodes[id],found=new List();let reuse=this.reuse&&!this.wrapped;
  if(reuse){for(const e of n.pairs.links()){const o=this.other(e.pair,n);if(o.sp!==0n||o.ptr!==null){reuse=false;this.fallback++;break;}}}
  if(reuse){for(const e of n.pairs.links()){const p=e.pair,o=this.other(p,n);if(o.sp!==0n||o.ptr!==null){reuse=false;this.fallback++;break;}o.sp=stamp;o.ptr=p;}
   if(!reuse){for(const e of n.pairs.links()){const p=e.pair,o=this.other(p,n);if(o.sp===stamp&&o.ptr===p){o.sp=0n;o.ptr=null;}}}}
  for(const q of queries){const o=this.nodes[q];if(o===n||!o.visible||o.type===n.type||!this.overlap(n,o))continue;let p=null;
   if(reuse&&o.sp===stamp){o.check=0n;p=o.ptr;if(p){o.ptr=null;p.la.remove();p.lb.remove();this.reused++;}}
   else o.check=stamp;
   if(!p)p=this.allocate(n,o);p.a=n;p.b=o;found.add(p.la);
  }
  while(n.pairs.first){const p=n.pairs.first.pair,o=this.other(p,n);if(reuse&&o.sp===stamp&&o.ptr===p){o.sp=0n;o.ptr=null;}
   if(o.check!==stamp)this.event('unpair',n,o);else o.check=0n;this.destroy(p);}
  while(found.first){const p=found.first.pair;found.remove(found.first);if(reuse&&p.b.sp===stamp){assert.equal(p.b.ptr,null);p.b.sp=0n;}if(p.b.check===stamp)this.event('pair',n,p.b);p.a.pairs.add(p.la);p.b.pairs.add(p.lb);}
 }
 snapshot(){return this.nodes.map(n=>({id:n.id,check:String(n.check),pairs:[...n.pairs.links()].map(e=>{assert(e.pair.live);const p=e.pair;assert(e.root===n.pairs);assert(p.a===n||p.b===n);assert.equal(p.la.root,p.a.pairs);assert.equal(p.lb.root,p.b.pairs);return[p.a.id,p.b.id];})}));}
 noScratch(){for(const n of this.nodes){assert.equal(n.sp,0n);assert.equal(n.ptr,null);}}
}
let state=0x6cf31e2d;const random=()=>{state^=state<<13;state^=state>>>17;state^=state<<5;return state>>>0;},shuffle=xs=>{const v=[...xs];for(let i=v.length-1;i>0;i--){const j=random()%(i+1);[v[i],v[j]]=[v[j],v[i]];}return v;};
const cases=[];let compared=0,allocControl=0,allocCandidate=0,freedControl=0,freedCandidate=0,reused=0,fallbacks=0;
function equal(a,b,label){assert.deepEqual(b.events,a.events,label+' callbacks');assert.deepEqual(b.snapshot(),a.snapshot(),label+' orientations/list order/stamps');b.noScratch();a.events=[];b.events=[];compared++;}
for(let trial=0;trial<100;trial++){const a=new World(false),b=new World(true);for(let step=0;step<150;step++){const id=random()%10,operation=random()%12;if(operation===0||operation===1){a.unpair(id);b.unpair(id);const visible=operation===0?!a.nodes[id].visible:true;a.nodes[id].visible=visible;b.nodes[id].visible=visible;}
  else if(operation===2){a.unpair(id);b.unpair(id);a.nodes[id].mask^=1;b.nodes[id].mask^=1;}
  else{const min=(random()%100)/20,max=min+.1+(random()%50)/20;a.nodes[id].box=[min,max];b.nodes[id].box=[min,max];}
  let query=shuffle(a.nodes.map(n=>n.id));if(random()%25===0)query.splice(random()%query.length,0,query[random()%query.length]);
  if(a.nodes[id].visible){a.repair(id,query);b.repair(id,query);}equal(a,b,'random '+trial+'/'+step);
 }allocControl+=a.alloc;allocCandidate+=b.alloc;freedControl+=a.free;freedCandidate+=b.free;reused+=b.reused;fallbacks+=b.fallback;}
function run(name,setup,query=[6,7,8,9]){const a=new World(false),b=new World(true);setup(a,b);a.repair(0,query);b.repair(0,query);equal(a,b,name);cases.push({name,pass:true,candidateFallback:b.fallback,recordReused:b.reused});}
run('opposite orientation and kept/removed callback order',(a,b)=>{for(const w of[a,b]){w.direct(6,0);w.direct(0,7);w.direct(8,0);w.nodes[0].box=[0,2];w.nodes[6].box=[0,1];w.nodes[7].box=[9,10];w.nodes[8].box=[1,3];w.nodes[9].box=[.5,1.5];}},[8,6,9,7]);
run('duplicate new BVH hit preserves callback and list multiplicity',(a,b)=>{for(const w of[a,b]){w.nodes[0].box=[0,2];w.nodes[6].box=[0,1];}},[6,6]);
run('duplicate kept BVH hit preserves callback suppression',(a,b)=>{for(const w of[a,b]){w.direct(6,0);w.nodes[0].box=[0,2];w.nodes[6].box=[0,1];}},[6,6]);
run('duplicate old relation fails closed to original behavior',(a,b)=>{for(const w of[a,b]){w.direct(0,6);w.direct(6,0);w.nodes[0].box=[0,2];w.nodes[6].box=[0,1];}},[6]);
for(const samePass of[false,true]){const a=new World(false),b=new World(true);for(const w of[a,b]){w.direct(0,6);w.direct(0,7);w.nodes[0].box=[0,2];w.nodes[6].box=[0,1];w.nodes[7].box=[1,2];}const ext={foreign:true};b.nodes[6].sp=samePass?2n:987n;b.nodes[6].ptr=ext;a.repair(0,[6,7]);b.repair(0,[6,7]);assert.equal(b.nodes[6].sp,samePass?2n:987n);assert.equal(b.nodes[6].ptr,ext);assert.equal(b.fallback,1);b.nodes[6].sp=0n;b.nodes[6].ptr=null;equal(a,b,'foreign marker '+samePass);cases.push({name:'foreign '+(samePass?'same':'other')+' pass scratch unchanged',pass:true});}
{const a=new World(false),b=new World(true);for(const w of[a,b]){w.direct(0,6);w.nodes[0].box=[0,2];w.nodes[6].box=[0,1];w.pass=(1n<<64n)-2n;}for(let i=0;i<5;i++){a.repair(0,[6,7,8]);b.repair(0,[6,7,8]);equal(a,b,'wrap '+i);}assert(b.wrapped);cases.push({name:'unsigned wrap disables reuse for remainder of run',pass:true});}
// Source binding: actual callback functions are engine-owned and only enqueue
// dirty work. A queued lightmap capture is not an immediate recursive pair pass.
const project=path.resolve(__dirname,'../../../..'),base=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),headerFile=path.join(base,'servers/rendering/renderer_scene_cull.h'),sourceFile=path.join(base,'servers/rendering/renderer_scene_cull.cpp'),header=fs.readFileSync(headerFile,'utf8'),source=fs.readFileSync(sourceFile,'utf8'),patched=transform(header,source),sha=s=>crypto.createHash('sha256').update(s).digest('hex');
const originalQueries=header.slice(header.indexOf('\tstruct PairInstances {'),header.indexOf('\n\tmutable HashSet<Instance *> heightfield_particle_colliders_update_list;')).match(/bvh2?->aabb_query\(instance->transformed_aabb, \*this\)/g),newQueries=patched.header.slice(patched.header.indexOf('\tstruct PairInstances {'),patched.header.indexOf('\n\tmutable HashSet<Instance *> heightfield_particle_colliders_update_list;')).match(/bvh2?->aabb_query\(instance->transformed_aabb, \*this\)/g);assert.deepEqual(newQueries,originalQueries);
const callbacks=source.slice(source.indexOf('void RendererSceneCull::_instance_pair('),source.indexOf('RID RendererSceneCull::scenario_allocate('));assert(!/\bupdate_dirty_instances\(|\b_update_dirty_instance\(|\b_update_instance\(/.test(callbacks));
assert(patched.header.includes('instance->transformed_aabb.intersects(p_instance->transformed_aabb) && (pair_mask & (1 << p_instance->base_type))'));
assert(allocCandidate<allocControl);assert(reused>0);
const result={version:1,marker:MARKER,scope:'Differential source-bound JavaScript intrusive-list algorithm model, not compiled engine execution or a GPU/performance result.',randomSeed:'0x6cf31e2d',randomTrials:100,stepsPerTrial:150,comparedTransitions:compared,adversarialCases:cases,records:{controlAllocated:allocControl,candidateAllocated:allocCandidate,controlFreed:freedControl,candidateFreed:freedCandidate,candidateReused:reused,candidateFallbacks:fallbacks},source:{headerFile,sourceFile,headerSha256:sha(header),sourceSha256:sha(source),patchedHeaderSha256:sha(patched.header),patchedSourceSha256:sha(patched.source),callbackBodiesSha256:sha(callbacks),sameQueryExpressions:originalQueries},limitations:['Actual source callbacks have no direct dirty drain; backend virtual callees still require full source review and actual engine validation.','The oracle compares callback input order, final both-side list order, pair orientation, stamps and scratch lifetime. It intentionally does not require identical allocator addresses.','Synthetic duplicate queries and old duplicate relations preserve baseline behavior, including baseline oddities; this prototype does not repair malformed graph semantics.']};
const output=path.join(project,'.cache/native-render-gap/original/bounds-repair/reuse-oracle-a.json');if(fs.existsSync(output))throw Error('Keep prior oracle result');fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,compared,cases:cases.length,records:result.records,sha256:sha(fs.readFileSync(output))}));
