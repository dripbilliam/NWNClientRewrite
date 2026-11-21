'use strict';
const FIELDS=['HitPoints','MaxHitPoints','PregameCurrent','CurrentHitPoints'];
function snapshot(root,fieldTypes){
 const types=fieldTypes(root);
 return {values:Object.fromEntries(FIELDS.map(key=>[key,root[key]??null])),types:Object.fromEntries(FIELDS.map(key=>[key,types?.[key]??null]))};
}
function compare(expected,uploaded,exported,reconnect=false,authoritative=null){
 const valid=FIELDS.every(key=>Number.isInteger(expected?.[key])&&expected[key]>=-32768&&expected[key]<=32767);
 const exact=value=>valid&&FIELDS.every(key=>value?.values?.[key]===expected[key]&&value?.types?.[key]===3);
 const uploadExact=reconnect?uploaded===null:exact(uploaded);
 const short=value=>Number.isInteger(value)&&value>=-32768&&value<=32767;
 const received=authoritative?.currentScope===true&&authoritative?.postAdmissionRequested===true&&Number.isSafeInteger(authoritative?.connection)&&authoritative.connection>0&&Number.isSafeInteger(authoritative?.generation)&&authoritative.generation>0&&Number.isInteger(authoritative?.areaId)&&authoritative.areaId>=0&&authoritative.areaId<=0xffffffff&&Number.isInteger(authoritative?.actorId)&&authoritative.actorId>=0&&authoritative.actorId<=0xffffffff&&Number.isSafeInteger(authoritative?.actorLifetime)&&authoritative.actorLifetime>0&&short(authoritative?.current)&&short(authoritative?.maximum)&&authoritative.maximum>0&&authoritative.current<=authoritative.maximum&&authoritative.temporary===0;
 const serverExpected=received&&valid?{HitPoints:expected.HitPoints,MaxHitPoints:authoritative.maximum,PregameCurrent:authoritative.current,CurrentHitPoints:(expected.HitPoints+authoritative.current-authoritative.maximum)<<16>>16}:null;
 const exportExact=Boolean(serverExpected)&&FIELDS.every(key=>exported?.values?.[key]===serverExpected[key]&&exported?.types?.[key]===3);
 const normalization=FIELDS.filter(key=>exported?.values?.[key]!==expected?.[key]).map(field=>({field,uploaded:expected?.[field]??null,exported:exported?.values?.[field]??null}));
 return {success:valid&&uploadExact&&received&&exportExact,uploadExact,exportExact,reconnect,expected,uploaded,exported,authoritative,serverExpected,normalization,scope:'Upload matches original807950 pregame cached SHORT fields. Fresh export matches separately received canonical controlled-actor HP: source base, authoritative maximum/current and base+current−maximum save formula. This owned first-level fixture requires no temporary HP; no predicted server bonus or blanket healing.'};
}
module.exports={snapshot,compare};
