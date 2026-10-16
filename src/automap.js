import {NativeIdList} from './native_id_list.js';
const f=Math.fround;
const ids=o=>{if(!(o.nativeAutoMapAreaIds6c8 instanceof NativeIdList))throw new Error('Native automap area-ID storage is unavailable');return o.nativeAutoMapAreaIds6c8;};
const buffer=(o,index)=>{
  const b=o.nativeAutoMapBuffers6d8?.[index];if(!(b instanceof Uint8Array)||b.length!==128)throw new Error('Native automap tile buffer is unavailable');return b;
};
const bounded=n=>{if(!Number.isInteger(n)||n<0||n>65536)throw new Error('Native automap allocation count is unavailable');return n;};
export function initializeAutomapState(o){
  o.nativeAutoMapAreaIds6c8??=new NativeIdList();o.nativeAutoMapBuffers6d8??=null;o.nativeAutoMapEnabled6e0??=1;
}
// LoadArea14035f72b..14035f750: signed product, f32 /8, ceilf, BYTE.
export function automapByteCount(width,height){return Math.ceil(f(f(Math.imul(width,height))*.125))&255;}

// ClearAutoMapData140387b40. Autoexplore flag and cached tile/area survive.
export function clearAutomap(o){
  const list=ids(o),maps=o.nativeAutoMapBuffers6d8;
  if(maps){if(maps.length<list.count)throw new Error('Native automap pointer array is incomplete');for(let i=0;i<list.count;i++)maps[i]=null;}
  o.nativeAutoMapBuffers6d8=null;list.setSize(0);
}
// PostProcess14039b897..14039b9e6. A PC or possessed familiar allocates
// fresh zeroed maps only when the outer pointer is null, independent of IDs.
export async function postProcessAutomap(o,p){
  if(!Number.isInteger(o.nativeField89c))throw new Error('Native automap PC object flag is unavailable');
  if(o.nativeField89c===0&&await p.possessedFamiliar(o)===0)return;
  if(o.nativeAutoMapBuffers6d8!==null)return;
  const module=await p.module(),list=ids(o);o.nativeAutoMapBuffers6d8=[];list.setSize(0);
  for(let i=0;i<p.moduleIds(module).length;i++){
    o.nativeAutoMapBuffers6d8.push(new Uint8Array(128));list.append(p.moduleIds(module)[i]);
  }
}
// ReconcileAutoMapData14039dbc0: preserve buffers by first old ID match;
// transferred slots become null before old ownership is released. A null
// outer array is deliberately not initialized by reconciliation.
export async function reconcileAutomap(o,p){
  const old=o.nativeAutoMapBuffers6d8;if(old===null)return;
  const module=await p.module(),next=p.moduleIds(module),list=ids(o);
  if(next.length===list.count&&next.every((id,i)=>id===list.ids[i]))return;
  const maps=[];
  for(let i=0;i<next.length;i++){
    const index=list.indexOf(next[i]);if(index<0)maps.push(new Uint8Array(128));
    else{maps.push(old[index]);old[index]=null;}
  }
  list.setSize(next.length);list.ids.set(next);o.nativeAutoMapBuffers6d8=maps;
}
// SetAutoMapData1403a2d50: equal counts preserve allocations, different
// counts clear/rebuild. Incoming vectors are copied, not adopted.
export async function setAutomap(o,areaIds,maps,p){
  bounded(areaIds.length);if(maps.length<areaIds.length)throw new Error('Native incoming automap pointer array is incomplete');
  for(let i=0;i<areaIds.length;i++)if(!(maps[i] instanceof Uint8Array)||maps[i].length<128)throw new Error('Native incoming automap data is incomplete');
  const list=ids(o);
  if(list.count===areaIds.length){list.ids.set(areaIds);for(let i=0;i<areaIds.length;i++)buffer(o,i).set(maps[i].subarray(0,128));}
  else{clearAutomap(o);o.nativeAutoMapBuffers6d8=[];for(let i=0;i<areaIds.length;i++){list.append(areaIds[i]);o.nativeAutoMapBuffers6d8.push(maps[i].slice(0,128));}}
  await reconcileAutomap(o,p);
}
function fullVoid(value,count,label){
  if(!(value instanceof Uint8Array)||value.byteLength<count)throw new Error(`Native ${label} has an indeterminate allocated byte tail`);
  return value.subarray(0,count);
}
// LoadAutoMapData140397400. Empty existing list exits before reading area
// IDs or the autoexplore flag. ReadFieldVOID copies only available bytes;
// malformed short/missing buffers remain explicitly unsupported, never zeroed.
export function loadAutomap(o,data){
  clearAutomap(o);const count=bounded((data.Mod_MapNumAreas??0)|0),rows=data.Mod_MapDataList;
  if(rows!==undefined){
    if(!Array.isArray(rows))throw new Error('Native Mod_MapDataList is unavailable');
    bounded(rows.length);if(rows.length===0)return;
    o.nativeAutoMapBuffers6d8=rows.map(row=>fullVoid(row.Mod_MapData,128,'Mod_MapData').slice());
  }
  if(count){const bytes=fullVoid(data.Mod_MapAreasData,count*4,'Mod_MapAreasData'),view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),list=ids(o);list.setSize(count);for(let i=0;i<count;i++)list.ids[i]=view.getUint32(i*4,true);}
  o.nativeAutoMapEnabled6e0=Number(((data.Mod_MapAutoExplores??1)&255)!==0);
}

