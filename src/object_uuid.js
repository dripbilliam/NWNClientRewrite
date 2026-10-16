import {OBJECT_INVALID} from './game_object_array.js';
import {nativeItemTag} from './item_stack_compare.js';
const text=value=>{nativeItemTag(value);return value.split('\0')[0];};
const eligible=new Set([4,5,6,7,9,10,12,13,14]);

// CanCarryUUID140505390/140505410. The member overload reads a BYTE from
// its parent; the static overload compares the full supplied INT.
export const canCarryUUID=type=>Number(eligible.has(type|0));

// LoadFromGff140505710..140505aa4. UUIDs belong to a persistent string map,
// not GameObjectArray's canonical ID allocator. Missing data retains old state.
export async function loadObjectUUID(state,p){
 if(canCarryUUID(state.parent.objectType&255)===0)return 0;
 const input=await p.read();
 if((input.status|0)===0||nativeItemTag(input.value).length===0)return 1;
 const key=text(input.value);
 if(await p.contains(key)){
  await p.warning(`UUID COLLISION: Tried to load and assign UUID ${key}, but UUID already in module.\n`);return 0;
 }
 if(await p.invalid(key)){
  await p.warning(`UUID: Tried to load and assign UUID ${key}, but UUID invalid.\n`);return 0;
 }
 await p.put(key,state.parent);state.value=input.value;
 return 1;
}

// TryAssign140505cc0..14050602c. As in the original, this does not erase an
// earlier key before adding a new one. Destructor erases only the current key.
export async function tryAssignObjectUUID(state,value,p){
 const key=text(value);
 if(canCarryUUID(state.parent.objectType&255)===0){
  await p.warning(`UUID: Tried to assign ${key}, but object type cannot carry UUIDs.\n`);return 0;
 }
 if(await p.contains(key)){
  await p.warning(`UUID: Tried to assign ${key}, but UUID already in module.\n`);return 0;
 }
 if(await p.invalid(key)){
  await p.warning(`UUID: Tried to assign ${key}, but not a valid UUID.\n`);return 0;
 }
 await p.put(key,state.parent);state.value=value;
 return 1;
}

// LookupObjectIdByUUID140505ab0: empty stored length returns INVALID without
// searching; an embedded NUL truncates the lookup key, not the length gate.
export function lookupObjectUUID(value,p){
 if(nativeItemTag(value).length===0)return OBJECT_INVALID;
 const object=p.find(text(value));return object?object.id>>>0:OBJECT_INVALID;
}

// Constructor140504d30 and destructor140504df0. Erase by key irrespective of
// which object the map currently contains. Native allocation frees are JS-owned.
export const initializeObjectUUID=parent=>Object.defineProperty({value:''},'parent',{value:parent});
export function destroyObjectUUID(state,p){
 if(nativeItemTag(state.value).length!==0)p.erase(text(state.value));
 state.value='';
}

// The load/assign validation is exact equality with the native UUID parse /
// standard hexadecimal format round trip (2f0590 ->2f0900 ->504960).
// Case, widths, separators, whitespace and signs therefore must be canonical.
// This predicate is the admission test, not a replacement for the general
// native UUID parser (which also accepts a compact base62 input form).
export const invalidCanonicalUUID=value=>Number(value.length!==36||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value));

export class ObjectUUIDRegistry{
 constructor({warning=()=>{},invalid=invalidCanonicalUUID}={}){this.objects=new Map();this.warning=warning;this.invalid=invalid;}
 providers(object){return{contains:key=>this.objects.has(key),put:(key,o)=>this.objects.set(key,o),invalid:this.invalid,warning:m=>this.warning(m,object)};}
 initialize(object){return object.nativeUUID=initializeObjectUUID(object);}
 load(object,read){if(!object.nativeUUID)throw new Error('Native UUID constructor state is unavailable');return loadObjectUUID(object.nativeUUID,{...this.providers(object),read});}
 tryAssign(object,value){if(!object.nativeUUID)throw new Error('Native UUID constructor state is unavailable');return tryAssignObjectUUID(object.nativeUUID,value,this.providers(object));}
 lookup(value){return lookupObjectUUID(value,{find:key=>this.objects.get(key)});}
 destroy(object){if(!object.nativeUUID)throw new Error('Native UUID destructor state is unavailable');destroyObjectUUID(object.nativeUUID,{erase:key=>this.objects.delete(key)});}
}
