import { OBJECT_INVALID } from './game_object_array.js';
import {NativeVariableOrder} from './script_variable_order.js';

const defaults = { int: 0, float: 0, string: '', object: OBJECT_INVALID, location: null, cswy:null, json:null };
const emptyLocation=()=>({areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0]});
export function emptyLocalLocation(value){
  return value===null||value?.areaId===OBJECT_INVALID&&['position','nativeOrientation'].every(name=>Array.isArray(value[name])&&value[name].length===3&&value[name].every(n=>n===0));
}
// Native CNWSScriptVarTable has one case-sensitive name entry with independent
// typed fields. Deleting one field leaves other types under that name intact.
export class ScriptVariableTable {
  constructor({ onSetInt = () => {} } = {}) { this.entries = new Map(); this.nativeOrder=new NativeVariableOrder(); this.onSetInt = onSetInt; }
  matchIndex(name, create = false) {
    const found=this.nativeOrder.find(name);let entry=found===undefined?undefined:this.entries.get(found);
    if (!entry && create) { entry = { ...defaults };const key=this.nativeOrder.insert(name); this.entries.set(key, entry); }
    return entry;
  }
  *nativeRows(){for(const name of this.nativeOrder.names){const entry=this.entries.get(name);if(!entry)throw new Error('Native variable list/map ownership is inconsistent');yield[name,entry];}}
  copyFrom(source){
    if(source===this)return;if(!(source instanceof ScriptVariableTable))throw new Error('Native variable copy source is unavailable');
    this.entries=structuredClone(source.entries);this.nativeOrder=new NativeVariableOrder();
    this.nativeOrder.bucketCount=source.nativeOrder.bucketCount;this.nativeOrder.names=[...source.nativeOrder.names];this.nativeOrder.hashes=new Map(source.nativeOrder.hashes);
  }
  get(name, type) {
    if (!Object.hasOwn(defaults, type)) throw new Error(`Unsupported local variable type ${type}`);
    const value = this.matchIndex(name)?.[type] ?? defaults[type];
    return type === 'location' ? value ? structuredClone(value) : emptyLocation() : value;
  }
  set(name, type, value, loading=0) {
    if (!Object.hasOwn(defaults, type)) throw new Error(`Unsupported local variable type ${type}`);
    if (type === 'int') value |= 0;
    if (type === 'float') value = Math.fround(value);
    if (type === 'object') value >>>= 0;
    if (value === defaults[type] || (type === 'location' && emptyLocalLocation(value))) { this.deleteIndex(name, type); return; }
    this.matchIndex(name, true)[type] = type === 'location' ? structuredClone(value) : value;
    if (type === 'int') this.onSetInt(name, value, loading);
  }
  deleteIndex(name, type) {
    const key=this.nativeOrder.find(name),entry=key===undefined?undefined:this.entries.get(key); if (!entry) return;
    entry[type] = defaults[type];
    if (Object.keys(defaults).every(key => entry[key] === defaults[key])) {this.entries.delete(key);this.nativeOrder.remove(key);}
  }
  getInt(name) { return this.get(name, 'int'); }
  getFloat(name) { return this.get(name, 'float'); }
  getString(name) { return this.get(name, 'string'); }
  getObject(name) { return this.get(name, 'object'); }
  getLocation(name) { return this.get(name, 'location'); }
  setInt(name, value, loading=0) { this.set(name, 'int', value, loading); }
  setFloat(name, value) { this.set(name, 'float', value); }
  setString(name, value) { this.set(name, 'string', value); }
  setObject(name, value) { this.set(name, 'object', value); }
  setLocation(name, value) { this.set(name, 'location', value); }
}
