import {nativeAssignedString,readNativeGff} from './native_gff_fields.js';
import {objectTemplateResRef} from './create_object.js';
import {scriptStringCase} from './script_string.js';
import {asNWSObject} from './native_object_cast.js';
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native resource query ${name} is unavailable`);return value|0;};
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native resource query provider ${name} is unavailable`);return p[name](...args);};
const string=value=>{if(typeof value!=='string')throw new Error('Native resource query string storage is unavailable');return nativeAssignedString(value);};

// Complete ExecuteCommandGetResRef14052fba0..52fe61, shared by582/814.
// Generic CNWSObject+30 is an owning string (stored length, including NULs).
// Areas are a separate cast; +120/+1a8 are fixed CResRefs, read as C strings.
// Module/name/tag/source keys never substitute for these live storage cells.
export async function scriptResourceReference(command,p){
 const read=call(p,'pop','object');if(!read.ok)return -639;
 const object=call(p,'object',integer(read.value,'object ID')>>>0);let value='';
 if(object){
  if((command|0)===582){
   if(call(p,'asObject',object)){
    const typed=call(p,'asObject',object);if(typed)value=string(call(p,'template',typed));
   }else if(call(p,'asArea',object))value=string(call(p,'resref',call(p,'asArea',object),0x120)).split('\0')[0];
  }else if((command|0)===814&&call(p,'asArea',object))value=string(call(p,'resref',call(p,'asArea',object),0x1a8)).split('\0')[0];
 }
 value=call(p,'lowercase',value);return call(p,'push',value)?0:-638;
}

// LoadCreature3975e0, LoadTrigger502ac0, LoadDoor4208a0, successful
// LoadEncounter43c490 and placeable/waypoint/store loaders assign their
// serialized TemplateResRef to CNWSObject+30. The constructor starts empty.
// Call only for parsed GIT/BIC records; template wrappers retain their owners.
export function importObjectTemplateReference(object,data){
 if(![5,6,7,9,10,12,13,14].includes(object.objectType))return;
 object.templateResRef=objectTemplateResRef(readNativeGff(data,'TemplateResRef',11,'').value);
}

export class ScriptResourceRuntime{
 constructor(session){this.session=session;}
 async execute(command,read){
  let result='',popError;
  const status=await scriptResourceReference(command,{pop:type=>{try{return{ok:true,value:read(type)};}catch(error){popError=error;return{ok:false};}},object:id=>this.session.registry.get(id)??null,
   asObject:asNWSObject,asArea:o=>o.objectType===4?o:null,
   template:o=>o.templateResRef,resref:(a,offset)=>objectTemplateResRef(offset===0x120?a.resRef:offset===0x1a8?a.tilesetResRef:undefined),lowercase:value=>scriptStringCase(value),push:value=>{result=value;return true;}});
  if(status!==0)throw popError??new Error(`Native resource query${command} failed (${status})`);return result;
 }
 command(command,args){let cursor=0;return this.execute(command,()=>{if(cursor>=args.length)throw new Error('Native resource query VM argument is unavailable');return args[cursor++];});}
 stack(command,vm,frame){return this.execute(command,type=>vm.pop(frame,type));}
}
