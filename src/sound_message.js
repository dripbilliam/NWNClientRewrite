import {encodeGffText} from './gff_text.js';
const f=Math.fround;
const value=(data,key,kind,fallback)=>{
 const v=data[key]??fallback;
 if(kind==='float'){if(typeof v!=='number')throw new Error(`Native sound FLOAT ${key} is unavailable`);return f(v);}
 if(!Number.isInteger(v))throw new Error(`Native sound ${kind} ${key} is unavailable`);
 return kind==='bool'?Number((v&255)!==0):kind==='byte'?v&255:v>>>0;
};
const reference=text=>{
 if(typeof text!=='string')throw new Error('Native sound resource reference is unavailable');
 const raw=encodeGffText(text),end=raw.indexOf(0),out=new Uint8Array(17);out.set(raw.subarray(0,Math.min(16,end<0?raw.length:end)));return out;
};

// Selected CNWSSoundObject ctor fields1404f3637..1404f36ad. Canonical
// base-object identity/lifecycle belongs to the shared registry, not this state.
export function initializeSoundMessageState(object){
 object.nativeMessageFields={0x308:1,0x30c:1,0x310:0,0x314:127,0x318:0,0x31c:3,0x320:0,0x324:0,0x328:0,0x32c:0,0x330:0,0x334:0,0x348:0,0x34c:0,0x350:10,0x354:20,0x358:0,0x35c:0};
 object.nativeSoundRefs338=[];object.nativeSoundRefCapacity344=0;
 Object.defineProperty(object.nativeMessageFields,0x340,{enumerable:true,configurable:true,get:()=>object.nativeSoundRefs338.length});
}
// Load scalar/list portions1404f4c3e..1404f50d8. Existing scalar defaults
// are retained, positions default0, and successful Sounds entries append without
// clearing/deduplicating on reload. GeneratedType/RandomPosition are raw bytes.
export function loadSoundMessageState(object,data){
 const fields=object.nativeMessageFields;if(!fields)throw new Error('Native sound constructor state is unavailable');
 for(const [offset,name,kind]of [[0x308,'Active','bool'],[0x30c,'Positional','bool'],[0x310,'Looping','bool'],[0x314,'Volume','byte'],[0x318,'VolumeVrtn','byte'],[0x31c,'Times','byte'],[0x320,'PitchVariation','float'],[0x324,'Hours','dword'],[0x328,'GeneratedType','byte'],[0x348,'Interval','dword'],[0x34c,'IntervalVrtn','dword'],[0x350,'MinDistance','float'],[0x354,'MaxDistance','float'],[0x358,'Continuous','bool'],[0x35c,'Random','bool'],[0x32c,'RandomPosition','byte'],[0x330,'RandomRangeX','float'],[0x334,'RandomRangeY','float']])fields[offset]=value(data,name,kind,fields[offset]);
 object.position=[value(data,'XPosition','float',0),value(data,'ZPosition','float',0),-value(data,'YPosition','float',0)];
 if(data.Sounds===undefined||data.Sounds===null)return;
 if(!Array.isArray(data.Sounds))throw new Error('Native sound resource list is unavailable');
 for(const entry of data.Sounds){
  if(entry?.Sound===undefined||entry.Sound===null)continue;
  const ref=reference(entry.Sound);
  if(object.nativeSoundRefs338.length===object.nativeSoundRefCapacity344)object.nativeSoundRefCapacity344=object.nativeSoundRefCapacity344===0?16:object.nativeSoundRefCapacity344*2;
  object.nativeSoundRefs338.push(ref);
 }
}
