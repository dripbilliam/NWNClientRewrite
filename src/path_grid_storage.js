// Native CPathfindInformation grid search owners, EE 89.8193.37-17.
// Local owned allocations mirror logical native fields, not pointer values.
const f=Math.fround;
export const pathInt=(path,offset)=>path.raw.getInt32(offset,true);
export const pathFloat=(path,offset)=>path.raw.getFloat32(offset,true);
export const setPathInt=(path,offset,value)=>path.raw.setInt32(offset,value,true);
export const setPathFloat=(path,offset,value)=>path.raw.setFloat32(offset,value,true);
const allocation=(path,offset,Type)=>{
  const value=path.allocations.get(offset);
  if(!(value instanceof Type))throw new Error(`Native grid allocation +${offset.toString(16)} is unavailable`);
  return value;
};
export const gridActivePaths=path=>pathInt(path,0x1d8);
export function gridStepSize(path){
  let radius=pathFloat(path,4);if(f(.1)<radius&&radius<=f(.65))radius=f(.1);
  return f(.1)<=radius?radius:f(.1);
}
// fast_rsqrt14022fd20: Quake bit estimate and ONE SSE Newton step.
export function nativeFastRsqrt(value){
  value=f(value);const bits=new DataView(new ArrayBuffer(4));bits.setFloat32(0,value,true);
  bits.setInt32(0,(0x5f3759df-(bits.getInt32(0,true)>>1))|0,true);
  const estimate=bits.getFloat32(0,true);
  return f(f(f(1.5)-f(f(f(value*f(.5))*estimate)*estimate))*estimate);
}
// GetGridSearchPathInfo140294250 returns a value copy of all 24 bytes.
export function gridPathInfo(path,index){
  const info=allocation(path,0x1e0,DataView);
  if(!Number.isInteger(index)||index<0||index>=gridActivePaths(path))throw new Error('Native grid path index is out of bounds');
  return new DataView(info.buffer.slice(index*24,index*24+24));
}
export function setGridPathInfo(path,index,value){
  const info=allocation(path,0x1e0,DataView);
  if(!(value instanceof DataView)||value.byteLength!==24||index<0||index>=gridActivePaths(path))throw new Error('Native grid path record is unavailable');
  new Uint8Array(info.buffer,index*24,24).set(new Uint8Array(value.buffer,value.byteOffset,24));
}
export function gridPathPoints(path,index){
  const paths=path.allocations.get(0x1d0),value=paths?.[index];
  if(!(value instanceof Int32Array))throw new Error('Native grid path point allocation is unavailable');return value;
}
// CreateGridSearchPath140293fe0 caps paths at32, never reuses a closed path.
export function createGridPath(path){
  const index=gridActivePaths(path);if(index>=32)return -1;
  const info=allocation(path,0x1e0,DataView),paths=path.allocations.get(0x1d0),capacity=pathInt(path,0x17c);
  if(!Array.isArray(paths)||index<0||capacity<1)throw new Error('Native grid search initialization is unavailable');
  new Uint8Array(info.buffer,index*24,21).fill(0);info.setInt32(index*24,1000000,true);
  setPathInt(path,0x1d8,index+1);paths[index]=new Int32Array(capacity*2);return index;
}
function searchedIndex(path,x,y,points){
  const index=(Math.imul((Math.imul(pathInt(path,0x1b8),2)+1)|0,(pathInt(path,0x1bc)+y)|0)+pathInt(path,0x1b8)+x)|0;
  if(index<0||index>=points.length)throw new Error('Native grid searched-point index is out of bounds');return index;
}
export function gridPointSearched(path,x,y){
  const points=path.allocations.get(0x1b0);return points?points[searchedIndex(path,x,y,points)]!==0:false;
}
export function setGridPointSearched(path,x,y,value){
  const points=path.allocations.get(0x1b0);if(points)points[searchedIndex(path,x,y,points)]=Number(value)&255;
}
// AddToGridSearchPath140293d50 keeps squared distance, count, cumulative cost,
// endpoint and closed BYTE in the distinct native 24-byte record.
export function addGridPoint(path,index,x,y,cost){
  const info=gridPathInfo(path,index),points=gridPathPoints(path,index),count=info.getInt32(4,true);
  if(count<0||count*2+1>=points.length)throw new Error('Native grid path point capacity is exhausted');
  points[count*2]=x;points[count*2+1]=y;
  const distance=(Math.imul(x,x)+Math.imul(y,y))|0;
  info.setInt32(0,distance,true);info.setInt32(4,count+1,true);info.setInt32(8,(info.getInt32(8,true)+cost)|0,true);
  info.setInt32(12,x,true);info.setInt32(16,y,true);setGridPathInfo(path,index,info);setGridPointSearched(path,x,y,1);
  if(distance<pathInt(path,0x198)){
    const best=allocation(path,0x190,Int32Array);best.set(points.subarray(0,(count+1)*2));
    setPathInt(path,0x198,distance);setPathInt(path,0x188,count+1);
  }
}
