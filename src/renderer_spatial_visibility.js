// Experimental conservative main-pass broad phase. The native path uses BSP
// traversal with reduced plane lists (140229dc0, caller 1400dba72), then AABB
// tests (PartOutside1400dbf30 -> BoxAbovePlane14022b350 at1400dbf8c).
// This is an independently built bounds hierarchy, NOT the original BSP layout
// or tile fade/LOD policy. Three keeps final frustum tests, sorting and drawing.
// Plane contact survives; uncertain geometry always keeps the ordinary path.
import {Box3,Material} from 'three';
import {isLocalRendererHook} from './renderer_local_hooks.js';

const allPlanes=63;
const supported=o=>o.isMesh&&!o.isSkinnedMesh&&!o.isInstancedMesh&&!o.isBatchedMesh&&
 !o.geometry?.isInstancedBufferGeometry&&!o.geometry?.morphAttributes?.position?.length&&
 !o.geometry?.morphAttributes?.normal?.length&&!o.boundingSphere&&
 (Array.isArray(o.material)?o.material:[o.material]).every(m=>m&&
  (m.isMeshLambertMaterial||m.isMeshBasicMaterial)&&!m.displacementMap&&
  (m.onBeforeCompile===Material.prototype.onBeforeCompile||isLocalRendererHook(m.onBeforeCompile)));

