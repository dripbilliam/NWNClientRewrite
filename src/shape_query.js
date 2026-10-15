import {OBJECT_INVALID} from './game_object_array.js';
import {normalizeOrientation} from './combat_lifecycle.js';
const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native shape provider ${n} is unavailable`);return p[n];};
const point=v=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error('Native shape vector is unavailable');return v.map(f);};
const sub=(a,b)=>a.map((v,n)=>f(v-b[n]));
const square=v=>f(f(f(v[1]*v[1])+f(v[0]*v[0]))+f(v[2]*v[2]));
const dot=(a,b)=>f(f(f(a[1]*b[1])+f(a[0]*b[0]))+f(a[2]*b[2]));
const normalize=v=>{const n=normalizeOrientation([v[0],v[2],f(-v[1])]);return[n[0],f(-n[2]),n[1]];};
const magnitude=v=>f(Math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))));

// lineproject140230220: infinite line, not a clamped segment. Dot and
// squared denominator have distinct native SSE addition orders.
export function nativeLineProjection(start,end,candidate){
  const direction=sub(end,start),denominator=f(f(f(direction[0]*direction[0])+f(direction[1]*direction[1]))+f(direction[2]*direction[2]));
  const scale=denominator===0?0:f(dot(sub(candidate,start),direction)/denominator);
  return direction.map((v,n)=>f(f(v*scale)+start[n]));
}
const types={5:1,6:2,7:4,10:8,11:16,12:32,9:64,14:128,13:256};
// ExecuteCommandGetObjectInShape14052d520, first ordinal128/next129.
// The shared area238 cursor only changes on a returned object. Preserve
// full XYZ distances, native cone quirks and the exact transparent LOS flag.
export async function objectInShape(first,self,shape,size,location,los,filter,target,p){
  if(!Number.isInteger(shape)||!Number.isInteger(los)||!Number.isInteger(filter))throw new Error('Native shape INT arguments are unavailable');
  shape|=0;los|=0;filter|=0;size=f(size);if(!Number.isFinite(size))throw new Error('Native shape size is unavailable');
  const area=required(p,'area')(location?.areaId);if(!area)return OBJECT_INVALID;
  let end=point(location.position),start=point(target),minimum,maximum;
  if(shape===3&&self)start=point(required(p,'position')(self));
  const source=[...(shape===0||shape===1||shape===3?start:end)];source[2]=f(source[2]+1);
  if(shape===1||shape===3){minimum=f(Math.min(end[0],start[0])-size);maximum=f(Math.max(end[0],start[0])+size);}
  else{minimum=f(end[0]-size);maximum=f(end[0]+size);}
  if(shape===0){
    const direction=normalize(sub(end,start)),offset=[f(direction[1]*f(-1.5)),f(direction[0]*f(1.5)),f(direction[2]*f(1.5))];
    end=direction.map((v,n)=>f(f(v*size)+start[n]));
    const corners=[start.map((v,n)=>f(v+offset[n])),start.map((v,n)=>f(v-offset[n])),end.map((v,n)=>f(v+offset[n])),end.map((v,n)=>f(v-offset[n]))];
    minimum=Math.min(...corners.map(v=>v[0]));maximum=Math.max(...corners.map(v=>v[0]));
  }
  let index;if(first)index=required(p,'firstByX')(area,minimum);
  else{if(!Number.isInteger(area.nativeObjectCursor238))throw new Error('Native shape shared area cursor is unavailable');index=(area.nativeObjectCursor238+1)|0;}
  if(index===null)return OBJECT_INVALID;if(index<0)throw new Error('Native shape cursor is outside allocated storage');
  const squaredSize=f(size*size);let cached=[0,0,0];
  for(;index<required(p,'spatialIds')(area).length;index++){
    const o=required(p,'object')(p.spatialIds(area)[index]);if(o&&o.objectType>4)cached=point(p.position(o));
    if(cached[0]>maximum)return OBJECT_INVALID;if(!o)continue;
    let admitted=Boolean(filter&(types[o.objectType]??0));
    if(o.objectType===5&&admitted&&required(p,'isDM')(o)!==0)admitted=false;
    if((filter&0x7fff)===0x7fff)admitted=true;if(!admitted)continue;
    let inside;
    if(shape===2)inside=cached.every((v,n)=>v<=f(end[n]+size)&&v>=f(end[n]-size));
    else if(shape===0){
      inside=square(sub(cached,start))<=squaredSize&&dot(normalize(sub(cached,start)),normalize(sub(end,start)))>=0;
      if(inside)inside=square(sub(cached,nativeLineProjection(start,end,cached)))<=f(2.25);
    }else if(shape===1||shape===3){
      const projection=nativeLineProjection(start,end,cached),along=sub(projection,start),alignment=dot(normalize(sub(cached,start)),normalize(sub(end,start)));
      if(shape===3)inside=alignment>=f(.866)&&square(along)<=squaredSize&&square(along)>=f(.01);
      else{const width=f(f(size/magnitude(sub(end,start)))*magnitude(projection));inside=alignment>0&&square(sub(cached,projection))<=f(width*width);}
    }else inside=square(sub(cached,end))<=squaredSize;
    if(!inside)continue;
    cached[2]=f(cached[2]+1);
    if(los!==0&&await required(p,'lineOfSight')(area,source,cached,self?.id??OBJECT_INVALID,o.id,1)===0)continue;
    area.nativeObjectCursor238=index;return o.id>>>0;
  }
  return OBJECT_INVALID;
}
