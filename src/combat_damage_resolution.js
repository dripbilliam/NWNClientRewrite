import { getAttackData, setBaseAttackDamage, totalAttackDamage } from './combat_attack_data.js';
import { attackResultDoesDamage } from './combat_strike.js';
import { rulesetInt } from './combat_stats.js';

const requireProviders = (p,names) => { for (const name of names) if (typeof p[name] !== 'function') throw new Error(`Native damage stage provider ${name} is unavailable`); };
const integer = (value, name) => { if (!Number.isInteger(value)) throw new Error(`Native damage stage ${name} is unavailable`); return value | 0; };
const i8 = value => (value << 24) >> 24;
const i16 = value => (value << 16) >> 16;
const totalAttacks = round => { const sum = (round.onhandAttacks + round.offhandAttacks + round.additionalAttacks + round.bonusEffectAttacks) | 0; return sum > 1 ? sum & 255 : 1; };
const ordinaryFollowup = data => ((data.attackType - 867) & 65535) > 1;

// ResolveDamage 0x1403e4720..1403e4c55. This stage fills attack records;
// it never subtracts HP. Mitigation and side-effect queries stay in their
// native order; special systems are required providers rather than no-ops.
export async function resolveStrikeDamage(actor, target, rules, p) {
  requireProviders(p,['offhand','damageRoll','creature','hitPoints','hasFeat','flatFooted','remainingUses','decrementUses','savingThrow','classLevel','abilityModifier','deathAttack','rangedEquipped','energyBonus','onHit','itemCastSpell','onHitVisuals','message','position']);
  await p.preflight?.(actor,target);
  const round = actor.combatRound, index = round.currentAttack & 255, offhand = integer(await p.offhand(actor),'offhand flag');
  const data = getAttackData(round,index,p.warning), sneak = data.sneakAttack, death = data.deathAttack, critical = Number(data.result === 3);
  if (death === 1 && typeof p.random?.dice !== 'function') throw new Error('Native death attack RNG is unavailable');
  let amount = integer(await p.damageRoll(actor,target,{offhand,critical,sneak,death,maximize:Number(data.attackType === 882)}),'damage roll');
  if (data.attackType === 882) await p.decrementUses(actor,882);
  let defender = await p.creature(target);
  if (defender && ((i16(await p.hitPoints(defender)) - amount) | 0) < 1 && await p.hasFeat(defender,223) !== 0 &&
      await p.flatFooted(defender) === 0 && (await p.remainingUses(defender,223) & 255) !== 0) {
    if ((await p.savingThrow(defender,2,amount & 65535,0,actor.id,1,223,1) & 255) !== 0) amount = Math.trunc(amount / 2) | 0;
    await p.decrementUses(defender,223);
  }
  defender = await p.creature(target);
  if (defender && death === 1 && (round.currentAttack & 255) === 0 && defender.nativeField700 === 0) {
    const level = Math.max(1,integer(await p.classLevel(actor,30),'Assassin class level'));
    const dc = (i8(await p.abilityModifier(actor,'Int')) + rulesetInt(rules,'DEATH_ATTACK_BASE_SAVE_DC',10) + level) & 65535;
    if ((await p.savingThrow(defender,1,dc,20,actor.id,1,0,1) & 255) !== 1 && (defender.creatureState & 255) !== 8)
      await p.deathAttack(actor,target,integer(p.random.dice(1,6),'death attack die') + level);
  }
  defender = await p.creature(target);
  if (defender && amount > 0 && await p.hasFeat(defender,856) !== 0 && Number(defender.combatRound.epicDodgeUsed) === 0) {
    data.lists[3].push(await p.message(2,{objects:[target.id],integers:[234]})); data.result = 4;
    if (await p.rangedEquipped(actor) === 1) {
      const position = await p.position(target);
      if (!position?.every(Number.isFinite) || position.length !== 3) throw new Error('Native epic-dodge position is unavailable');
      position.forEach((component,i)=>data.raw.setFloat32(0x80+i*4,component,true));
    }
    defender.combatRound.epicDodgeUsed = 1; return;
  }
  const base = Number(target.plot) === 1 ? 0 : amount; setBaseAttackDamage(data,base);
  if (Number(target.plot) === 0) {
    await p.energyBonus(actor,target,data); // GetTotalEffectBonus(2,target,1,0,0,0,255,255,0).
    if (base > 0) await p.onHit(actor,target,offhand,critical);
    await p.itemCastSpell(actor,target);
    if (totalAttackDamage(getAttackData(round,index,p.warning),1) >= 0) await p.onHitVisuals(actor,target);
  }
}