export async function automapIndex(o,id,p){
  let index=ids(o).indexOf(id>>>0);if(index===-1){await reconcileAutomap(o,p);index=ids(o).indexOf(id>>>0);}return index;
}
const cell=(area,x,y)=>{
  const linear=(Math.imul(area.width|0,y|0)+(x|0))|0,byte=Math.trunc(linear/8),shift=(linear-byte*8)&31;
  if(byte<0||byte>=128)throw new Error('Native automap tile access is outside its allocated buffer');return{byte,shift};
};
// Get/SetTileExplored140393270/1403a4330. No invented XY bounds: native
// computes a signed linear index, truncating division by8 toward zero.
export async function getTileExplored(o,id,x,y,p){
  id>>>=0;const area=await p.areaById(id);if(!area)return 0;
  const index=await automapIndex(o,id,p);if(index===-1)return 0;
  const {byte,shift}=cell(area,x,y);return(buffer(o,index)[byte]>>>shift)&1;
}
export async function setTileExplored(o,id,x,y,value,p){
  id>>>=0;const area=await p.areaById(id);if(!area)return;
  const index=await automapIndex(o,id,p);if(index===-1)return;
  const {byte,shift}=cell(area,x,y),b=buffer(o,index),mask=(1<<shift)&255;b[byte]=value===0?b[byte]&~mask:b[byte]|mask;
}
// SetAllTilesExplored1403a2ac0 fills area BYTE348 bytes. Clearing a
// client-owned creature immediately reapplies automatic exploration.
export async function setAllTilesExplored(o,id,value,p){
  id>>>=0;const area=await p.areaById(id);if(!area)return;
  const index=await automapIndex(o,id,p);if(index===-1)return;
  if(!Number.isInteger(area.nativeMapByteCount348))throw new Error('Native automap area byte count is unavailable');
  const count=area.nativeMapByteCount348&255;if(count>128)throw new Error('Native automap area byte count exceeds its allocation');
  if(count)buffer(o,index).fill(value===0?0:255,0,count);
  if(value===0&&await p.client(o.id))await p.update(o,o.id);
}
const cvtt=n=>n>=-2147483648&&n<2147483648?Math.trunc(n)|0:-2147483648;
// UpdateAutoMap1403a7390. Flags&3 selects native visibility DFS; otherwise
// reveal3x3 with X outer/Y inner order. Explicit target can differ from viewer.
export async function updateAutomap(o,targetId,p){
  if(!Number.isInteger(o.nativeAutoMapEnabled6e0))throw new Error('Native autoexplore flag is unavailable');
  if(o.nativeAutoMapEnabled6e0===0||!await p.area(o))return;
  const target=await p.creature(targetId>>>0);if(!target)return;
  const position=p.position(o),x=cvtt(f(f(position[0])/f(10))),y=cvtt(f(f(position[1])/f(10)));
  if(x<0||y<0||x>=(await p.area(o)).width||y>=(await p.area(o)).height)return;
  if(((await p.area(o)).flags&1)===0&&((await p.area(o)).flags&2)===0){
    for(let dx=-1;dx<2;dx++)for(let dy=-1;dy<2;dy++){
      const area=await p.area(o),tx=x+dx,ty=y+dy;
      if(ty<0||ty>=area.height||tx<0||tx>=area.width||!await p.tileExists(area,tx,ty))continue;
      const id=(await p.area(o)).id;if(await getTileExplored(target,id,tx,ty,p)===0)await setTileExplored(target,(await p.area(o)).id,tx,ty,1,p);
    }
  }else await p.explore(await p.area(o),target,x,y,8);
}
// ExploreArea14036bb40 returns1 after merge/free (assembly14036bc69),0
// when its area is absent from the target list. No reconciliation here.
export async function exploreArea(area,o,x,y,range,p){
  const index=ids(o).indexOf(area.id);if(index===-1)return 0;
  const count=bounded(Math.imul(area.width,area.height)),visited=new Uint8Array(count),position=p.position(o);
  await p.dfs(area,visited,(range+1)|0,x|0,y|0,f(f(position[0])-f(f(x)*10)),f(f(position[1])-f(f(y)*10)));
  const b=buffer(o,index);if(count>1024)throw new Error('Native explored area exceeds its map buffer');
  for(let i=0;i<count;i++)if(visited[i]!==0)b[i>>3]|=1<<(i&7);return 1;
}
