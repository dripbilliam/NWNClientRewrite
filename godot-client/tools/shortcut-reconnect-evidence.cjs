const {integrationComplete}=require('./integration-evidence.cjs');
const definitions={0:[42,22],12:[3,4],28:[3,22],29:[3,10],33:[2,100],34:[1,null],35:[1,null]};
function bindingsMatch(rows,saved=false){
 return Array.isArray(rows)&&rows.length===36&&Object.entries(definitions).every(([index,[type,param]])=>{const b=rows[index];return b&&(saved?b.QBObjectType:b.type)===type&&(param===null||(saved?b.QBINTParam1:b.intParam)===param);})&&[31,32].every(i=>(saved?rows[i].QBObjectType:rows[i].type)===0);
}
function shortcutPhaseComplete(report,p){
 const t=p?.test,restored=Boolean(t?.restored),requests=report.actionRequests?.filter(v=>v.connection===p.connection)??[];
 if(!t?.completed||!Array.isArray(t.checks)||t.checks.length<(restored?15:21)||!t.checks.every(v=>v.passed)||!bindingsMatch(p.bindings)||!Object.keys(definitions).every(i=>t.rows?.[i]&&!t.rows[i].empty))return false;
 const potion=p.items?.find(v=>v.index===34),armor=p.items?.find(v=>v.index===35),o=t.observations;
 return Boolean(potion&&armor&&potion.id===p.bindings[34].itemId&&armor.id===p.bindings[35].itemId&&potion.location?.channel==='R'&&armor.location?.channel==='I'&&armor.location.slot===2&&[potion,armor].every(v=>v.location.ownerId===p.actorId)&&(p.bindings[34].intParam&255)===0&&(p.bindings[34].intParam>>>16&255)===255&&p.bindings[35].intParam===0xff00ff&&o?.before?.potion===o?.after?.potion+1&&o.before.light===o.after.light+1&&o.after.potion===potion.stack&&p.lightUses===o.after.light&&p.serverStartLight===o.before.light&&(!restored||JSON.stringify(o.keyboardSlots)===JSON.stringify([35,35,34,33,28]))&&requests.some(v=>v.operation==='useItem'&&v.itemId===potion.id&&v.propertyIndex===0&&v.variant===255)&&requests.some(v=>v.operation==='castSpell'&&v.spellId===100&&v.beforeUses===o.before.light)&&requests.some(v=>v.operation==='useSkill'&&v.packedSkill===22&&v.targetId===p.actorId)&&['dialog-entry','dialog-replies','dialog-close'].every(kind=>report.skillDialogs?.some(v=>v.connection===p.connection&&v.kind===kind))&&['equip','unequip'].every(operation=>report.inventoryResults?.some(v=>v.connection===p.connection&&v.itemId===armor.id&&v.operation===operation&&v.success)));
}
function shortcutReconnectComplete(report){
 const phases=report.shortcutPhases??[],saves=report.characterSaves??[],exports=report.shortcutExports??[];
 if(!integrationComplete('text',report)||phases.length!==2||phases[0].test.restored||!phases[1].test.restored||phases[0].connection===phases[1].connection||!phases.every(p=>shortcutPhaseComplete(report,p))||report.rejectedCommands?.length||saves.length<3||new Set(saves.map(v=>v.id)).size!==1||exports.length<3)return false;
 const [first,last]=phases;
 if(first.test.observations.after.potion!==last.test.observations.before.potion||!report.characterReads?.some(v=>v.connection===last.connection&&v.source==='vault'&&v.sha256===saves[1].sha256))return false;
 if(!phases.every(p=>report.shortcutPreparedUpdates?.find(v=>v.connection===p.connection)?.changes.filter(v=>v.ready).length===p.serverStartLight))return false;
 return exports.every(e=>{
  const potion=phases.find(p=>p.connection===e.connection)?.items.find(v=>v.index===34);
  return Array.isArray(e.lightPrepared)&&e.lightPrepared.filter(Boolean).length===phases.find(p=>p.connection===e.connection)?.lightUses&&bindingsMatch(e.rows,true)&&saves.some(s=>s.connection===e.connection&&s.sha256===e.sha256)&&e.rows[33].QBMultiClass===0&&e.rows[33].QBMetaType===0&&e.rows[33].QBDomainLevel===0&&e.rows[34].QBCastPropIndex===0&&e.rows[34].QBCastSubPropIdx===255&&e.rows[34].QBItemInvSlot===0xffffffff&&e.rows[34].QBItemReposX===potion?.location.x&&e.rows[34].QBItemReposY===potion?.location.y&&e.rows[35].QBCastPropIndex===255&&e.rows[35].QBCastSubPropIdx===255&&e.rows[35].QBItemInvSlot===2&&[34,35].every(index=>['QBItemReposX','QBItemReposY'].every(k=>Number.isInteger(e.rows[index][k])));
 });
}
module.exports={shortcutReconnectComplete,shortcutPhaseComplete,bindingsMatch};
