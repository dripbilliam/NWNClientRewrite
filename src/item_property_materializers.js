import {OBJECT_INVALID} from './game_object_array.js';
import {applyBonusSpellOfLevel} from './bonus_spell_slots.js';
export function materializeBonusSpellSlots(item,property,owner,slot,loading,p){return applyBonusSpellOfLevel(item,property,owner,slot,loading,p.bonusSlots(owner));}
const hand=slot=>({16:1,32:2,16384:3,32768:4,65536:5,8:7})[slot>>>0];
const equipped=(effect,type)=>{effect.type=type;effect.durationType=(effect.durationType&0xfff8)|3;};
const condition=(effect,property,alignment,race,specific)=>{
 const type=property.type&65535,subtype=property.subtype&65535;
 if(type===alignment){if(subtype>=1&&subtype<=3)effect.integers[3]=subtype;else if(subtype===4||subtype===5)effect.integers[4]=subtype;}
 else if(type===race)effect.integers[2]=subtype;
 else if(type===specific&&subtype<=8){effect.integers[3]=[2,1,3][Math.trunc(subtype/3)];effect.integers[4]=[4,1,5][subtype%3];}
};
const field=(entry)=>{if(!Number.isInteger(entry?.value))throw new Error('Native item-property materializer table INT is unavailable');return entry.value|0;};
const base=async(item,p)=>{const info=await p.base(item);if(!info||!Number.isInteger(info.weaponWield))throw new Error('Native item-property materializer base storage is unavailable');return info;};

// ApplyACBonus14046d9b0..14046dca9. Armor category is the base item's
// AC_Enchant BYTE; vs-damage properties replace the default4103 flags.
export async function materializeArmor(item,property,owner,_slot,loading,p){
 const effect=p.create(0,OBJECT_INVALID,[]),value=field(await p.int(await p.cost(2),property.costValue&65535,'Value'));if(value===0)return 0;
 equipped(effect,48);p.creator(effect,item.id);const info=await p.base(item);
 if(!Number.isInteger(info?.acEnchant))throw new Error('Native item-property AC_Enchant BYTE is unavailable');
 effect.integers[0]=info.acEnchant&255;effect.integers[1]=value;effect.integers[5]=4103;effect.integers[2]=28;
 condition(effect,property,2,4,5);
 if((property.type&65535)===3&&(property.subtype&65535)<=2)effect.integers[5]=[1,2,4][property.subtype&65535];
 await p.apply(owner,effect,loading|0,0);return 0;
}

// ApplyLight140472270..1404723c6. Color is Param1Value BYTE; intensity
// is CostValue WORD1..4. This owner passes loading to BOTH ApplyEffect flags.
export async function materializeLight(item,property,owner,_slot,loading,p){
 if(await p.has(item,44,0)===0)return 0;
 const color=property.param1Value&255,intensity=property.costValue&65535;
 if(color>6||intensity<1||intensity>4)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,54);p.creator(effect,item.id);
 effect.integers[0]=[153,157,161,165,177,169,173][color]+intensity-1;
 await p.apply(owner,effect,loading|0,loading|0);return 0;
}

// ApplyEnhancementBonus14046fee0..14047077d: two effects, distinct copy
// operations, double-weapon ordering and direct IPRP_MeleeCost ownership.
export async function materializeEnhancement(item,property,owner,slot,loading,p){
 await p.base(item);
 const attack=p.create(0,OBJECT_INVALID,[]),table=await p.melee();let value=field(await p.int(table,property.costValue&65535,'Value'));
 if(value===0)return 0;
 equipped(attack,10);p.creator(attack,item.id);attack.integers[0]=value;
 const selected=hand(slot);if(selected===undefined){await p.warning('attackSlot');p.release(attack);return 0;}
 attack.integers[1]=selected;attack.integers[2]=28;condition(attack,property,7,8,9);
 if(((await base(item,p)).weaponWield&255)===8){const off=p.copy(attack,'assign');off.integers[1]=2;await p.apply(owner,off,loading|0,0);}
 const damage=p.copy(attack,'constructor');await p.apply(owner,attack,loading|0,0);
 equipped(damage,13);p.creator(damage,item.id);damage.integers[5]=selected;
 if(value>5){
  const costs=await p.cost(4);
  if(costs)for(let i=0;i<p.count(costs);i++){
   const dice=field(await p.int(costs,i,'NumDice')),die=field(await p.int(costs,i,'Die'));
   if(dice===0&&die===value){value=i;break;}
  }
 }
 damage.integers[0]=value;damage.integers[1]=(await p.damageFlags(item))|0;damage.integers[2]=28;condition(damage,property,7,8,9);
 if(((await base(item,p)).weaponWield&255)===8){const off=p.copy(damage,'assign');off.integers[5]=2;await p.apply(owner,off,loading|0,0);}
 await p.apply(owner,damage,loading|0,0);return 0;
}

