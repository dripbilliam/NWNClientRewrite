// REFERENCE / NETWORK-SEMANTIC HELPER ONLY. Not imported by runtime. Final
// reveal/fade presentation and its ordered setter kernel belong in Godot.
// Read-only projection of one received PlayerInfo mask0x200 record. Native
// 7b4f70 -> 850120 assigns tile+30; this is not local LOS/exploration.
// Call exactly once at the ordered raw-record boundary. A sticky automap field
// or a final-map diff cannot identify a new delivery. This helper owns no map,
// lifetime, clock, callbacks or deduplication state.
export const NATIVE_TILE_VISIBILITY_MAX_TILES = 65536;
export const NATIVE_TILE_VISIBILITY_MAX_OPERATIONS = 131072;

const own = (value,key) => Object.prototype.hasOwnProperty.call(value,key);
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value) && !ArrayBuffer.isView(value);
const sequence = value => Array.isArray(value) || value instanceof Uint8Array;
const flag = value => typeof value === 'boolean' ? Number(value) : typeof value === 'number' && Number.isFinite(value) && (value === 0 || value === 1) ? (value === 0 ? 0 : 1) : null;
const integer = (value,min,max) => typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max;
const unavailable = (reason,field) => ({available:false,reason,field,states:null,operations:[],warnings:[],delivery:null});

/**
 * Return detached final states and native-ordered setter operations for one
 * complete decoded change. Each operation says whether850120 changes the field
 * and whether its BEFORE-STORE object notification runs. No callbacks execute.
 *
 * previous: caller-owned current native tile+30 integers, including known
 * initialization; missing state is unavailable, never inferred unexplored.
 * change: decoder-shaped {mode:[BOOL,BOOL],points:[...]|bytes:[BYTE,...]}.
 * delivery: optional caller-owned {scope:string,serial:safe nonnegative int};
 * copied as evidence only. The existing receiver owns once-only dispatch.
 * An executing adapter must recheck its live previous value at each operation
 * if callbacks can reenter replication; these projected changed/previous fields
 * describe a plain, callback-free replay of the supplied snapshot.
 */
export function projectNativeTileVisibility(input){
 if(!record(input))return unavailable('missing-input','input');
 const {width,height,previous,change}=input;
 if(!integer(width,1,NATIVE_TILE_VISIBILITY_MAX_TILES) || !integer(height,1,NATIVE_TILE_VISIBILITY_MAX_TILES) || width*height>NATIVE_TILE_VISIBILITY_MAX_TILES)return unavailable('invalid-dimensions','width/height');
 const size=width*height;
 if(!sequence(previous) || previous.length!==size)return unavailable('missing-current-tile-state','previous');
 for(let i=0;i<size;i++)if(!integer(previous[i],-2147483648,2147483647))return unavailable('invalid-current-tile-state',`previous[${i}]`);
 if(!record(change) || !Array.isArray(change.mode) || change.mode.length!==2)return unavailable('missing-mode','change.mode');
 const first=flag(change.mode[0]),second=flag(change.mode[1]);
 if(first===null || second===null)return unavailable('invalid-mode','change.mode');
 let delivery=null;
 if(own(input,'delivery')){
  const value=input.delivery;
  if(!record(value) || typeof value.scope!=='string' || value.scope.length===0 || !integer(value.serial,0,Number.MAX_SAFE_INTEGER))return unavailable('invalid-delivery','delivery');
  delivery={scope:value.scope,serial:value.serial};
 }
 // Validate the entire decoded payload before constructing a partial result.
 if(second){
  if(!sequence(change.bytes) || change.bytes.length>255)return unavailable('missing-or-invalid-packed-bytes','change.bytes');
  for(let i=0;i<change.bytes.length;i++)if(!integer(change.bytes[i],0,255))return unavailable('invalid-packed-byte',`change.bytes[${i}]`);
 }else{
  if(!Array.isArray(change.points))return unavailable('missing-points','change.points');
  const requested=change.points.length+(first?size:0);
  if(requested>NATIVE_TILE_VISIBILITY_MAX_OPERATIONS)return unavailable('operation-limit','change.points');
  for(let i=0;i<change.points.length;i++){
   const point=change.points[i];
   if(!record(point) || !integer(point.x,0,255) || !integer(point.y,0,255))return unavailable('invalid-point',`change.points[${i}]`);
   if(!first && flag(point.state)===null)return unavailable('missing-or-invalid-point-state',`change.points[${i}].state`);
  }
 }
 const states=Array.from(previous),operations=[],warnings=[];
 const set=(x,y,value,suppress,pointIndex=null)=>{
  // Native decoded point coordinates are BYTEs. Out-of-area points warn and
  // continue; a missing tile is not created and is not treated as state0.
  if(x>=width || y>=height){warnings.push({code:'missing-tile',x,y,point_index:pointIndex});return;}
  const index=y*width+x,old=states[index],changed=old!==value;
  operations.push({sequence:operations.length,tile_index:index,x,y,previous:old,new_state:value,suppress_object_updates:suppress,changed,notify_objects:changed && suppress===0});
  // Consumers executing callbacks must do so before applying this store. The
  // returned array is only the detached final projection, not a callback view.
  if(changed)states[index]=value;
 };
 if(second){
  // Native accepts both(0,1) and(1,1). Only supplied bytes are visited: do not
  // clear an absent tail.7e7510 computes this exact linear bit-to-tile index.
  for(let byteIndex=0;byteIndex<change.bytes.length;byteIndex++)for(let bit=0;bit<8;bit++){
   const index=byteIndex*8+bit;
   if(index>=size)continue;
   const value=(change.bytes[byteIndex]>>>bit)&1;
   set(index%width,Math.floor(index/width),value,1-value);
  }
 }else if(first){
  const value=change.points.length===0?1:0;
  // Original full replacement is X-major, unlike packed linear indexing.
  for(let x=0;x<width;x++)for(let y=0;y<height;y++)set(x,y,value,1-value);
  for(let i=0;i<change.points.length;i++){const point=change.points[i];set(point.x,point.y,1,0,i);}
 }else{
  for(let i=0;i<change.points.length;i++){const point=change.points[i],value=flag(point.state);set(point.x,point.y,value,1-value,i);}
 }
 return {available:true,reason:null,field:null,states,operations,warnings,delivery};
}
