'use strict';
const exactArray=(a,b)=>Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((v,i)=>v===b[i]);
const integer=(v,a,b)=>Number.isInteger(v)&&v>=a&&v<=b;
const total=classes=>classes.reduce((n,c)=>n+c.level,0);
const classLevel=(classes,id)=>classes.find(c=>c.id===id)?.level??0;
function actorFacts(actor){
 const stats=actor?.replicated?.stats,abilities=actor?.clientAbilityCache?.base??actor?.playerState?.abilities?.base,level=actor?.playerState?.levelUp;
 const hp=actor?.replicated?.hitPoints;
 if(!actor||!integer(actor.id,0,0xffffffff)||!Array.isArray(stats?.classes)||!stats.classes.length||stats.classes.some(c=>!integer(c.id,0,255)||!integer(c.level,1,254))||!Array.isArray(abilities)||abilities.length!==6||abilities.some(v=>!integer(v,0,255))||!Array.isArray(level?.skills)||level.skills.some(v=>!integer(v,0,255))||!Array.isArray(actor.playerState.feats)||!actor.playerState.spellbooks||Array.isArray(actor.playerState.spellbooks))throw Error('Required canonical received level-up facts are incomplete');
 return {actorId:actor.id,classes:stats.classes.map(c=>({id:c.id,level:c.level})),abilities:[...abilities],skills:[...level.skills],feats:[...actor.playerState.feats],spellbooks:structuredClone(actor.playerState.spellbooks),hp:hp?{current:hp.current,maximum:hp.maximum,temporary:hp.fieldE8}:null};
}
function sourcePresentation(value){
 return Boolean(value&&Object.hasOwn(SOURCE_PANES,value.stage)&&value.sourceActive===true&&value.genericVisible===false&&value.runtimeOwns===true&&value.paneVisible===true&&value.ready===true&&value.wanted===true&&value.frontend==='res://systems/native_level_up_frontend.gd'&&integer(value.token,0,Number.MAX_SAFE_INTEGER)&&Array.isArray(value.identity)&&value.identity.length===3&&value.identity.every(v=>integer(v,0,Number.MAX_SAFE_INTEGER))&&Array.isArray(value.navigationTicket)&&value.navigationTicket.length===6&&exactArray(value.navigationTicket.slice(0,3),value.identity)&&value.navigationTicket[3]===value.token&&value.navigationTicket[5]===value.stage&&integer(value.navigationTicket[4],0,Number.MAX_SAFE_INTEGER)&&Array.isArray(value.ticket)&&value.ticket.length===8&&exactArray(value.ticket.slice(0,6),value.navigationTicket)&&value.ticket[7]===value.stage&&integer(value.ticket[6],0,Number.MAX_SAFE_INTEGER)&&value.pane===SOURCE_PANES[value.stage]);
}
const SOURCE_PANES=Object.freeze({class:'res://systems/native_level_up_class.gd',attributes:'res://systems/native_level_up_attributes.gd',skills:'res://systems/native_level_up_skills.gd',feats:'res://systems/native_level_up_feats.gd',spells:'res://systems/native_spells_chooser.gd',domains:'res://systems/native_level_up_domains.gd',school:'res://systems/native_level_up_school.gd',associate:'res://systems/native_associate_chooser.gd',summary:'res://systems/native_level_up_summary.gd'});
function finalizationWitness(value,identity,token){
 const keys=(v,names)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).every(k=>names.includes(k));
 const vector=v=>Array.isArray(v)&&v.length===6&&v.every(x=>integer(x,-128,255));
 const ids=v=>Array.isArray(v)&&v.length<=4096&&v.every(x=>integer(x,0,65535));
 const fields=['ready','scope','ticket','classes','currentClassIndex','vitals','ownedFeats','primaryFeats','ownedTypes','primaryTypes','literalInt40Membership','moduleFlags','toughnessHPBonus','summary','serverAcknowledged'];
 if(!keys(value,fields)||value.ready!==true||value.serverAcknowledged!==false||!exactArray(value.scope,[...identity,token])||!Array.isArray(value.ticket)||value.ticket.length!==6||!exactArray(value.ticket.slice(0,4),value.scope)||!integer(value.ticket[4],0,Number.MAX_SAFE_INTEGER)||value.ticket[5]!=='summary')return false;
 if(!Array.isArray(value.classes)||!value.classes.length||value.classes.length>8||!integer(value.currentClassIndex,0,value.classes.length-1)||value.classes.some(c=>!keys(c,['id','level'])||!integer(c.id,0,254)||!integer(c.level,1,255)))return false;
 if(!keys(value.vitals,['raw','racial','gains','scores','modifiers'])||!['raw','racial','gains','scores','modifiers'].every(k=>vector(value.vitals[k]))||!ids(value.ownedFeats)||!ids(value.primaryFeats))return false;
 for(const list of ['owned','primary'])if(!Array.isArray(value[list+'Types'])||value[list+'Types'].length!==value[list+'Feats'].length||value[list+'Types'].some(t=>t!==2&&t!==3))return false;
 if(!keys(value.literalInt40Membership,['owned','primary'])||!['owned','primary'].every(list=>value.literalInt40Membership[list]===value[list+'Feats'].some((id,i)=>id===40&&value[list+'Types'][i]===2)))return false;
 if(!keys(value.moduleFlags,['forceMaximum','hideHitPointGain'])||!['forceMaximum','hideHitPointGain'].every(k=>typeof value.moduleFlags[k]==='boolean')||!integer(value.toughnessHPBonus,-2147483648,2147483647))return false;
 if(!keys(value.summary,['hitDie','displayHitPointGain','hiddenHitPointGain'])||!integer(value.summary.hitDie,1,255)||!integer(value.summary.displayHitPointGain,-128,127)||typeof value.summary.hiddenHitPointGain!=='boolean')return false;
 return Buffer.byteLength(JSON.stringify(value))<=128*1024;
}
function advancement(before,after,proposal){
 if(!before||!after||!proposal||!Array.isArray(before.classes)||!Array.isArray(after.classes)||!integer(proposal.classId,0,255))return {success:false};
 const checks={sameActor:before.actorId===after.actorId,oneTotalLevel:total(after.classes)===total(before.classes)+1,class:classLevel(after.classes,proposal.classId)===classLevel(before.classes,proposal.classId)+1,otherClasses:before.classes.every(c=>c.id===proposal.classId||classLevel(after.classes,c.id)===c.level),ability:integer(proposal.ability,0,6)&&before.abilities.every((v,i)=>after.abilities[i]===v+(proposal.ability===i?1:0)),skills:Array.isArray(proposal.skills)&&proposal.skills.length===before.skills.length&&proposal.skills.every((v,i)=>integer(v,0,127)&&after.skills[i]===before.skills[i]+v),feats:Array.isArray(proposal.feats)&&proposal.feats.every(id=>after.feats.includes(id)),die:integer(proposal.hitDie,1,255)};
 return {success:Object.values(checks).every(Boolean),checks};
}
function exportedFacts(root,structType=null,fieldTypes=null){
 const typed=typeof structType==='function'&&typeof fieldTypes==='function';
 const metadata=typed?{hp:Object.fromEntries(['HitPoints','CurrentHitPoints','MaxHitPoints','PregameCurrent'].map(k=>[k,fieldTypes(root)[k]??null])),classes:(root.ClassList??[]).map(c=>({struct:structType(c),class:fieldTypes(c).Class,level:fieldTypes(c).ClassLevel,knownWords:Array.from({length:10},(_,i)=>(c['KnownList'+i]??[]).every(x=>fieldTypes(x).Spell===2)),memorizedWords:Array.from({length:10},(_,i)=>(c['MemorizedList'+i]??[]).every(x=>fieldTypes(x).Spell===2))})),skillRankBytes:(root.SkillList??[]).every(x=>fieldTypes(x).Rank===0),featWords:(root.FeatList??[]).every(x=>fieldTypes(x).Feat===2)}:null;
 return {classes:(root.ClassList??[]).map(c=>({id:c.Class,level:c.ClassLevel,domains:[c.Domain1??null,c.Domain2??null],school:c.School??null,known:Array.from({length:10},(_,i)=>(c['KnownList'+i]??[]).map(x=>x.Spell)),memorized:Array.from({length:10},(_,i)=>(c['MemorizedList'+i]??[]).map(x=>({spell:x.Spell,ready:x.Ready??null,metamagic:x.SpellMetaMagic??null})))})),abilities:['Str','Dex','Con','Int','Wis','Cha'].map(k=>root[k]),skills:(root.SkillList??[]).map(v=>v.Rank),feats:(root.FeatList??[]).map(v=>v.Feat),hp:{base:root.HitPoints,currentCache:root.CurrentHitPoints,maximum:root.MaxHitPoints,pregameCurrent:root.PregameCurrent},metadata};
}
module.exports={SOURCE_PANES,actorFacts,sourcePresentation,finalizationWitness,advancement,exportedFacts};
