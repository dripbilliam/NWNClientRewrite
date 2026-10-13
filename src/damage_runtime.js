import { OBJECT_INVALID } from './game_object_array.js';
import { creatureLifeState, doCreatureDamageAsync } from './creature_damage.js';
import { damageAfterImmunity, damageImmunityByFlags, highestDamageTypeFlag } from './damage_effect.js';
import { damageResistance, damageReduction } from './damage_mitigation.js';
import { creatureRoot } from './creature_rules.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { decrementRoundLength, weaponAttackType } from './combat_round.js';
import { abilityModifier, rulesetInt } from './combat_stats.js';
import { damageEffectBonusAsync } from './damage_effect_bonus.js';
import { addAttackDamage } from './attack_damage.js';
import { setRoundPaused, setPauseTimer, checkActionLength } from './combat_timing.js';
import { setLastHostileActor } from './combat_hostile.js';
import { damageRollAsync, damageDifficulty } from './damage_roll.js';
import { attackDamageFlags, weaponPower, calculateDamagePower } from './damage_weapon.js';
import { creatureAlignment } from './creature_rules.js';
import { broadcastCombatState } from './combat_broadcast.js';

const i16 = n => (n << 16) >> 16;
const i8 = n => (n << 24) >> 24;

// Local authority only. These events are internal records, NOT NWN packets.
// Missing surrounding systems remain diagnosed; this is not a complete
// implementation of OnApplyDamage/Death or the attack-action scheduler.
export class DamageRuntime {
  constructor(session) { this.session = session; }
  omission(object, behavior, effect) {
    runtimeDiagnostics.record('combat.lifecycle-unimplemented', behavior,
      { ...this.session.diagnosticContext(object.id), effectId: effect?.id, creatorId: effect?.creatorId });
  }
  health(object) {
    const stats = this.session.creatureStats(object.id);
    stats.temporaryHP ??= 0;
    // Accessors retain ONE live base and temporary HP source, including changes
    // made by recursively executed removal/death scripts. No state snapshots.
    return {
      get baseHP() { return stats.currentHP; }, set baseHP(n) { stats.currentHP = n | 0; },
      get temporaryHP() { return stats.temporaryHP; }, set temporaryHP(n) { stats.temporaryHP = n | 0; }
    };
  }
  synchronize(object) {
    if (object.creatureData) object.creatureData.CurrentHitPoints = i16(object.stats.currentHP);
  }
  async operations(object, plan) {
    for (const operation of plan.operations) {
      if (operation.type === 'effectInteger') {
        const effect = object.effects?.find(e => e.id === operation.effectId);
        if (!effect) throw new Error('Damage budget references a missing live effect handle');
        effect.integers[operation.index] = operation.value;
      } else if (operation.type === 'removeEffect') {
        if (operation.immediate !== true) throw new Error('Damage requires immediate effect removal');
        await this.session.effects.remove(object.id, operation.effectId);
      } else if (operation.type === 'feedback') {
        this.session.onMessage({ ...operation, type: 'combatFeedback', id: object.id,
          text: `Damage absorbed: ${operation.amount}` });
        this.omission(object, 'Native combat feedback packet routing and overhead presentation are not implemented');
      } else throw new Error(`Unknown damage operation ${operation.type}`);
    }
    return plan.amount;
  }
  async mitigate(object, attacker, amount, flags, power, bypassImmunity) {
    if (!bypassImmunity) amount = damageAfterImmunity(amount,
      damageImmunityByFlags(flags, object.damageImmunityCache ?? Array(32).fill(0), object.stats?.feats));
    const options = { attacker, combat: 0, simulation: 0, ranged: 0, baseWeapon: 0 };
    const effects = () => [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])];
    amount = await this.operations(object, damageResistance(object, effects(), this.session.characterRules, amount, flags, options));
    if (power !== 6) amount = await this.operations(object, damageReduction(object, effects(), this.session.characterRules, amount, power, options));
    return amount;
  }
  async effectBonus(object, target, attack, options = {}) {
    // Caller owns the current attack record. This resolves effect components;
    // it neither schedules a strike nor subtracts HP or publishes a packet.
    if (options.energy && (!(Array.isArray(attack.damage) || attack.damage instanceof Int16Array) || attack.damage.length !== 32))
      throw new Error('Native attack damage record is unavailable');
    const rules = this.session.characterRules;
    const items = (object.inventory ?? []).map(id => this.session.registry.get(id)).filter(item => item?.equipmentSlot)
      .map(item => ({ id: item.id, slot: item.equipmentSlot, data: item.authored, temporaryProperties: item.temporaryProperties }));
    const effects = object => [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])];
    const result = await damageEffectBonusAsync(object, target, rules, items, this.session.random, {
      ...options, attack, limit: options.limit ?? this.session.combatLimits?.damage ?? 100,
      effects: effects(object),
      immunity: (amount, flags) => damageAfterImmunity(amount,
        damageImmunityByFlags(flags, target.damageImmunityCache ?? Array(32).fill(0), target.stats?.feats)),
      resistance: (amount, flags, context) => this.operations(target,
        damageResistance(target, effects(target), rules, amount, flags, { attacker: object, ...context })),
      addDamage: (flags, amount) => addAttackDamage(attack, flags, amount)
    });
    for (const warning of result.selection.warnings) runtimeDiagnostics.record(warning.code, warning.reason,
      { ...this.session.diagnosticContext(object.id), ...warning });
    return result;
  }
  async roll(object, target, attack, options) {
    const session = this.session, rules = session.characterRules, items = session.equippedItems(object);
    const effects = actor => [...(actor.itemCombatEffects?.effects ?? []), ...(actor.effects ?? [])];
    const result = await damageRollAsync(object,target,rules,items,session.random,{
      weaponAttackType:()=>weaponAttackType(object.combatRound,items,session.random),
      ...options, attack, difficulty:damageDifficulty(object,target,option=>session.getDifficultyOption(option)),
      effectBonus:async context=>(await this.effectBonus(object,target,attack,context)).total,
      damageFlags:()=>{
        const profile = attackDamageFlags(items,rules,attack,{resolvedHand:attack.weaponAttackType===0?weaponAttackType(object.combatRound,items,session.random):undefined});
        for (const warning of profile.warnings) runtimeDiagnostics.record(warning.code,warning.reason,{...session.diagnosticContext(object.id),...warning});
        return profile.flags;
      },
      damagePower:({offhand})=>calculateDamagePower(object,items,rules,attack,
        weaponPower(effects(object),attack.weaponAttackType,offhand,target?.objectType===5?creatureAlignment(creatureRoot(target)):null,session.combatLimits?.attack??20)),
      immunity:(amount,flags)=>damageAfterImmunity(amount,damageImmunityByFlags(flags,target.damageImmunityCache??Array(32).fill(0),target.stats?.feats)),
      resistance:(amount,flags,context)=>this.operations(target,damageResistance(target,effects(target),rules,amount,flags,{attacker:object,...context,combat:Number(context.combat),simulation:Number(context.simulation),baseWeapon:Number(context.baseWeapon)})),
      reduction:(amount,power,context)=>this.operations(target,damageReduction(target,effects(target),rules,amount,power,{attacker:object,...context,combat:Number(context.combat),simulation:Number(context.simulation)}))
    });
    return result.amount;
  }
  async subtract(object, amount, context) {
    const state = this.health(object);
    const result = await doCreatureDamageAsync(state, amount, {
      getTemporaryEffects: () => (object.effects ?? []).filter(e => e.type === 15),
      removeEffectImmediate: id => this.session.effects.remove(object.id, id, context),
      getDifficulty: option => this.session.getDifficultyOption(option),
      getLifeFlags: () => ({ isPC: object.isPC, possessedFamiliar: object.isPossessedFamiliar,
        immortal: object.immortal ?? creatureRoot(object)?.IsImmortal ?? 0 })
    });
    this.synchronize(object);
    return result;
  }
  async runEvent(object, name, context) {
    if (!name) return;
    try {
      await this.session.vm.run(await this.session.program(name), object.id,
        context ? { budget: context.budget, depth: (context.depth ?? 0) + 1 } : {});
    } catch (error) {
      // RunEventScript failure does not skip the remaining native damage work.
      this.session.report(error, { ...this.session.diagnosticContext(object.id), script: name });
    }
  }
  initiative(object) {
    if (object.initiativePending !== 1) return;
    const roll = this.session.random.dice(1, 20), rules = this.session.characterRules;
    let modifier = abilityModifier(object.stats.equippedAbilities.Dex, rules);
    const has = feat => object.stats.feats.includes(feat);
    if (has(753)) modifier += rulesetInt(rules, 'EPIC_SUPERIOR_INITIATIVE_BONUS', 8);
    else if (has(377)) modifier += rulesetInt(rules, 'IMPROVED_INITIATIVE_BONUS', 4);
    if (has(379)) modifier += rulesetInt(rules, 'BLOODED_INITIATIVE_BONUS', 2);
    if (has(402)) modifier += rulesetInt(rules, 'THUG_INITIATIVE_BONUS', 2);
    object.initiativeRoll = i8(modifier + roll); object.initiativePending = 0;
    if (object.isPC) this.session.onMessage({ type: 'initiative', id: object.id, roll, modifier,
      text: `Initiative: ${roll} + ${modifier}` });
  }
  reaction(object, effect) {
    const values = effect.integers, round = object.combatRound, length = values[33] | 0;
    if (values[32] !== 0 || (object.animationState ?? 0) > 1 || !round) return;
    // CheckActionLength 0x140375430, SetPauseTimer and DecrementRoundLength.
    if (!checkActionLength(round, effect.creatorId, length)) return;
    setRoundPaused(round, 1, effect.creatorId);
    setPauseTimer(round, length, 0);
    decrementRoundLength(round, length);
    if (values[36] !== 0) object.animationState = 14;
    else {
      if (typeof object.modelType !== 'string') {
        this.omission(object, 'Native damage-reaction MODELTYPE is unavailable; reaction animation and its RNG draws remain unimplemented', effect);
        return;
      }
      const random = this.session.random, model = object.modelType;
      if (random.next() % 2 === 0 && model.includes('P') && model.includes('F')) object.animationState = 23;
      else if (random.next() % 3 === 0) object.animationState = 77;
      else object.animationState = random.next() % 2 === 0 ? 100 : 99;
    }
    this.omission(object, 'Damage reaction selected; native combat animation playback/pause scheduling is not connected', effect);
  }
  setLastHostile(object, creator, force = 0) {
    const session = this.session;
    return setLastHostileActor(object, creator?.id ?? OBJECT_INVALID, force, {
      object: id => session.registry.get(id), creature: id => session.registry.get(id)?.objectType === 5 ? session.registry.get(id) : null,
      dead: a => Number(session.isDead(a)), dm: a => Number(Boolean(a.isDM)), hitPoints: a => session.hitPoints(a.id, false),
      area: a => session.registry.get(a.areaId), pvp: a => {
        if (!Number.isInteger(a.pvpSetting)) throw new Error('Native hostile actor area PVP setting is unavailable');
        return session.getPVPSetting(a);
      }, faction: a => {
        if (!Number.isInteger(a.factionId)) throw new Error('Native hostile actor faction ID is unavailable'); return a.factionId;
      }, warning: message => this.omission(object, message)
    });
  }
  lastHostile(object) {
    if (!object) return OBJECT_INVALID;
    let id = object.lastHostileActorId ?? OBJECT_INVALID;
    if (!object.plot) {
      let actor = this.session.registry.get(id);
      if (actor?.objectType === 11) { id = actor.creatorId; actor = this.session.registry.get(id); }
      if (actor?.objectType === 5 && !this.session.isDead(actor) && !this.session.isDying(actor)) return id;
    }
    object.lastHostileActorId = OBJECT_INVALID;
    return OBJECT_INVALID;
  }
  preflight(object, effect) {
    if (object.objectType !== 5) return;
    // These branches change scripts, HP or RNG order. Do not silently emulate
    // their absence when a live object actually needs them.
    const unsupported = (object.effects ?? []).some(e => [8, 61].includes(e.type));
    if ([15, 16].includes(object.animationState) || unsupported) {
      this.omission(object, 'Damage during casting or with shield/status effects requires unavailable lifecycle providers', effect);
      throw new Error('Damage casting/shield/status lifecycle is not implemented');
    }
    this.session.getDifficultyOption(5);
  }
  async apply(object, effect, context) {
    if (effect.integers.length < 39 || this.session.isDead(object)) return;
    const components = effect.integers.slice(0, 32).map(n => n | 0);
    let amount = 0;
    for (let i = 0; i < 32; i++) if (components[i] >= 0) {
      if (object.plot) components[i] = 0;
      amount = (amount + components[i]) | 0;
    }
    const creator = this.session.registry.get(effect.creatorId), attacker = creator?.objectType === 5 ? creator : null;
    const processed = effect.integers[36] !== 0, reflected = effect.integers[37] !== 0;
    if (!amount && !object.plot) {
      if (processed && !reflected && attacker && object.objectType === 5 && object.effects?.some(e => e.type === 61)) {
        this.omission(object, 'Zero-damage combat shield recursion is not implemented', effect);
        throw new Error('Damage shield resolution is not implemented');
      }
      return;
    }
    if (![5, 9, 10].includes(object.objectType)) return;
    this.preflight(object, effect);
    const wasDying = this.session.isDying(object);
    if (!processed) {
      const flags = effect.integers[34] >>> 0;
      const power = flags & 4103 ? effect.integers[35] | 0 : 6;
      amount = await this.mitigate(object, attacker, amount, flags, power, effect.bypassImmunity);
      // Native creature history overwrites EACH present component with the
      // mitigated total. HP is reduced by that total ONCE; never resum it.
      if (object.objectType === 5) for (let i = 0; i < 32; i++) if (components[i] >= 0) components[i] = amount;
    }
    if (object.objectType === 5) {
      if (amount > 0) { await this.subtract(object, amount, context); this.reaction(object, effect); }
      if (attacker) {
        // OnApplyDamage 140428bce..140428be9: each party broadcast
        // precedes that endpoint's initiative, defender before attacker.
        await broadcastCombatState(object,this.session.combat.broadcastProviders());
        this.initiative(object);
        await broadcastCombatState(attacker,this.session.combat.broadcastProviders());
        this.initiative(attacker);
      }
      object.lastDamagerId = effect.creatorId;
      this.setLastHostile(object, creator);
      object.lastDamage = [...components];
      // Shields are preflight-blocked until their recursive handler exists.
      if (!object.isPossessedFamiliar && !this.session.isDead(object) &&
        !(object.isPC && (object.scripts?.damaged ?? '') === 'default')) await this.runEvent(object, object.scripts?.damaged, context);
      this.session.onMessage({ type: 'damage', id: object.id, creatorId: effect.creatorId, amount,
        components: [...components], text: `Damage: ${amount}` });
      if (!wasDying && this.session.isDying(object)) this.dying(object, effect);
      else if (this.session.isDead(object)) await this.death(object, effect, context);
    } else {
      if (!object.plot) object.currentHP = (i16(this.session.hitPoints(object.id, false)) - amount) | 0;
      this.session.queueScript(object.scripts?.damaged, object.id, { damager: effect.creatorId, damageAmount: amount });
      if (!object.plot) {
        object.lastDamage = [...components];
        this.session.onMessage({ type: 'damage', id: object.id, creatorId: effect.creatorId, amount,
          components: [...components], text: `Damage: ${amount}` });
      }
      if (this.session.isDead(object)) await this.death(object, effect, context);
    }
  }
  dying(object, effect) {
    this.playerEvent(32, object);
    object.actionTimer = 0;
    this.omission(object, 'Native dying orientation/animation and automatic GUI closure are not implemented', effect);
    this.session.onMessage({ type: 'dying', id: object.id, text: `${object.name || 'Creature'} is dying` });
  }
  playerEvent(nativeEventId, object) {
    const session = this.session;
    if (!session.module) throw new Error('Player lifecycle requires the canonical module object');
    // Module::EventHandler stores event 32 at +0x38c and event 10 at +0x388,
    // independently of entering (+0x344), even when the script is empty.
    // Commit this only when the event is dispatched.
    session.scheduler.enqueue(session.module.id, { type: 'script', nativeEventId,
      name: session.ifo?.[nativeEventId === 32 ? 'Mod_OnPlrDying' : 'Mod_OnPlrDeath'] ?? '',
      eventObjects: { [nativeEventId === 32 ? 'dying' : 'died']: object.id } });
  }
  async removeTemporary(object, effect, context) {
    const state = this.health(object), before = creatureLifeState(state, object.isPC, object.isPossessedFamiliar);
    state.temporaryHP = Math.max(0, (i16(state.temporaryHP) - (effect.integers[0] | 0)) | 0);
    const after = creatureLifeState(state, object.isPC, object.isPossessedFamiliar);
    if (!before.dying && after.dying) this.dying(object, effect);
    else if (!before.dead && after.dead) await this.death(object, { ...effect, creatorId: OBJECT_INVALID }, context);
  }
  async death(object, effect, context) {
    if (object.plot) return;
    if (object.objectType === 5) {
      const immortal = object.immortal ?? creatureRoot(object)?.IsImmortal ?? 0;
      if (immortal) {
        if (this.session.hitPoints(object.id, false) <= 0) { object.stats.currentHP = 1; this.synchronize(object); }
        return;
      }
      if (object.deathHandled) return;
      this.session.onClearActions(object.id);
      object.lastKillerId = effect.creatorId === object.id ? object.lastDamagerId ?? OBJECT_INVALID : effect.creatorId;
      await this.runEvent(object, object.scripts?.death, context);
      this.omission(object, 'Native death XP, witness reputation, associate lifecycle and death presentation are not implemented', effect);
      object.deathHandled = true;
      if (this.session.hitPoints(object.id, false) > -11) object.stats.currentHP = -11;
      this.synchronize(object);
      object.combatMode = 0; object.currentActionId = 65535;
      // Death purges effects immediately and restarts its live traversal.
      // Internal duration 3/4 and supernatural effects have native exceptions.
      let index = 0;
      while (index < (object.effects ?? []).length) {
        const active = object.effects[index];
        if ([3, 4].includes(active.durationType) || active.type === 32 ||
          active.subtype === 32 && ![8, 9, 23].includes(active.type)) index++;
        else { await this.session.effects.remove(object.id, active.id, context); index = 0; }
      }
      if (object.isPC || object.isPossessedFamiliar) this.playerEvent(10, object);
      else this.omission(object, 'Native corpse cleanup/body bag and encounter active-count updates are not implemented', effect);
    } else {
      this.session.onClearActions(object.id);
      if (object.kind === 'door') {
        const previous = object.animationState; object.animationState = 3; this.session.onDoorState(object, previous);
        // Linked-door death effects require the complete native transition lifecycle.
        this.omission(object, 'Linked-door death propagation and timed destroyed-object cleanup are not implemented', effect);
      } else this.omission(object, 'Destroyed placeable animation, GUI closure and timed cleanup are not implemented', effect);
      this.session.queueScript(object.scripts?.death, object.id);
    }
    this.session.onMessage({ type: 'death', id: object.id, creatorId: effect.creatorId, text: `${object.name || object.kind} died` });
  }
  amountByFlags(object, flags) {
    flags >>>= 0;
    if (!flags || flags & (flags - 1)) return 0;
    return object?.lastDamage?.[31 - Math.clz32(flags)] ?? 0;
  }
  amountByType(object, flags) {
    if (![5, 9, 10].includes(object?.objectType) || (flags | 0) < 1 ||
      (flags >>> 0) > highestDamageTypeFlag(this.session.characterRules?.damagetypes?.orderedRows?.length)) return 0;
    return this.amountByFlags(object, flags);
  }
  total(object) {
    return (object?.lastDamage ?? []).reduce((total, value) => value > 0 ? (total + value) | 0 : total, 0);
  }
}
