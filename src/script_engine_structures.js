import {gffRecord,gffField} from './gff_writer.js';
import {readNativeGff,nativeGffLabel,nativeAssignedString} from './native_gff_fields.js';
import {savedEffectStorage} from './game_effect_load.js';
import {scriptTalent} from './talent.js';
const int=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native script engine ${n} is unavailable`);return v|0;};
const put=(r,n,t,v)=>{r.fields[nativeGffLabel(n)]=gffField(t,v);};
const arrays=[['IntList','integers',5],['FloatList','floats',8],['StringList','strings',10],['ObjectList','objectIds',4]];

// CScriptEvent4c6490 leaves its type WORD unwritten; do not invent type0.
export function scriptEventStorage(){return{type:undefined,integers:[],floats:[],strings:[],objectIds:[],nativeCapacities:{integers:0,floats:0,strings:0,objectIds:0}};}
// ExecuteCommandEventUserDefined14051d510: type WORD11 and INT slot0.
export function scriptUserDefinedEvent(number){const e=scriptEventStorage();e.type=11;e.integers.push(int(number,'user-defined event number'));e.nativeCapacities.integers=16;return e;}
// CopyGameDefinedStructure creates a fresh event then CopyScriptEvent4c68d0.
// Fresh destination capacities are the copied counts, not source spare capacity.
export function copyScriptEventValue(source){
 const result=scriptEventStorage();if(source===null)return result;result.type=source.type===undefined?undefined:int(source.type,'event copy type')&65535;
 for(const [,key,type]of arrays){if(!Array.isArray(source[key]))throw new Error('Native event copy storage is unavailable');result[key]=source[key].map(v=>type===10?nativeAssignedString(v):type===8?Math.fround(v):type===4?int(v,key)>>>0:int(v,key));result.nativeCapacities[key]=result[key].length;}
 return result;
}
// Whole CreateGameDefinedStructure14050d170..14050d25c. These constructors
// consume no effect ID; the unsupported/opaque kinds return native NULL.
export function createScriptEngineStructure(kind){
 if(kind===0||kind===4)return savedEffectStorage();if(kind===1)return scriptEventStorage();
 if(kind===2)return{areaId:0x7f000000,position:[0,0,0],nativeOrientation:[0,0,0]};if(kind===3)return scriptTalent();return null;
}
// Whole SaveEvent1404c7070..1404c728b. Lists exist only for nonempty arrays.
export function saveScriptEvent(event,root){
 put(root,'EventType',2,int(event.type,'event type')&65535);
 for(const [name,key,type]of arrays){
  const values=event[key];if(!Array.isArray(values))throw new Error(`Native script event ${key} storage is unavailable`);
  if(values.length){const rows=[];put(root,name,15,rows);for(const value of values){const row=gffRecord({},105);rows.push(row);put(row,'Parameter',type,type===5?int(value,key):type===4?int(value,key)>>>0:type===8?Math.fround(value):value);}}
 }
 return 1;
}
// Whole LoadEvent1404c6ba0..1404c7067. Existing arrays are appended to,
// never cleared; native capacities start16 and double at the current count.
export function loadScriptEvent(event,data,read=readNativeGff){
 event.type=read(data,'EventType',2,0).value&65535;
 for(const [name,key,type]of arrays){
  const list=read(data,name,15,null);if(list.status===0)continue;
  if(!Array.isArray(event[key])||!Number.isInteger(event.nativeCapacities?.[key]))throw new Error('Native event array ownership is unavailable');
  for(const row of list.value){const count=event[key].length,capacity=event.nativeCapacities[key];if(count>capacity)throw new Error('Native event array count exceeds allocated storage');
   if(count===capacity){const next=capacity===0?16:capacity*2;if(next>0x7fffffff)throw new Error('Native event array allocation overflow is unavailable');event.nativeCapacities[key]=next;}
   const value=read(row,'Parameter',type,type===10?'':0).value;event[key].push(type===5?value|0:type===4?value>>>0:type===8?Math.fround(value):value);
  }
 }
 return 1;
}
const talentFields=[['ID','id',5],['Type','type',5],['MultiClass','classIndex',0],['Item','itemId',4],['ItemPropertyIndex','itemPropertyIndex',5],['CasterLevel','casterLevel',0],['MetaType','metamagic',0]];
export function saveScriptTalent(talent,root){ // SaveTalent14049a570..14049a638.
 for(const [name,key,type]of talentFields){const value=int(talent[key],key);put(root,name,type,type===0?value&255:type===4?value>>>0:value);}return 1;
}
export function loadScriptTalent(talent,data,read=readNativeGff){ // LoadTalent140497880..14049798a.
 for(const [name,key,type]of talentFields){const value=read(data,name,type,0).value;talent[key]=type===0?value&255:type===4?value>>>0:value|0;}return 1;
}
// Whole virtual SaveGameDefinedStructure140552d60..140552e66.
export async function saveScriptEngineStructure(kind,value,p,root){
 kind=int(kind,'structure kind');const node=gffRecord({},kind>>>0);put(root,'GameDefinedStrct',14,node);
 if(kind===0||kind===4){await p.saveEffect(value,node);return 1;}
 if(kind===1)return p.saveEvent(value,node);if(kind===2)return p.saveLocation(value,node);if(kind===3)return p.saveTalent(value,node);
 if(kind>=5&&kind<=7)await p.saveOpaque(kind,value,node);return 0;
}
// Whole virtual LoadGameDefinedStructure1405521d0..140552435. Unknown kinds
// return0 without touching the output pointer; known kinds own a fresh value.
export async function loadScriptEngineStructure(kind,data,p,out){
 kind=int(kind,'structure kind');const nested=(p.read??readNativeGff)(data,'GameDefinedStrct',14,null);
 if(kind<0||kind>7)return 0;if(nested.status===0)throw new Error('Native script engine structure GFF pointer is uninitialized');
 if(kind===0||kind===4){out.value=await p.createEffect(1);await p.loadEffect(out.value,nested.value);return 1;}
 out.value=await p.create(kind);
 if(kind===1)return p.loadEvent(out.value,nested.value);if(kind===2)return p.loadLocation(out.value,nested.value);if(kind===3)return p.loadTalent(out.value,nested.value);
 await p.loadOpaque(kind,out.value,nested.value);return 1;
}