// ApplyDamageBonus14046ece0..14046f0aa. Ammunition admission precedes
// construction; a zero cost consumes a constructor ID but applies no effect.
export async function materializeDamage(item,property,owner,slot,loading,p){
 const id=item.baseItem>>>0;if(id<=27&&(0x0a100000>>>id&1)!==0)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]),value=property.costValue&65535;if(value===0)return 0;
 equipped(effect,13);p.creator(effect,item.id);effect.integers[0]=value;
 let damage=(property.type&65535)===16?property.subtype&65535:property.param1Value&255;if(damage>2)damage-=2;
 effect.integers[1]=1<<(damage&31);
 const selected=hand(slot);if(selected===undefined){await p.warning('damageSlot');p.release(effect);return 0;}
 effect.integers[5]=selected;effect.integers[2]=28;condition(effect,property,17,18,19);
 if(((await base(item,p)).weaponWield&255)===8){const off=p.copy(effect,'assign');off.integers[5]=2;await p.apply(owner,off,loading|0,0);}
 await p.apply(owner,effect,loading|0,0);return 0;
}

// ApplyAbilityBonus14046dcd0..14046de6d. Out-of-range WORD selectors leave
// the constructor's zero selector; table lookup status does not gate Value.
export async function materializeAbility(item,property,owner,_slot,loading,p){
 const value=field(await p.int(await p.cost(1),property.costValue&65535,'Value'));if(value===0)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,36);p.creator(effect,item.id);
 const ability=property.subtype&65535;if(ability<=5)effect.integers[0]=ability;
 effect.integers[1]=value;await p.apply(owner,effect,loading|0,0);return 0;
}
// ApplyRegeneration1404725f0. The property WORD is the amount itself,
// capped at20; no cost-table lookup. Zero still consumes a constructor ID.
export async function materializeRegeneration(item,property,owner,_slot,loading,p){
 const effect=p.create(0,OBJECT_INVALID,[]),amount=property.costValue&65535;if(amount===0)return 0;
 p.creator(effect,item.id);equipped(effect,7);effect.integers[0]=Math.min(amount,20);effect.integers[1]=6000;
 await p.apply(owner,effect,loading|0,0);return 0;
}

// ApplyFreeAction140470c90..140470eff. Four independent equipped immunity
// effects, each with its own constructor ID and item creator. Both lower
// ApplyEffect flags receive the RAW loading flag (not a boolean).
export async function materializeFreeAction(item,_property,owner,_slot,loading,p){
 for(const immunity of [6,9,10,24]){
  const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,22);p.creator(effect,item.id);
  effect.integers[0]=immunity;effect.integers[1]=28;await p.apply(owner,effect,loading|0,loading|0);
 }
 return 0;
}

// ApplySkillBonus1404726d0. Zero returns BEFORE effect construction; cost
// WORD is the bonus itself. Selector and racial selector keep native widths.
export async function materializeSkill(item,property,owner,_slot,loading,p){
 const amount=property.costValue&65535;if(amount===0)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,55);p.creator(effect,item.id);
 effect.integers[0]=property.subtype&65535;effect.integers[1]=amount;effect.integers[2]=28;
 await p.apply(owner,effect,loading|0,0);return 0;
}

// ApplyDamageReduction14046f540 / ApplyDamageResistance14046f6a0.
// Both construct even for zero/failed cost lookup and pass the lower Amount
// output. The native WORD selector arithmetic differs between the two owners.
export async function materializeMitigation(item,property,owner,_slot,loading,p){
 const reduction=(property.type&65535)===22,effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,reduction?12:2);p.creator(effect,item.id);
 const amount=field(await p.int(await p.cost(reduction?6:7),property.costValue&65535,'Amount')),selector=property.subtype&65535;
 if(reduction){effect.integers[0]=amount;effect.integers[1]=selector+1;}
 else{effect.integers[0]=1<<((selector>2?selector-2:selector)&31);effect.integers[1]=amount;}
 await p.apply(owner,effect,loading|0,0);return 0;
}

