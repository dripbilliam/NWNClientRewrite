'use strict';
// Local UI correlation metadata only. It does not validate gameplay authority,
// create a transaction/token/result, or serialize any original-server packet.
const FIELDS=Object.freeze(['version','owner','entry','request','generation','areaId','actorId','nativeLifetime','knownLifetime','operation','token']);
const ALLOWED=new Set(FIELDS);
const ERROR='Invalid local level-up reply scope';
const integer=(value,minimum,maximum=Number.MAX_SAFE_INTEGER)=>Number.isSafeInteger(value)&&value>=minimum&&value<=maximum;
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value));}
function scalarProperty(value,key){
 const descriptor=Object.getOwnPropertyDescriptor(value,key);
 if(!descriptor||!Object.hasOwn(descriptor,'value'))throw new TypeError(ERROR);
 return descriptor.value;
}
/**
 * Capture once from the ORIGINAL received command, before any Session call or
 * await. Spread the same echo into success and failure replies. Absence permits
 * older non-UI direct commands; a present invalid field must refuse dispatch.
 */
function captureLevelUpReplyScope(command){
 try{
  if(!plain(command))throw new TypeError(ERROR);
  const field=Object.getOwnPropertyDescriptor(command,'levelRequest');
  if(!field)return null;
  if(!Object.hasOwn(field,'value')||!plain(field.value))throw new TypeError(ERROR);
  const input=field.value,keys=Reflect.ownKeys(input);
  if(keys.length!==FIELDS.length||keys.some(key=>typeof key!=='string'||!ALLOWED.has(key)))throw new TypeError(ERROR);
  const copy={};for(const key of FIELDS)copy[key]=scalarProperty(input,key);
  if(copy.version!==1||typeof copy.owner!=='string'||!/^[\x20-\x7e]{1,128}$/.test(copy.owner)||!integer(copy.entry,0)||!integer(copy.request,1)||!integer(copy.generation,0)||!integer(copy.areaId,0,0xffffffff)||!integer(copy.actorId,0,0xffffffff)||!integer(copy.nativeLifetime,1)||!integer(copy.knownLifetime,1)||!['begin','submit','cancel'].includes(copy.operation))throw new TypeError(ERROR);
  const validToken=copy.operation==='begin'?copy.token===-1:copy.operation==='submit'?integer(copy.token,0):copy.token===-1||integer(copy.token,0);
  if(!validToken)throw new TypeError(ERROR);
  for(const key of ['operation','generation','areaId','actorId'])if(copy[key]!==scalarProperty(command,key))throw new TypeError(ERROR);
  return Object.freeze({levelRequest:Object.freeze(copy)});
 }catch{
  // Never expose malformed owner values, unknown keys, getter/proxy exceptions,
  // proposal text, credentials, or arbitrary command data in a diagnostic.
  throw new TypeError(ERROR);
 }
}
module.exports={captureLevelUpReplyScope};
