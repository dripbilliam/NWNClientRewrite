// Experimental conservative SCREEN-TILE membership. Light shading and source
// order stay in the original shader. Every overflow/unknown input keeps the
// ordinary full light loop; no nearest-N or capacity truncation is permitted.
export const POINT_GRID_FALLBACK=0xffffffff;
const popcount=v=>{v-=v>>>1&0x55555555;v=(v&0x33333333)+(v>>>2&0x33333333);return((v+(v>>>4)&0x0f0f0f0f)*0x01010101)>>>24;};
function rectangle(light,projection,near,width,height,tile,cols,rows,perspective){
 const [x,y,z]=light.position,radius=light.radius;
 // NWN's installed legacy adapter encodes quadratic attenuation with negative
 // decay. That branch has INFINITE support even when distance/radius > 0.
 // Keep every such light in every cell; radius is not a shader cutoff there.
 if(![x,y,z,radius,light.decay??2].every(Number.isFinite)||Math.max(Math.abs(x),Math.abs(y),Math.abs(z))>1e15||!light.neutral&&(!(radius>0)||(light.decay??2)<0))return[0,0,cols-1,rows-1];
 // Only renderer-owned zero-color padding can use a small unsafe neighborhood
 // instead of its infinite cutoff. Near-zero direction retains ordinary math.
 const r=light.neutral?Math.max(.0001,Math.max(Math.abs(x),Math.abs(y),Math.abs(z))*1e-6):radius*(1+.0001)+.0001;
 if(z-r>-near)return null;
 if(perspective&&z+r>=-near)return[0,0,cols-1,rows-1];
 let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
 for(let mask=0;mask<8;mask++){
  const px=x+(mask&1?r:-r),py=y+(mask&2?r:-r),pz=z+(mask&4?r:-r),p=projection,w=p[3]*px+p[7]*py+p[11]*pz+p[15],sx=(p[0]*px+p[4]*py+p[8]*pz+p[12])/w,sy=(p[1]*px+p[5]*py+p[9]*pz+p[13])/w;
  if(!Number.isFinite(sx)||!Number.isFinite(sy)||!(w>0))return[0,0,cols-1,rows-1];
  minX=Math.min(minX,sx);maxX=Math.max(maxX,sx);minY=Math.min(minY,sy);maxY=Math.max(maxY,sy);
 }
 // A whole extra tile covers projection/Float32/interpolation boundary error.
 const left=Math.floor((minX+1)*width*.5/tile)-1,right=Math.floor((maxX+1)*width*.5/tile)+1,bottom=Math.floor((minY+1)*height*.5/tile)-1,top=Math.floor((maxY+1)*height*.5/tile)+1;
 if(right<0||top<0||left>=cols||bottom>=rows)return null;return[Math.max(0,left),Math.max(0,bottom),Math.min(cols-1,right),Math.min(rows-1,top)];
}
export function buildPointLightGrid({lights,firstShadow=0,width,height,tileSize=96,projection,near,perspective=true,data=new Uint32Array(16384),bits=null}){
 if(!Array.isArray(lights)||!Number.isInteger(firstShadow)||firstShadow<0||firstShadow>lights.length||!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||!Number.isInteger(tileSize)||tileSize<1||!projection||projection.length!==16||!projection.every(Number.isFinite)||!Number.isFinite(near)||near<0||!(data instanceof Uint32Array))throw Error('Invalid point grid input');
 const cols=Math.ceil(width/tileSize),rows=Math.ceil(height/tileSize),cells=cols*rows,words=Math.ceil(lights.length/32);if(cells*2>data.length)return{enabled:false,reason:'header-capacity',cols,rows,data};
 if(!(bits instanceof Uint32Array)||bits.length<cells*words)bits=new Uint32Array(cells*words);else bits.fill(0,0,cells*words);
 for(let index=firstShadow;index<lights.length;index++){
  const light=lights[index],rect=rectangle(light,projection,near,width,height,tileSize,cols,rows,perspective);if(!rect)continue;const word=index>>>5,bit=1<<(index&31);
  for(let y=rect[1];y<=rect[3];y++)for(let x=rect[0];x<=rect[2];x++)bits[(y*cols+x)*words+word]|=bit;
 }
 let at=cells*2,total=0,max=0,fallbackCells=0;const lists=new Map();
 for(let cell=0;cell<cells;cell++){
  let signature='';for(let word=0;word<words;word++)signature+=','+bits[cell*words+word];const previous=lists.get(signature);
  if(previous){data[cell*2]=previous.offset;data[cell*2+1]=previous.count;const count=previous.count===POINT_GRID_FALLBACK?lights.length-firstShadow:previous.count;fallbackCells+=Number(previous.count===POINT_GRID_FALLBACK);total+=count;max=Math.max(max,count);continue;}
  let count=0;for(let word=0;word<words;word++)count+=popcount(bits[cell*words+word]);data[cell*2]=at;
  if(at+count>data.length){data[cell*2+1]=POINT_GRID_FALLBACK;lists.set(signature,{offset:at,count:POINT_GRID_FALLBACK});fallbackCells++;total+=lights.length-firstShadow;max=Math.max(max,lights.length-firstShadow);continue;}
  lists.set(signature,{offset:at,count});
  data[cell*2+1]=count;total+=count;max=Math.max(max,count);
  for(let index=firstShadow;index<lights.length;index++)if(bits[cell*words+(index>>>5)]&(1<<(index&31)))data[at++]=index;
 }
 return{enabled:true,cols,rows,tileSize,data,bits,usedWords:at,firstShadow,lights:lights.length,fallbackCells,uniqueLists:lists.size,averageLights:total/cells,maxLights:max};
}
export function pointGridIndices(grid,x,y){
 if(!grid.enabled||!Number.isFinite(x)||!Number.isFinite(y)||x<0||y<0||x>=grid.cols*grid.tileSize||y>=grid.rows*grid.tileSize)return null;const cell=Math.floor(y/grid.tileSize)*grid.cols+Math.floor(x/grid.tileSize),offset=grid.data[cell*2],count=grid.data[cell*2+1];return count===POINT_GRID_FALLBACK?null:Array.from(grid.data.subarray(offset,offset+count));
}