// DarkVision14046f980, TrueSeeing140472cb0, ImprovedEvasion140471e80.
// Darkvision/evasion set Integer0 BEFORE creator; true seeing has no integers.
export async function materializeVision(item,property,owner,_slot,loading,p){
 const type=property.type&65535,[effectType,selector]=new Map([[26,[69,2]],[71,[72,null]],[38,[83,212]]]).get(type);
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,effectType);
 if(selector!==null)effect.integers[0]=selector;
 p.creator(effect,item.id);await p.apply(owner,effect,loading|0,0);return 0;
}

// ApplyImmunity140471c70. The subtype switch is the native property enum,
// not a list of spells/forms. Subtype1 makes a copy-constructor0 child BEFORE
// applying the first effect, so both immunity records share its uint64 ID.
export async function materializeImmunity(item,property,owner,_slot,loading,p){
 const subtype=property.subtype&65535;if(subtype>9)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,22);
 effect.integers[0]=[30,29,1,2,3,4,28,6,31,32][subtype];effect.integers[1]=28;p.creator(effect,item.id);
 const child=subtype===1?p.copy(effect,'constructor'):null;
 await p.apply(owner,effect,loading|0,loading|0);
 if(child){equipped(child,22);child.integers[0]=19;child.integers[1]=28;p.creator(child,item.id);await p.apply(owner,child,loading|0,loading|0);}
 return 0;
}

// ApplyBonusFeat14046e6d0. Native stats-null and failed FeatIndex queries
// return before construction. This is active IPRP_FEATS physical row lookup.
export async function materializeBonusFeat(item,property,owner,_slot,loading,p){
 if(!p.hasStats(owner))return 0;
 const entry=await p.int(await p.feats(),property.subtype&65535,'FeatIndex');if(entry.status===0)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,83);effect.integers[0]=field(entry);p.creator(effect,item.id);
 await p.apply(owner,effect,loading|0,loading|0);return 0;
}

// SpellImmunityLevel140472900/School1404729f0/Specific140472b60.
// Specific uses the property CostTable BYTE and CostValue WORD, not subtype;
// failed SpellIndex conversion still supplies the lower output to the effect.
export async function materializeSpellImmunity(item,property,owner,_slot,loading,p){
 const type=property.type&65535,selector=property.subtype&65535;let spell=0;
 if(type===54&&selector>7)return 0;
 if(type===53){const table=await p.cost(property.costTable&255);if(!table)return 0;spell=field(await p.int(table,property.costValue&65535,'SpellIndex'));}
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,type===53?50:65);p.creator(effect,item.id);
 if(type===53)effect.integers[0]=spell;
 else{effect.integers[0]=type===78?property.costValue&65535:9;effect.integers[1]=-1;effect.integers[2]=type===54?selector+1:0;effect.integers[3]=1;}
 await p.apply(owner,effect,loading|0,loading|0);return 0;
}

// DamageImmunity14046f0b0 / Vulnerability14046f810. The former queries
// before allocating and rejects mapped WORD indices>=32 after the query; the
// latter allocates first and always uses the CPU's masked shift count.
export async function materializeDamagePercent(item,property,owner,_slot,loading,p){
 const decrease=(property.type&65535)===24,selector=property.subtype&65535,mapped=(selector>2?selector-2:selector)&65535;
 let effect=null;if(decrease){effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,17);p.creator(effect,item.id);}
 const table=await p.cost(decrease?22:property.costTable&255);if(!decrease&&!table)return 0;
 const amount=field(await p.int(table,property.costValue&65535,'Value'));if(!decrease&&mapped>=32)return 0;
 if(!decrease){effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,16);}
 effect.integers[0]=1<<(mapped&31);effect.integers[1]=amount;if(!decrease)p.creator(effect,item.id);
 await p.apply(owner,effect,loading|0,decrease?0:loading|0);return 0;
}

// ImprovedSpellResistance140472130: active cost11/Value is queried before
// construction, zero consumes no ID; status alone does not reject the output.
export async function materializeSpellResistance(item,property,owner,_slot,loading,p){
 const value=field(await p.int(await p.cost(11),property.costValue&65535,'Value'));if(value===0)return 0;
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,33);p.creator(effect,item.id);effect.integers[0]=value;
 await p.apply(owner,effect,loading|0,0);return 0;
}