// ResolvePostMeleeDamage 0x1403e8f00..1403e979a, also used after ranged
// damage. The initial total is retained for Crippling Strike/weapon warning;
// Quivering Palm explicitly rereads the current record total.
export async function resolvePostStrikeDamage(actor, target, rules, p) {
  if (!target) return;
  requireProviders(p,['creature','hitPoints','immortal','attackWeapon','devastatingCritical','effectImmunity','level','abilityModifier','savingThrow','effect','hasFeat','unarmed','newTarget','circleKick','cleave','weaponEffective','message']);
  await p.preflight?.(actor,target);
  const round = actor.combatRound, data = getAttackData(round,round.currentAttack & 255,p.warning);
  const hand = data.weaponAttackType, sneak = data.sneakAttack, total = totalAttackDamage(data,1);
  if (!attackResultDoesDamage(data.result)) return;
  const defender = await p.creature(target);
  if (!defender) {
    if (i16(await p.hitPoints(target)) <= total && Number(target.plot) === 0) data.killingBlow = 1;
  } else {
    if ((i16(await p.hitPoints(defender)) <= total || data.coupDeGrace === 1) && await p.immortal(defender) === 0 && Number(defender.plot) === 0) data.killingBlow = 1;
    const weapon = await p.attackWeapon(actor,hand);
    if (data.result === 3 && await p.devastatingCritical(actor,weapon) !== 0 && await p.effectImmunity(defender,31,actor,1) === 0 &&
        await p.immortal(defender) === 0 && data.killingBlow === 0) {
      const dc = ((await p.level(actor) & 255) >>> 1) + rulesetInt(rules,'DEVASTATING_CRITICAL_BASE_DC',10) + i8(await p.abilityModifier(actor,'Str'));
      if ((await p.savingThrow(defender,1,dc & 65535,0,actor.id,1,0,1) & 255) === 0) {
        data.lists[0].push(await p.effect(19,actor.id,[1,1],0)); data.result = 10;
      } else data.lists[3].push(await p.message(2,{objects:[target.id],integers:[257]}));
    }
    if (sneak === 1 && total > 0 && await p.hasFeat(actor,222) !== 0)
      data.lists[0].push(await p.effect(37,actor.id,[0,rulesetInt(rules,'CRIPPLING_STRIKE_STRENGTH_MODIFIER',2),4],2));
    if (data.attackType === 296 && data.result < 11 && (0x48a >>> data.result & 1) !== 0 && totalAttackDamage(data,1) > 0 &&
        await p.effectImmunity(defender,31,actor,1) === 0 && (await p.level(defender) & 255) < (await p.level(actor) & 255)) {
      const dc = ((await p.level(actor) & 255) >>> 1) + rulesetInt(rules,'QUIVERING_PALM_BASE_DC',10) + i8(await p.abilityModifier(actor,'Wis'));
      if ((await p.savingThrow(defender,1,dc & 65535,0,actor.id,1,0,1) & 255) === 0) data.lists[0].push(await p.effect(19,actor.id,[1,1],0));
    }
    if (data.coupDeGrace === 1) data.lists[0].push(await p.effect(19,actor.id,[0,1],0));
    if (ordinaryFollowup(data) && attackResultDoesDamage(data.result) && await p.hasFeat(actor,409) === 1 && round.circleKickAttacks > 0 &&
        await p.unarmed(actor) === 1 && totalAttacks(round) < 50) {
      const next = await p.newTarget(actor,defender.id);
      if (next) {
        round.newAttackTargetId = next.id >>> 0; await p.circleKick(round,next.id);
        actor.passiveAttack = 1; round.circleKickAttacks = (round.circleKickAttacks - 1) | 0;
      }
    }
    if (data.killingBlow === 1 && ordinaryFollowup(data) && totalAttacks(round) < 50) {
      const great = await p.hasFeat(actor,391) !== 0;
      if (great || await p.hasFeat(actor,6) !== 0 && round.cleaveAttacks > 0) {
        const next = await p.newTarget(actor,defender.id);
        if (next) {
          round.newAttackTargetId = next.id >>> 0; await p.cleave(round,next.id,Number(great)); actor.passiveAttack = 1;
          if (!great) round.cleaveAttacks = (round.cleaveAttacks - 1) | 0;
        }
      }
    }
  }
  if (total < 1 && Number(round.weaponSucks) === 0 && await p.weaponEffective(actor,target.id,Number(hand === 2)) === 0) {
    data.lists[3].push(await p.message(3,{integers:[117]})); round.weaponSucks = 1;
  }
}
