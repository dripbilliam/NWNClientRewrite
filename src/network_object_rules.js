import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';

// Wire shape depends on the selected module/HAK's baseitems table. This owner
// reads resources only; it never constructs a singleplayer simulation.
export async function loadNetworkObjectRules(resolver){
 const [baseitems,classes,visualeffects,skills,spells,feat]=await Promise.all(['baseitems','classes','visualeffects','skills','spells','feat'].map(async name=>parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)))));
 return{
  // CNWRules::LoadSkillInfo2ac6f0 stores the physical row count as BYTE107.
  skillCount:skills.orderedRows.length&255,
  baseItemModelType:id=>{const result=intEntry(baseitems,id,'ModelType');return result.found?result.value&255:null;},
  quickbarItemInfo:id=>baseitems.orderedRows[id]?{container:intEntry(baseitems,id,'Container').value,equipableSlots:intEntry(baseitems,id,'EquipableSlots').value>>>0}:null,
  spellInputInfo:id=>Number.isInteger(id)&&id>=0&&spells.orderedRows[id]?{targetType:intEntry(spells,id,'TargetType').value&65535}:null,
  featInputInfo:id=>Number.isInteger(id)&&id>=0&&id<65536&&intEntry(feat,id,'Feat').found?{}:null,
  // InitLegacyClassDefaults2a4350 initializes Wizard10/Cleric2; LoadClassInfo
  // overwrites4f8/4f4 only on successful PickSchool/PickDomains INT lookup.
  classInfo:id=>{if(!classes.orderedRows[id])return null;const school=intEntry(classes,id,'PickSchool'),domains=intEntry(classes,id,'PickDomains');return{pickSchool:school.found?school.value!==0:id===10,pickDomains:domains.found?domains.value!==0:id===2};},
  // GetIsBeam4954f0: exact one-character Type_FD string B or P.
  isBeam:id=>{const v=nativeStringEntry(visualeffects,id,'Type_FD');return v.value==='B'||v.value==='P';},
 };
}
