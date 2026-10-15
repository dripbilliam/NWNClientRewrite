import {intEntry} from './combat_stats.js';
import {itemArmorClass} from './combat_modifiers.js';
import {canonicalItemData} from './native_item_runtime.js';
const byte=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native arcane failure ${name} is unavailable`);return v&255;};
const signed=v=>(v<<24)>>24;

// ComputeArmourClass14038843b/140388785 import cache writes; effect cache
// D78 has its own apply/remove owners and must not be reset by equipment.
export function initializeArcaneEquipmentCache(o,session){
  const rules=session.characterRules,chest=session.equipmentSlot(o,2),shield=session.equipmentSlot(o,32);
  o.nativeArcaneChestD79=0;o.nativeArcaneShieldD7a=0;
  if(chest){
    const ac=itemArmorClass({data:canonicalItemData(chest)},rules),entry=intEntry(rules.armor,ac,'ARCANEFAILURE%');
    if(!entry.found)throw new Error('Native armor arcane-failure table scratch value is unavailable');o.nativeArcaneChestD79=entry.value&255;
  }
  if(shield&&[14,56,57].includes(shield.baseItem))o.nativeArcaneShieldD7a=session.items.baseInfo(shield).arcaneSpellFailure;
}

// ExecuteCommandGetArcaneSpellFailure14051ece0. Armor+shield sum wraps BYTE
// before sign extension; then signed effect BYTE is added and capped0..100.
export function arcaneSpellFailure(o){
  if(o.nativeArcaneFailurePropertiesPending)throw new Error('Native equipped arcane spell-failure property owner is unavailable');
  const effect=signed(byte(o.nativeArcaneEffectD78,'effect cache'));
  const armor=signed((byte(o.nativeArcaneChestD79,'chest cache')+byte(o.nativeArcaneShieldD7a,'shield cache'))&255);
  return Math.max(0,Math.min(100,effect+armor));
}
