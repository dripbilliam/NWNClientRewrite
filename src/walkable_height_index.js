import {findWalkableHeight} from './walkmesh.js';

// Static area ground only. This narrows candidate membership; the original
// barycentric calculation, tolerance, reference-height choice and tie order
// remain in findWalkableHeight. Mutable door/object obstacles are not indexed.
export class WalkableHeightIndex{
 constructor(triangles,{cellSize=10,maxReferences=1_000_000}={}){
  if(!(cellSize>0)||!Number.isFinite(cellSize)||!Number.isInteger(maxReferences)||maxReferences<1)throw Error('Invalid height index bounds');
  this.source=triangles;this.sourceCount=triangles.length;this.cellSize=cellSize;this.cells=new Map();this.overflow=[];this.references=0;this.closed=false;this.queries=0;this.candidates=0;this.fullScans=0;this.coordinateLimit=1;this.fallback=false;
  for(let index=0;index<triangles.length;index++){
   const vertices=triangles[index].vertices,[a,b,c]=vertices,x=vertices.map(v=>v[0]),z=vertices.map(v=>v[2]),minX=Math.min(...x),maxX=Math.max(...x),minZ=Math.min(...z),maxZ=Math.max(...z),extent=Math.max(maxX-minX,maxZ-minZ),magnitude=Math.max(...x.map(Math.abs),...z.map(Math.abs));
   const u=(b[2]-c[2])*(a[0]-c[0]),v=(c[0]-b[0])*(a[2]-c[2]),denominator=u+v;
   if(Number.isFinite(magnitude))this.coordinateLimit=Math.max(this.coordinateLimit,magnitude*2+1);
   if(Math.abs(denominator)<1e-8)continue; // Always skipped by the exact query.
   // Ill-conditioned/extreme coordinates take the ordinary calculation in
   // every cell. Avoid asserting geometric bounds on unstable floating math.
   if(!Number.isFinite(denominator)||!Number.isFinite(magnitude)||magnitude>1e8||Math.abs(denominator)<Math.max(Math.abs(u),Math.abs(v),extent*extent)*1e-8){this.overflow.push(index);continue;}
   // If each barycentric weight >= -e and their sum is1, each coordinate is
   // inside [min-3e*extent,max+3e*extent]. Add numerical roundoff margin too.
   const margin=3e-5*extent+64*Number.EPSILON*Math.max(1,magnitude),left=Math.floor((minX-margin)/cellSize),right=Math.floor((maxX+margin)/cellSize),bottom=Math.floor((minZ-margin)/cellSize),top=Math.floor((maxZ+margin)/cellSize),count=(right-left+1)*(top-bottom+1);
   if(!Number.isSafeInteger(count)||count>4096){this.overflow.push(index);continue;}
   if(this.references+count>maxReferences){this.fallback=true;break;}
   for(let cx=left;cx<=right;cx++){let column=this.cells.get(cx);if(!column){column=new Map();this.cells.set(cx,column);}for(let cz=bottom;cz<=top;cz++){let cell=column.get(cz);if(!cell){cell=[];column.set(cz,cell);}cell.push(index);}}
   this.references+=count;
  }
  this.overflowTriangles=this.overflow.map(index=>triangles[index]);
  if(this.references+this.overflow.length*[...this.cells.values()].reduce((n,c)=>n+c.size,0)>maxReferences)this.fallback=true;
  if(this.fallback){this.cells.clear();this.references=0;this.overflow=[];this.overflowTriangles=[];return;}
  // Merge once during construction so query arrays retain exact source order,
  // including exceptional triangles. No query sorting or temporary arrays.
  for(const column of this.cells.values())for(const [key,local]of column){const merged=[];let a=0,b=0;while(a<local.length||b<this.overflow.length){const index=b>=this.overflow.length||a<local.length&&local[a]<this.overflow[b]?local[a++]:this.overflow[b++];merged.push(triangles[index]);}column.set(key,merged);}
 }
 height(x,z,referenceHeight=Infinity,maxDelta=Infinity){
  if(this.closed)return null;this.queries++;
  const full=this.fallback||this.source.length!==this.sourceCount||!Number.isFinite(x)||!Number.isFinite(z)||Math.abs(x)>this.coordinateLimit||Math.abs(z)>this.coordinateLimit;
  const triangles=full?this.source:(this.cells.get(Math.floor(x/this.cellSize))?.get(Math.floor(z/this.cellSize))??this.overflowTriangles);
  if(full)this.fullScans++;this.candidates+=triangles.length;
  return findWalkableHeight(triangles,x,z,referenceHeight,maxDelta);
 }
 snapshot(){return{triangles:this.sourceCount,cells:[...this.cells.values()].reduce((n,c)=>n+c.size,0),references:this.references,overflow:this.overflow.length,queries:this.queries,candidates:this.candidates,fullScans:this.fullScans,fallback:this.fallback,closed:this.closed};}
 dispose(){this.cells.clear();this.overflow=[];this.overflowTriangles=[];this.source=null;this.references=0;this.closed=true;}
}
