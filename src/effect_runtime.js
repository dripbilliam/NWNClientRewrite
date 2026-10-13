import { OBJECT_INVALID } from './game_object_array.js';
import { equipmentCombatEffects } from './combat_modifiers.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { effectImmunity } from './effect_immunity.js';
import { creatureRoot } from './creature_rules.js';
import { setDamageImmunity, damageImmunityTotal } from './damage_effect.js';

// Mapped Heal, CutsceneGhost and positive attack/AC/save stat effects.
// CGameEffect IDs are uint64, separate from canonical uint32 game-object IDs.
// Store them as hex strings so VM value copies preserve identity without loss.
export class EffectRuntime {
  constructor(session) { this.session = session; this.nextId = 1n; }
  create(type, creatorId = OBJECT_INVALID, integers = [], subtype = 0) {
    const id = this.nextId.toString(16).padStart(16, '0'); this.nextId = BigInt.asUintN(64, this.nextId + 1n);
    return { id, type, creatorId, integers, subtype, durationType: 0, duration: 0, spellId: -1, exposed: true };
  }
  invalid() { return this.create(0); }
  valid(effect) { return Number(Boolean(effect?.type && effect.exposed && [1, 2].includes(effect.durationType))); }
  enumerate(objectId, first = false) {
    const object = this.session.registry.get(objectId);
    if (!object) return this.invalid();
    if (object.authored?.EffectList?.length) throw new Error('Saved active effect import is not implemented');
    if (first) object.effectCursor = 0;
    const effects = object.effects ?? [];
    for (let i = object.effectCursor ?? 0; i < effects.length; i++) {
      const effect = effects[i];
      if (effect.exposed && [1, 2].includes(effect.durationType)) {
        object.effectCursor = (i + 1) & 0xffff;
        return structuredClone(effect);
      }
    }
    object.effectCursor = 0;
    return this.invalid();
  }
  apply(durationType, value, objectId, seconds = 0, context) {
    const object = this.session.registry.get(objectId);
    if (!object || !['player', 'creature', 'door', 'placeable', 'item', 'trigger', 'store', 'encounter', 'waypoint'].includes(object.kind)) return;
    if (!value?.type) return;
    if (![2, 12, 38, 39, 93, 10, 11, 13, 14, 15, 16, 17, 22, 26, 27, 48, 49, 55, 56].includes(value.type)) throw new Error(`Effect type ${value.type} is not implemented`);
    const effect = structuredClone(value);
    effect.durationType = durationType === 0 ? 0 : durationType === 1 ? 1 : 2;
    if (effect.durationType === 1) {
      if (!Number.isFinite(seconds) || seconds < 0) throw new Error('Negative/nonfinite temporary effect duration is not implemented');
      effect.duration = Math.fround(seconds);
      effect.expires = this.session.scheduler.time + Math.trunc(Math.fround(effect.duration * 1000));
    }
    if (effect.type === 38) return this.session.damage.apply(object, effect, context);
    if([55,56].includes(effect.type)) {
      // OnApplySkillIncrease/Decrease 0x1404332d0/0x140433190. These
      // handlers admit magnitude zero and retain only creature records.
      if(object.objectType!==5||this.session.isDead(object)||(effect.integers[1]|0)<0)return;
      if(effect.type===56){
        const source=this.session.registry.get(effect.creatorId);
        if(object.plot||!effect.bypassImmunity&&effectImmunity(creatureRoot(object),
          [...(object.itemCombatEffects?.effects??[]),...(object.effects??[])],27,
          source?.objectType===5?creatureRoot(source):null,{plot:Boolean(object.plot)}))return;
      }
      const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented','Skill modifier applied; native linked type-67 effect icons 43/44 are not implemented',
        {...this.session.diagnosticContext(object.id),effectId:effect.id,effectType:effect.type,creatorId:effect.creatorId});
      return;
    }
    if ([13, 14].includes(effect.type)) {
      if (this.session.isDead(object) || effect.type === 14 && object.objectType !== 5) return;
      if (effect.type === 14 && !effect.bypassImmunity) {
        const source = this.session.registry.get(effect.creatorId);
        if (effectImmunity(creatureRoot(object), [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])],
          21, source?.objectType === 5 ? creatureRoot(source) : null, { plot: Boolean(object.plot) })) return;
      }
      if (object.objectType === 5) object.combatInformationDirty = 1;
      const active = object.effects ??= [], index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Damage bonus/penalty applied; native linked effect icons are not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type });
      return;
    }
    if ([2, 12].includes(effect.type)) {
      // Native handlers retain these records without a dead/amount gate.
      const active = object.effects ??= [], index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Damage mitigation applied; native linked icon/floaty presentation is not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type });
      return;
    }
    if (effect.type === 15) {
      if (object.objectType !== 5 || this.session.isDead(object)) return;
      const state = this.session.damage.health(object);
      state.temporaryHP = ((((state.temporaryHP << 16) >> 16) + (effect.integers[0] | 0)) | 0);
      const active = object.effects ??= [], index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Temporary hit points applied; native linked icon/floaty presentation is not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type });
      return;
    }
    if (effect.type === 39) {
      // OnApplyHeal consumes the effect even if passed TEMPORARY/PERMANENT.
      if (object.objectType === 5 && this.session.isDead(object)) return;
      if (!['player', 'creature', 'door', 'placeable'].includes(object.kind)) return;
      const current = object.objectType === 5 ? (object.stats.currentHP << 16) >> 16 : this.session.hitPoints(objectId, false), maximum = this.session.hitPoints(objectId, true);
      const amount = Math.min(effect.integers[0] | 0, maximum - current);
      if (object.objectType === 5) {
        object.stats.currentHP = (current + amount) | 0;
        this.session.damage.synchronize(object);
        runtimeDiagnostics.record('combat.lifecycle-unimplemented', 'Heal applied; dying recovery, negative-level removal, native feedback and encumbrance updates are not implemented',
          { ...this.session.diagnosticContext(object.id), effectId: effect.id });
      }
      else object.currentHP = current + amount;
      this.session.onMessage({ type: 'heal', id: objectId, creatorId: effect.creatorId, amount, text: `Hit points healed: ${amount}` });
      return;
    }
    if ([16, 17].includes(effect.type)) {
      if (this.session.isDead(object) || (effect.integers[1] | 0) < 0) return;
      if (effect.type === 17) {
        if (object.plot) return;
        const source = this.session.registry.get(effect.creatorId);
        if (object.objectType === 5 && !effect.bypassImmunity && effectImmunity(creatureRoot(object),
          [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])], 22,
          source?.objectType === 5 ? creatureRoot(source) : null, { plot: Boolean(object.plot) })) return;
      }
      const active = object.effects ??= [], flags = effect.integers[0] >>> 0;
      const total = damageImmunityTotal([...(object.itemCombatEffects?.effects ?? []), ...active, effect], flags);
      setDamageImmunity(object.damageImmunityCache ??= Array(32).fill(0), flags, total);
      const index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Damage immunity applied; native linked effect icons are not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type, creatorId: effect.creatorId });
      return;
    }
    if ([10, 11, 22, 26, 27, 48, 49].includes(effect.type)) {
      if (object.objectType !== 5 || this.session.isDead(object)) return;
      if (effect.type !== 22 && (effect.integers[[48, 49].includes(effect.type) ? 1 : 0] | 0) < 1) return;
      if (!object.stats?.combat?.saves) throw new Error('Combat effect target stats are not loaded');
      if ([11, 27, 49].includes(effect.type)) {
        const source = this.session.registry.get(effect.creatorId);
        if (object.plot || !effect.bypassImmunity && effectImmunity(creatureRoot(object),
          [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])],
          { 11: 20, 27: 25, 49: 23 }[effect.type], source?.objectType === 5 ? creatureRoot(source) : null, { plot: Boolean(object.plot) })) return;
      }
      const cache = structuredClone(object.acCache ?? object.stats.combat.finalBreakdown.armor.cache);
      if ([48, 49].includes(effect.type)) {
        const [category, amount, race, law, good, damage] = effect.integers;
        const sign = effect.type === 48 ? 'up' : 'down';
        if (race === 28 && !law && !good && damage === 4103) {
          if (!category) cache[sign][0] = ((cache[sign][0] + amount) << 24) >> 24;
          else if (cache[sign][category] < amount) cache[sign][category] = (amount << 24) >> 24;
        }
      }
      const effects = object.effects ??= [];
      const index = effects.findIndex(e => e.type > effect.type);
      if (index < 0) effects.push(effect); else effects.splice(index, 0, effect);
      object.acCache = cache;
      this.session.refreshCombat(object);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Combat stat effect applied; native effect icons and feedback are not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type, creatorId: effect.creatorId });
      return;
    }
    // Native first application sets the creature's ghost flag. A duplicate is
    // consumed rather than stacked; non-creatures retain the effect, no flag.
    if (object.objectType === 5) {
      if (object.cutsceneGhost) return;
      object.cutsceneGhost = true;
    }
    const effects = object.effects ??= [];
    const index = effects.findIndex(e => e.type > effect.type);
    if (index < 0) effects.push(effect); else effects.splice(index, 0, effect);
  }
  requestRemoval(objectId, value, creatorId) {
    const object = this.session.registry.get(objectId);
    let effect;
    for (const record of object?.effects ?? []) if (record.id === value?.id) { record.exposed = false; effect = record; }
    if (!effect) return;
    // RemoveEffect hides the live record immediately; deletion is an AI event.
    // Already returned VM copies retain their previous validity flags.
    this.session.scheduler.enqueue(objectId, { type: 'removeEffect', effectId: effect.id, creatorId });
  }
  remove(objectId, effectId, context) {
    const object = this.session.registry.get(objectId), index = object?.effects?.findIndex(e => e.id === effectId) ?? -1;
    if (index < 0) return;
    if (object.effects[index].type === 15) {
      // RemoveEffectById 0x140498280 invokes OnEffectRemoved BEFORE deleting
      // the record. A nested death handler can remove it first; requery by ID.
      const effect = object.effects[index];
      return this.session.damage.removeTemporary(object, effect, context).then(() => {
        const liveIndex = object.effects.findIndex(e => e.id === effectId);
        if (liveIndex >= 0) object.effects.splice(liveIndex, 1);
      });
    }
    const [effect] = object.effects.splice(index, 1);
    if ([13, 14].includes(effect.type) && object.objectType === 5) object.combatInformationDirty = 1;
    if ([16, 17].includes(effect.type)) setDamageImmunity(object.damageImmunityCache, effect.integers[0],
      damageImmunityTotal([...(object.itemCombatEffects?.effects ?? []), ...object.effects], effect.integers[0]));
    if (effect.type === 93 && object.objectType === 5) object.cutsceneGhost = false;
    if ([10, 11, 22, 26, 27, 48, 49].includes(effect.type)) {
      if ([48, 49].includes(effect.type)) {
        const [category, amount, race, law, good, damage] = effect.integers;
        const sign = effect.type === 48 ? 'up' : 'down';
        if (race === 28 && !law && !good && damage === 4103) {
          if (!category) object.acCache[sign][0] = ((object.acCache[sign][0] - amount) << 24) >> 24;
          else {
            const items = (object.inventory ?? []).map(id => this.session.registry.get(id)).filter(i => i?.equipmentSlot)
              .map(i => ({ id: i.id, slot: i.equipmentSlot, data: i.authored }));
            const remaining = [...(object.itemCombatEffects ?? equipmentCombatEffects(items, this.session.characterRules, { root: creatureRoot(object) })).effects, ...object.effects]
              .filter(e => e.type === effect.type && e.integers[0] === category && e.integers[2] === 28 && !e.integers[3] && !e.integers[4] && e.integers[5] === 4103);
            object.acCache[sign][category] = (Math.max(0, ...remaining.map(e => e.integers[1])) << 24) >> 24;
          }
        }
      }
      this.session.refreshCombat(object);
    }
  }
  async update() {
    for (const object of this.session.registry.objects.values()) await this.updateObject(object);
  }
  async updateObject(object) {
    for (const effect of [...(object.effects ?? [])]) {
      // UpdateEffectList uses CompareWorldTimes == 1, strictly AFTER expiry.
      if (effect.durationType === 1 && this.session.scheduler.time > effect.expires) {
        const result = this.remove(object.id, effect.id);
        if (result?.then) await result;
      }
    }
  }
}
