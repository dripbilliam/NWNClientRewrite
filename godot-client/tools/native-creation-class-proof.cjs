'use strict';
// Owned CreationCheck facts only: serialized GFF metadata, not game rules.
function snapshot(root,structType,fieldTypes){
 if(!Array.isArray(root.ClassList)||root.ClassList.length!==1)throw Error('Expected one first-level source class');
 const cls=root.ClassList[0],levels=[];
 for(let level=0;level<10;level++){
  const read=prefix=>{const rows=cls[prefix+level]??[];if(!Array.isArray(rows)||rows.length>1024)throw Error('Bounded spell record list unavailable');return rows.map(row=>({spell:row.Spell,type:structType(row),fields:{...fieldTypes(row)}}));};
  levels.push({knownPresent:Object.hasOwn(cls,'KnownList'+level),memorizedPresent:Object.hasOwn(cls,'MemorizedList'+level),known:read('KnownList'),memorized:read('MemorizedList')});
 }
 return {classId:cls.Class,level:cls.ClassLevel,type:structType(cls),fields:{...fieldTypes(cls)},domains:[cls.Domain1??null,cls.Domain2??null],schoolPresent:Object.hasOwn(cls,'School'),dailyUsesPresent:Object.hasOwn(cls,'SpellsPerDayList'),familiarPresent:Object.hasOwn(root,'FamiliarType')||Object.hasOwn(root,'FamiliarName'),companionPresent:Object.hasOwn(root,'CompanionType')||Object.hasOwn(root,'CompanionName'),levels};
}
const validDomains=values=>Array.isArray(values)&&values.length===2&&values.every(id=>Number.isInteger(id)&&id>=0&&id<=255)&&values[0]!==values[1];
function verifySource(value,expected=null){
 const checks={class:value?.classId===2&&value.level===1&&value.type===0&&value.fields?.Class===5&&value.fields?.ClassLevel===3,domains:validDomains(value?.domains)&&value.fields?.Domain1===0&&value.fields?.Domain2===0,schoolOmitted:value?.schoolPresent===false,dailyUsesOmitted:value?.dailyUsesPresent===false,unusedPetsOmitted:value?.familiarPresent===false&&value?.companionPresent===false,levels:Array.isArray(value?.levels)&&value.levels.length===10};
 checks.unrestrictedKnownOmitted=checks.levels&&value.levels.every(row=>Array.isArray(row.known)&&row.known.length===0&&row.knownPresent===false);
 checks.originalUnpreparedRows=checks.levels&&value.levels.every(row=>Array.isArray(row.memorized)&&row.memorized.length<=255&&row.memorized.every(v=>v.spell===65535&&v.type===0&&JSON.stringify(v.fields)==='{"Spell":2}'));
 if(expected){
  checks.sourceContract=expected.divineCreation?.version===1&&expected.divineCreation.classId===2&&expected.divineCreation.memorizes===1&&expected.divineCreation.learnScroll===0&&expected.divineCreation.post?.PickDomains===1&&expected.divineCreation.post?.SpellbookRestricted===0;
  checks.acceptedDomains=validDomains(expected.domains)&&JSON.stringify(value?.domains)===JSON.stringify(expected.domains);
  checks.actualSlots=Array.isArray(expected.divineCreation?.slots)&&expected.divineCreation.slots.length===10&&checks.levels&&expected.divineCreation.slots.every((count,index)=>Number.isInteger(count)&&count>=0&&count<=255&&value.levels[index].memorized.length===count&&value.levels[index].memorizedPresent===(count>0));
 }
 return {success:Object.values(checks).every(Boolean),checks,scope:'Original first-level Cleric upload shape: physical class2, BYTE Domains, omitted School/daily uses/pets/restricted known book; actual source slot counts and struct0/WORDffff rows. No server-normalization assumptions.'};
}
function verifyExport(value,expected){
 const checks={class:value?.classId===expected?.classId&&value?.classId===2&&value.level===1&&value.fields?.Class===5&&value.fields?.ClassLevel===3,domains:validDomains(expected?.domains)&&JSON.stringify(value?.domains)===JSON.stringify(expected.domains)&&value.fields?.Domain1===0&&value.fields?.Domain2===0,schoolOmitted:value?.schoolPresent===false,sourceContract:expected?.divineCreation?.version===1&&expected.divineCreation.post?.PickDomains===1&&expected.divineCreation.post?.SpellbookRestricted===0,wordSpells:Array.isArray(value?.levels)&&value.levels.length===10&&value.levels.every(row=>[...row.known,...row.memorized].every(spell=>spell.fields.Spell===2))};
 return {success:Object.values(checks).every(Boolean),checks,scope:'Independent original-server saved Cleric class/domain/WORD-spell fields. Server-owned class/list structure types, readiness flags and derived unrestricted books remain its own normalization.'};
}
module.exports={snapshot,verifySource,verifyExport};
