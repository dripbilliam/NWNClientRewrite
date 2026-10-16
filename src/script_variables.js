import { OBJECT_INVALID } from './game_object_array.js';

const defaults = { int: 0, float: 0, string: '', object: OBJECT_INVALID, location: null, cswy:null, json:null };
const emptyLocation=()=>({areaId:OBJECT_INVALID,position:[0,0,0],nativeOrientation:[0,0,0]});
export function emptyLocalLocation(value){
  return value===null||value?.areaId===OBJECT_INVALID&&['position','nativeOrientation'].every(name=>Array.isArray(value[name])&&value[name].length===3&&value[name].every(n=>n===0));
}
// Native CNWSScriptVarTable has one case-sensitive name entry with independent
// typed fields. Deleting one field leaves other types under that name intact.
export class ScriptVariableTable {
  constructor({ onSetInt = () => {} } = {}) { this.entries = new Map(); this.onSetInt = onSetInt; }
  matchIndex(name, create = false) {
    let entry = this.entries.get(name);
    if (!entry && create) { entry = { ...defaults }; this.entries.set(name, entry); }
    return entry;
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
    const entry = this.matchIndex(name); if (!entry) return;
    entry[type] = defaults[type];
    if (Object.keys(defaults).every(key => entry[key] === defaults[key])) this.entries.delete(name);
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
