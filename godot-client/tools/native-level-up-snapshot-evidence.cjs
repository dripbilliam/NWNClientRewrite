'use strict';
// Diagnostic-only exact NativeSession snapshot copy. Unknown fields are refused,
// never logged or silently removed from evidence presented as a complete copy.
const TOP=new Set(['actorId','classes','race','goodEvil','lawChaos','baseAbilities','feats','spellbooks','fieldDC6','skills','fieldE34','fieldE48','fieldE30','fieldE38','fieldD4','fieldC0']);
const CLASS=new Set(['id','level','school','domains']),BOOK=new Set(['known','memorized','slots','usesLeft']),MEMORY=new Set(['domain','index','level','metamagic','ready','spell']);
const integer=(v,low,high)=>Number.isInteger(v)&&v>=low&&v<=high;
function record(value,allowed){
 if(!value||typeof value!=='object'||Array.isArray(value)||![Object.prototype,null].includes(Object.getPrototypeOf(value)))throw Error('Received snapshot record shape is unavailable');
 if(Object.getOwnPropertySymbols(value).length)throw Error('Received snapshot contains an unrecognized field');
 for(const [key,descriptor]of Object.entries(Object.getOwnPropertyDescriptors(value)))if(!allowed.has(key)||!Object.hasOwn(descriptor,'value'))throw Error('Received snapshot contains an unrecognized field');
}
function array(value,maximum){
 if(!Array.isArray(value)||value.length>maximum||Object.getOwnPropertySymbols(value).length)throw Error('Received snapshot array exceeds its native evidence bound');
 const fields=Object.getOwnPropertyDescriptors(value);if(Object.keys(fields).length!==value.length+1)throw Error('Received snapshot array storage is malformed');
 for(const[key,d]of Object.entries(fields))if(key!=='length'&&(!/^(0|[1-9][0-9]*)$/.test(key)||Number(key)>=value.length||!Object.hasOwn(d,'value')))throw Error('Received snapshot contains an unrecognized array field');
}
function vector(value,maximum,low,high){array(value,maximum);if(!value.every(x=>integer(x,low,high)))throw Error('Received snapshot vector exceeds its native evidence bound');}
function levels(value,visit){record(value,new Set(Array.from({length:10},(_,i)=>String(i))));for(const row of Object.values(value))visit(row);}
function receivedSnapshot(value){
 record(value,TOP);
 array(value.classes,8);if(!integer(value.actorId,0,0xffffffff)||!value.classes.length)throw Error('Received snapshot identity/classes are unavailable');
 for(const row of value.classes){record(row,CLASS);if(!integer(row.id,0,254)||!integer(row.level,1,255))throw Error('Received snapshot class is malformed');if(Object.hasOwn(row,'school')&&!integer(row.school,0,255))throw Error('Received snapshot school is malformed');if(Object.hasOwn(row,'domains')){vector(row.domains,2,0,255);if(row.domains.length!==2)throw Error('Received snapshot domains are malformed');}}
 vector(value.baseAbilities,6,0,255);if(value.baseAbilities.length!==6)throw Error('Received snapshot ability storage is incomplete');vector(value.skills,255,-128,127);vector(value.feats,65535,0,65535);
 record(value.spellbooks,new Set(Array.from({length:8},(_,i)=>String(i))));
 for(const book of Object.values(value.spellbooks)){
  record(book,BOOK);if(Object.hasOwn(book,'known'))vector(book.known,65535,0,0xffffffff);
  if(Object.hasOwn(book,'memorized'))levels(book.memorized,list=>{array(list,255);for(const row of list){if(row===null)continue;record(row,MEMORY);for(const[key,n]of Object.entries(row))if(!integer(n,0,key==='spell'?0xffffffff:255))throw Error('Received memorized scalar is malformed');}});
  for(const key of ['slots','usesLeft'])if(Object.hasOwn(book,key))levels(book[key],n=>{if(!integer(n,0,255))throw Error('Received spell count is malformed');});
 }
 for(const key of ['race','goodEvil','lawChaos','fieldC0'])if(Object.hasOwn(value,key)&&!integer(value[key],0,255))throw Error('Received snapshot BYTE is malformed');
 for(const[key,maximum]of [['fieldDC6',65535],['fieldD4',0xffffffff]])if(Object.hasOwn(value,key)&&!integer(value[key],0,maximum))throw Error('Received snapshot counter is malformed');
 for(const key of ['fieldE34','fieldE30'])if(Object.hasOwn(value,key)&&!integer(value[key],-2147483648,2147483647))throw Error('Received snapshot associate field is malformed');
 for(const key of ['fieldE48','fieldE38'])if(Object.hasOwn(value,key)&&(typeof value[key]!=='string'||Buffer.byteLength(value[key])>2048))throw Error('Received snapshot associate name exceeds evidence bound');
 const encoded=JSON.stringify(value);if(Buffer.byteLength(encoded)>512*1024)throw Error('Received snapshot exceeds512KiB evidence bound');return JSON.parse(encoded);
}
module.exports={receivedSnapshot};