// Three planes point inward. Reject only when the most positive corner is
// strictly outside. Roundoff padding deliberately admits uncertain boundaries.
export function classifySpatialBounds(bounds,planes,mask=allPlanes,stats=null){
 let remaining=mask;
 for(let i=0;i<planes.length;i++){
  const bit=1<<i;if(!(mask&bit))continue;
  const p=planes[i],n=p.normal,x=n.x,y=n.y,z=n.z;
  const hi=x*(x>=0?bounds[3]:bounds[0])+y*(y>=0?bounds[4]:bounds[1])+z*(z>=0?bounds[5]:bounds[2])+p.constant;
  const lo=x*(x>=0?bounds[0]:bounds[3])+y*(y>=0?bounds[1]:bounds[4])+z*(z>=0?bounds[2]:bounds[5])+p.constant;
  if(stats)stats.planeTests++;
  const epsilon=1e-7*(1+Math.abs(p.constant)+Math.abs(x)*Math.max(Math.abs(bounds[0]),Math.abs(bounds[3]))+
   Math.abs(y)*Math.max(Math.abs(bounds[1]),Math.abs(bounds[4]))+Math.abs(z)*Math.max(Math.abs(bounds[2]),Math.abs(bounds[5])));
  if(hi < -epsilon)return -1;
  if(lo>=epsilon)remaining&=~bit;
 }
 return remaining;
}
function include(target,b){for(let i=0;i<3;i++){target[i]=Math.min(target[i],b[i]);target[i+3]=Math.max(target[i+3],b[i+3]);}}
const empty=()=>new Float64Array([Infinity,Infinity,Infinity,-Infinity,-Infinity,-Infinity]);
function refit(node){
 if(!node.dirty)return;
 const b=node.bounds;b.set([Infinity,Infinity,Infinity,-Infinity,-Infinity,-Infinity]);
 if(node.rows)for(const r of node.rows)include(b,r.bounds);
 else {refit(node.left);refit(node.right);include(b,node.left.bounds);include(b,node.right.bounds);}
 node.dirty=false;
}
function build(rows,parent=null){
 const node={bounds:empty(),parent,dirty:true};
 for(const r of rows)include(node.bounds,r.bounds);
 if(rows.length<=8){node.rows=rows;for(const r of rows)r.leaf=node;}
 else {
  let axis=0;for(let i=1;i<3;i++)if(node.bounds[i+3]-node.bounds[i]>node.bounds[axis+3]-node.bounds[axis])axis=i;
  rows.sort((a,b)=>(a.bounds[axis]+a.bounds[axis+3])-(b.bounds[axis]+b.bounds[axis+3]));
  const middle=rows.length>>>1;node.left=build(rows.slice(0,middle),node);node.right=build(rows.slice(middle),node);
 }
 node.dirty=false;return node;
}
export class RendererSpatialVisibility{
 constructor(){this.records=new Map();this.members=[];this.rows=[];this.box=new Box3();this.epoch=0;this.stats={};}
 reset(){this.records.clear();this.members=[];this.rows=[];this.root=null;this.stats={};}
 updateBounds(row){
  const o=row.object,g=o.geometry,a=g?.attributes?.position,m=o.matrixWorld?.elements;
  if(!supported(o)||o.frustumCulled===false||!a||a.isInterleavedBufferAttribute||!a.count||!m)return false;
  for(let i=0;i<16;i++)if(!Number.isFinite(m[i]))return false;
  const verticesChanged=row.geometry!==g||row.attribute!==a||row.array!==a.array||row.version!==a.version||row.count!==a.count;
  let changed=verticesChanged;
  for(let i=0;i<16&&!changed;i++)if(row.matrix[i]!==m[i])changed=true;
  if(!changed){this.stats.reusedBounds++;return true;}
  // Read the actual vertex channel, not a potentially stale authored bbox.
  if(verticesChanged){row.local??=new Box3();row.local.setFromBufferAttribute(a);}
  this.box.copy(row.local).applyMatrix4(o.matrixWorld);
  const {min,max}=this.box,b=row.bounds;
  if(![min.x,min.y,min.z,max.x,max.y,max.z].every(Number.isFinite))return false;
  b.set([min.x,min.y,min.z,max.x,max.y,max.z]);row.matrix.set(m);
  row.geometry=g;row.attribute=a;row.array=a.array;row.version=a.version;row.count=a.count;
  this.stats.updatedBounds++;
  for(let node=row.leaf;node&&!node.dirty;node=node.parent)node.dirty=true;
  return true;
 }
 prepare(members,frustum){
  this.epoch++;this.stats={members:members.length,indexed:0,fallback:0,updatedBounds:0,reusedBounds:0,planeTests:0,nodes:0,rejectedNodes:0,candidates:0,rebuilds:0};
  let rebuild=members.length!==this.members.length;
  for(let i=0;i<members.length&&!rebuild;i++)if(members[i]!==this.members[i])rebuild=true;
  if(rebuild){
   const retained=new Map();this.rows=[];
   for(const object of members){let row=this.records.get(object);if(!row)row={object,bounds:empty(),matrix:new Float64Array(16),selected:0,indexed:false};row.leaf=null;retained.set(object,row);this.rows.push(row);}
   this.records=retained;this.members=members.slice();
  }
  for(const row of this.rows){
   const indexed=this.updateBounds(row);
   if(indexed!==row.indexed){rebuild=true;row.indexed=indexed;}
   if(indexed)this.stats.indexed++;else {row.selected=this.epoch;this.stats.fallback++;}
  }
  if(rebuild){const indexed=this.rows.filter(r=>r.indexed);this.root=indexed.length?build(indexed):null;this.stats.rebuilds++;}
  else if(this.root)refit(this.root);
  if(this.root)this.query(this.root,frustum.planes,(1<<frustum.planes.length)-1);
  return this;
 }
 query(node,planes,mask){
  this.stats.nodes++;
  const remaining=mask?classifySpatialBounds(node.bounds,planes,mask,this.stats):0;
  if(remaining===-1){this.stats.rejectedNodes++;return;}
  if(node.rows){for(const row of node.rows)if(!remaining||classifySpatialBounds(row.bounds,planes,remaining,this.stats)!==-1){row.selected=this.epoch;this.stats.candidates++;}}
  else {this.query(node.left,planes,remaining);this.query(node.right,planes,remaining);}
 }
 accepts(object){return this.records.get(object)?.selected===this.epoch;}
 snapshot(){return{...this.stats};}
}