// ApplyAttackBonus14046dfe0. Construct before Value lookup, then use active
// melee costs. Unlike enhancement, this owner performs its base query only
// AFTER slot/condition setup, makes a double-weapon offhand copy and no damage.
export async function materializeAttack(item,property,owner,slot,loading,p){
 const effect=p.create(0,OBJECT_INVALID,[]),value=field(await p.int(await p.melee(),property.costValue&65535,'Value'));if(value===0)return 0;
 equipped(effect,10);p.creator(effect,item.id);effect.integers[0]=value;
 const selected=hand(slot);if(selected===undefined){await p.warning('attackSlot');p.release(effect);return 0;}
 effect.integers[1]=selected;effect.integers[2]=28;condition(effect,property,57,58,59);
 if(((await base(item,p)).weaponWield&255)===8){const off=p.copy(effect,'assign');off.integers[1]=2;await p.apply(owner,off,loading|0,0);}
 await p.apply(owner,effect,loading|0,0);return 0;
}

// Complete ApplyChangedSavingThrowVsX14046e9f0. Physical IPRP_SaveElement
// SavingThrowType takes precedence on successful read. Native fallback switch
// holes/out-of-range selectors leave constructor Integer2 zero, not an error.
export async function materializeChangedSave(item,amount,property,owner,loading,p){
 amount|=0;const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,amount<0?27:26);p.creator(effect,item.id);
 effect.integers[0]=((amount^(amount>>31))-(amount>>31))|0;effect.integers[1]=0;effect.integers[3]=28;
 const selector=property.subtype&65535,table=await p.saveElements(),entry=table?await p.int(table,selector,'SavingThrowType'):null;
 if(entry&&entry.status!==0)effect.integers[2]=field(entry);
 else{const fallback=new Map([[0,0],[1,6],[3,12],[4,11],[5,3],[6,13],[7,8],[8,4],[9,7],[11,1],[12,10],[13,2],[14,9],[15,5],[16,14],[17,15],[18,18],[19,19],[20,16],[21,17]]);if(fallback.has(selector))effect.integers[2]=fallback.get(selector);}
 await p.apply(owner,effect,loading|0,0);return 0;
}
// ApplyImprovedSavingThrowVsX140472030. Cost1 queried even for zero; the
// helper is entered only for a nonzero output, including negative/failed reads.
export async function materializeSave(item,property,owner,_slot,loading,p){
 const value=field(await p.int(await p.cost(1),property.costValue&65535,'Value'));
 if(value!==0)await materializeChangedSave(item,value,property,owner,loading,p);return 0;
}
// ApplyTurnResistance140472d50, raw property WORD (no cost lookup).
export async function materializeTurnResistance(item,property,owner,_slot,loading,p){
 const effect=p.create(0,OBJECT_INVALID,[]);equipped(effect,77);p.creator(effect,item.id);effect.integers[0]=property.costValue&65535;
 await p.apply(owner,effect,loading|0,0);return 0;
}

// Native item-property enum -> concrete shared handler. Authored 2DA/UTI
// data chooses properties; this table does not encode spells or form IDs.
export const itemPropertyMaterializers=new Map([
 [[0],materializeAbility],[[1,2,3,4,5],materializeArmor],[[6,7,8,9],materializeEnhancement],[[12],materializeBonusFeat],[[13],materializeBonusSpellSlots],
 [[16,17,18,19],materializeDamage],[[20,24],materializeDamagePercent],[[22,23],materializeMitigation],[[26,38,71],materializeVision],
 [[37],materializeImmunity],[[39],materializeSpellResistance],[[40],materializeSave],[[44],materializeLight],[[51],materializeRegeneration],[[52],materializeSkill],[[53,54,78],materializeSpellImmunity],[[56,57,58,59],materializeAttack],[[73],materializeTurnResistance],[[75],materializeFreeAction]
].flatMap(([ids,fn])=>ids.map(id=>[id,fn])));

// CNWSItem ApplyItemProperties140464d50 and RemoveItemProperties14046b3e0.
// The bound is re-read after every callback, retaining live pool traversal.
export async function applyEquippedPropertyList(item,owner,slot,loading,p){
 const ai=await p.ai();if(!ai)return;
 let count=p.count(item);for(let i=0;i<count;i++){
  const property=i<0||i>=count?null:p.property(item,i);await p.apply(ai,item,property,owner,slot>>>0,loading|0);count=p.count(item);
 }
}
export async function removeEquippedPropertyList(item,owner,slot,p){
 const ai=await p.ai();if(ai){let count=p.count(item);for(let i=0;i<count;i++){
  const property=i<0||i>=count?null:p.property(item,i);await p.remove(ai,item,property,owner,slot>>>0);count=p.count(item);
 }}
 await p.removeCreator(owner,item.id);
}
