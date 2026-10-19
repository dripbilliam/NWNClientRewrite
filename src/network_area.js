import {decodeGffText} from './gff_text.js';
import {satisfiesNativeBuild} from './network_build.js';

const string=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';};
const ref=r=>{const v=r.readCResRef(),end=v.indexOf(0);return decodeGffText(end<0?v:v.subarray(0,end));};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:string(r)};
const vector=r=>[r.readFloat(),r.readFloat(),r.readFloat()];
function count(r,n,minimum,label){
 if(!Number.isInteger(n)||n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/minimum))throw new Error(`Invalid native area ${label} count`);
 return n;
}
const fields=(r,offsets,method,target={})=>{for(const offset of offsets)target[offset.toString(16)]=r[method]();return target;};

// Inverse of the original PackAreaIntoMessage140363200..140364661, including
// ambient/sound packers358750/4f5120. Preserve unclassified native fields by
// offset instead of assigning guessed renderer meanings. The client wire ID
// namespace (including bit31) is retained for every referenced object.
export function readAreaState(r,build){
 if(!build||![build.number,build.revision,build.postfix].every(Number.isInteger))throw new Error('Native client build for area information is unavailable');
 const atLeast=(revision,postfix=0)=>satisfiesNativeBuild(build,{number:8193,revision,postfix});
 const area={id:r.readObjectIdClient(),resRef:ref(r)};
 area.name=r.readBool()?{text:string(r)}:localized(r);
 area.moduleEntry=[r.readInt(),r.readInt(),r.readInt()];
 const f=area.fields={};
 fields(r,[8,0x98,0x9c],'readDword',f);
 if(atLeast(35))fields(r,[0xac,0xb0,0xb4],'readFloat',f);
 fields(r,[0xa0],'readDword',f);fields(r,[0xa4],'readByte',f);fields(r,[0xa8],'readBool',f);fields(r,[0xb8,0xbc],'readDword',f);
 if(atLeast(35))fields(r,[0xcc,0xd0,0xd4],'readFloat',f);
 fields(r,[0xc0],'readDword',f);fields(r,[0xc4],'readByte',f);fields(r,[0xc8,0xd8,0xdc],'readBool',f);
 area.pvp=r.readByte();fields(r,[0x100],'readBool',f);fields(r,[0x104],'readByte',f);fields(r,[0x108],'readFloat',f);fields(r,[0x34c],'readInt',f);
 area.ambient={};fields(r,[8,0x18,0x20],'readBool',area.ambient);fields(r,[0xc,0x10,0x14,0x1c,0x24,0x28],'readInt',area.ambient);fields(r,[0x2c,0x2d],'readByte',area.ambient);
 area.time={timeOfDay:r.readByte(),transition:r.readDword(),hour:r.readByte(),day:r.readByte(),month:r.readByte(),year:r.readDword(),dawn:r.readByte(),dusk:r.readByte()};
 fields(r,[0xe0,0xe3,0xe4],'readByte',f);
 if(atLeast(14)&&f.e4===3)fields(r,[0xe8,0xec,0xf0,0xf4,0xf8,0xfc],'readFloat',f);
 area.weather={type:r.readByte(),enabled:r.readBool()};
 area.width=r.readInt();area.height=r.readInt();area.tileset=ref(r);area.grass=[];
 if(atLeast(36,3)){
  fields(r,[0x368],'readBool',f);const n=count(r,r.readInt(),37,'grass');
  for(let i=0;i<n;i++){const entry={field10:r.readByte(),name:string(r),fields:fields(r,[0x28,0x2c,0x30,0x34,0x38,0x3c,0x40,0x44],'readFloat')};area.grass.push(entry);}
 }
 if(atLeast(36,5))fields(r,[0x10c],'readBool',f);
 // Dimensions are signed in the native owner. Reject impossible products
 // rather than wrapping/allocating from a damaged or hostile packet.
 if(area.width<0||area.height<0)throw new Error('Invalid native area dimensions');
 const tiles=count(r,area.width*area.height,16,'tile');area.tiles=[];
 for(let i=0;i<tiles;i++){
  const tile={fields:fields(r,[0x14,0x24,0x18],'readInt')},mask=r.readWord();tile.lightMask=mask;
  for(const [bit,offset]of [[1,0x28],[2,0x29],[4,0x2a],[8,0x2b],[16,0x2c],[32,0x2d],[64,0x2e],[128,0x2f]])tile.fields[offset.toString(16)]=mask&bit?r.readByte():0;
  area.tiles.push(tile);
 }
 area.mapPins=[];let n=count(r,r.readInt(),20,'map-pin');
 for(let i=0;i<n;i++)area.mapPins.push({id:r.readObjectIdClient(),position:vector(r),enabled:r.readBool(),name:localized(r)});
 area.playerMapPins=[];n=count(r,r.readInt(),20,'player-map-pin');
 for(let i=0;i<n;i++)area.playerMapPins.push({index:r.readInt(),text:string(r),position:vector(r)});
 area.sounds=[];n=count(r,r.readWord(),53,'sound');
 for(let i=0;i<n;i++){
  const sound={id:r.readObjectIdClient(),fields:{}},s=sound.fields;
  fields(r,[0x308,0x30c,0x310],'readBool',s);fields(r,[0x314,0x318,0x31c],'readByte',s);fields(r,[0x320],'readFloat',s);fields(r,[0x324],'readDword',s);fields(r,[0x328],'readByte',s);
  fields(r,[0x348,0x34c],'readDword',s);fields(r,[0x350,0x354],'readFloat',s);fields(r,[0x358,0x35c,0x32c],'readBool',s);fields(r,[0x330,0x334],'readFloat',s);
  sound.position=vector(r);sound.refs=[];const refs=count(r,r.readWord(),16,'sound-reference');for(let j=0;j<refs;j++)sound.refs.push(ref(r));area.sounds.push(sound);
 }
 area.placeableLights=[];n=count(r,r.readWord(),18,'placeable-light');
 for(let i=0;i<n;i++)area.placeableLights.push({id:r.readObjectIdClient(),appearance:r.readWord(),position:vector(r)});
 area.staticPlaceables=[];n=count(r,r.readWord(),30,'static-placeable');
 for(let i=0;i<n;i++)area.staticPlaceables.push({id:r.readObjectIdClient(),appearance:r.readWord(),position:vector(r),orientation:vector(r)});
 area.reservedCounts=[r.readWord(),r.readWord()];
 if(area.reservedCounts.some(n=>n!==0))throw new Error('Unsupported native area trailing records');
 return area;
}

// SendServerToPlayerArea_ClientArea1404cd9d0..1404ce035 wraps that body.
export function readClientArea(r,build){
 const loadingScreen=r.readInt(),position=vector(r),facing=r.readFloat(),flag=r.readBool(),area=readAreaState(r,build);
 return{loadingScreen,position,facing,flag,area};
}
