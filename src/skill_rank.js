import { creatureRoot } from './creature_rules.js';
import { intEntry,rulesetInt } from './combat_stats.js';

// GetSkillRank 0x140406a40..0x140408058. Only native early/base-only branches
// are currently connected. Effective ranks must not silently use raw ranks;
// they also need effect bonuses, abilities, feat/race/area/armor/level inputs.
export function skillRank(object, skill, rules, baseOnly = false) {
  if (!rules.skills) throw new Error('Native skill rules are unavailable');
  skill &= 255;
  const count = (rules.skills.orderedRows?.length ?? rules.skills.rows.size) & 255;
  if (skill >= count) return 0;
  const root = creatureRoot(object);
  if (object.isDM || root.IsDM) return 127;
  const source = Array.isArray(object.stats?.skills) ? object.stats.skills[skill] ?? 0 : root.SkillList?.[skill]?.Rank ?? 0;
  const raw = (source << 24) >> 24;
  if (baseOnly) return Math.min(127, Math.max(-127, raw));
  throw new Error('Effective skill rank modifiers are not implemented');
}

const clamp=value=>Math.min(127,Math.max(-127,value|0));
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native skill ${name} is unavailable`);return v|0;};
const signedByte=v=>(integer(v,'byte')<<24)>>24;
// LoadSkillInfo 0x1402ac6f0..0x1402ad108, +20 KeyAbility, +28
// Untrained, +2c ArmorCheckPenalty. KeyAbility is case-sensitive and an
// unrecognized/empty string leaves the native initial value STR (zero).
export function skillInfo(rules,skill) {
  const table=rules.skills;if(!table)throw new Error('Native skill rules are unavailable');
  const row=table.orderedRows?table.orderedRows[skill]:table.rows.get(skill);
  const key=Object.keys(row??{}).find(name=>name.toLowerCase()==='keyability');
  const ability=({STR:0,DEX:1,CON:2,INT:3,WIS:4,CHA:5})[key===undefined?table.defaultValue:row[key]]??0;
  return{ability,untrained:intEntry(table,skill,'Untrained').value,armorCheckPenalty:intEntry(table,skill,'ArmorCheckPenalty').value};
}

// Native HasFeat checks inside GetSkillRank. These engine gates are distinct
// from chargen feat prerequisites or custom skill-table ordering.
const focus={0:[34,587],20:[404,588],1:[173,589],22:[407,590],2:[174,591],3:[175,592],4:[177,593],5:[178,594],6:[179,595],7:[180,596],8:[181,597],9:[182,598],10:[183,599],11:[184,600],12:[185,601],13:[186,602],14:[187,603],15:[188,604],16:[189,605],17:[190,606],18:[192,607],21:[406,608],19:[193,609],25:[911,913],26:[912,914],23:[915,917],24:[916,918]};
const extras={
  20:[[403,'MERCANTILE_BACKGROUND_APPRAISE_BONUS',2],[384,'SILVER_PALM_APPRAISE_BONUS',2]],
  1:[[243,'SKILL_AFFINITY_SKILL_BONUS',2]],
  5:[[387,'STEALTHY_HIDE_BONUS',2]],
  6:[[237,'SKILL_AFFINITY_SKILL_BONUS',2],[244,'PARTIAL_SKILL_FOCUS_SKILL_BONUS',1],[0,'ALERTNESS_SKILL_BONUS',2]],
  7:[[234,'SKILL_AFFINITY_SKILL_BONUS',2],[381,'COURTEOUS_MAGOCRACY_LORE_BONUS',2]],
  8:[[247,'SKILL_AFFINITY_SKILL_BONUS',2],[387,'STEALTHY_MOVE_SILENTLY_BONUS',2]],
  10:[[18,'IMPROVED_PARRY_MODIFIER',4]],11:[[378,'ARTIST_PERFORM_BONUS',2]],
  12:[[378,'ARTIST_PERSUADE_BONUS',2],[384,'SILVER_PALM_PERSUADE_BONUS',2],[385,'SMOOTH_TALK_PERSUADE_BONUS',4],[402,'THUG_PERSUADE_BONUS',2],[586,'EPIC_REPUTATION_SKILL_BONUS',4]],
  14:[[238,'SKILL_AFFINITY_SKILL_BONUS',2],[245,'PARTIAL_SKILL_FOCUS_SKILL_BONUS',1]],
  16:[[381,'COURTEOUS_MAGOCRACY_LORE_BONUS',2]],
  17:[[0,'ALERTNESS_SKILL_BONUS',2],[239,'SKILL_AFFINITY_SKILL_BONUS',2],[246,'PARTIAL_SKILL_FOCUS_SKILL_BONUS',1],[379,'BLOODED_SPOT_BONUS',2],[378,'ARTIST_SPOT_BONUS',2]],
  18:[[586,'EPIC_REPUTATION_SKILL_BONUS',4]],23:[[586,'EPIC_REPUTATION_SKILL_BONUS',4]],24:[[586,'EPIC_REPUTATION_SKILL_BONUS',4]]
};

// Full arithmetic from GetSkillRank 0x140406a40..0x140408058. Effective
// world/effect/armor/class-penalty queries stay explicit. This does not
// infer them from displayed ranks, geometric blindness or class names.
export async function effectiveSkillRank(object,skill,versus,baseOnly,rules,p) {
  if(!rules.skills)throw new Error('Native skill rules are unavailable');
  skill=integer(skill,'ID')&255;
  const count=(rules.skills.orderedRows?.length??rules.skills.rows.size)&255;
  if(skill>=count)return 0;
  for(const name of ['isDM','rawRank'])if(typeof p[name]!=='function')throw new Error(`Native skill provider ${name} is unavailable`);
  if(await p.isDM(object)!==0)return 127;
  let total=signedByte(await p.rawRank(object,skill));
  if(baseOnly!==0)return clamp(total);
  const info=skillInfo(rules,skill);
  if(info.untrained===0&&total===0)return 0;
  for(const name of ['effectBonus','abilityModifier','blind','armorPenalties','hasFeat','area','classes','classPenalties'])
    if(typeof p[name]!=='function')throw new Error(`Native skill provider ${name} is unavailable`);
  await p.preflight?.(object,skill,versus);
  const add=v=>{total=(total+integer(v,'modifier'))|0;};
  const featBonus=async(feat,label,fallback)=>{if(await p.hasFeat(object,feat)!==0)add(rulesetInt(rules,label,fallback));};
  add(await p.effectBonus(object,skill,versus));
  add(signedByte(await p.abilityModifier(object,info.ability)));
  if(info.ability<=1&&await p.blind(object)!==0)add(-rulesetInt(rules,'BLIND_PENALTY_TO_SKILL_CHECK',4));
  if(info.armorCheckPenalty===1){
    const armor=await p.armorPenalties(object);
    if(!Array.isArray(armor)||armor.length!==2)throw new Error('Native skill armor penalty caches are unavailable');
    add(signedByte((integer(armor[0],'armor penalty')+integer(armor[1],'shield penalty'))|0));
  }
  if(focus[skill]){
    await featBonus(focus[skill][0],'SKILL_FOCUS_SKILL_BONUS',3);
    await featBonus(focus[skill][1],'EPIC_SKILL_FOCUS_SKILL_BONUS',10);
  }
  for(const [feat,label,fallback] of extras[skill]??[])await featBonus(feat,label,fallback);
  if(skill===5||skill===8||skill===14){
    const area=await p.area(object);
    if(area){const flags=integer(area.flags,'area flags');
      if(skill===14){if(flags&2)await featBonus(227,'STONECUNNING_SEARCH_SKILL_BONUS',2);}
      else if(flags&4&&!(flags&3))await featBonus(201,'TRACKLESS_STEP_SKILL_BONUS',4);
    }
  }
  if(skill===7&&await p.hasFeat(object,197)!==0){
    const classes=await p.classes(object);if(!Array.isArray(classes))throw new Error('Native skill class records are unavailable');
    for(const c of classes.slice(0,classes.length&255))if([1,28].includes(integer(c.Class,'class ID')&255))add(integer(c.ClassLevel,'class level')&255);
  }
  const penalties=await p.classPenalties(object);
  if(!Array.isArray(penalties))throw new Error('Native skill class penalty records are unavailable');
  const classes=await p.classes(object);
  if(!Array.isArray(classes)||penalties.length!==(classes.length&255))throw new Error('Native skill class penalty count is unavailable');
  for(const amount of penalties)add(-(integer(amount,'class penalty')&255));
  return clamp(total);
}

// GetCanUseSkill 0x1403fa1d0. The three creature special-skill IDs
// 100..102 validate against skill 2 but class usability receives original ID.
export async function canUseSkill(object,skill,rules,p) {
  if(!rules.skills)throw new Error('Native skill rules are unavailable');
  skill=integer(skill,'ID')&255;const mapped=((skill+156)&255)<3?2:skill;
  if(mapped>=((rules.skills.orderedRows?.length??rules.skills.rows.size)&255))return 0;
  for(const name of ['isDM','baseRank','classes','classSkillUsable'])if(typeof p[name]!=='function')throw new Error(`Native skill provider ${name} is unavailable`);
  if(await p.isDM(object)!==0)return 1;
  if(skillInfo(rules,mapped).untrained===0)return Number(signedByte(await p.baseRank(object,mapped))>0);
  const classes=await p.classes(object);if(!Array.isArray(classes))throw new Error('Native skill class records are unavailable');
  for(const c of classes.slice(0,classes.length&255))if(await p.classSkillUsable(integer(c.Class,'class ID')&255,skill)!==0)return 1;
  return 0;
}
