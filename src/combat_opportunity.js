import { OBJECT_INVALID } from './game_object_array.js';
import { nativeDistanceSquared } from './nearest_objects.js';
import { normalizeOrientation } from './combat_lifecycle.js';

const f = Math.fround;
const integer = (value,name) => {
  if (!Number.isInteger(value)) throw new Error(`Native opportunity attack ${name} is unavailable`);
  return value | 0;
};
const callback = (p,name) => {
  if (typeof p[name] !== 'function') throw new Error(`Native opportunity attack provider ${name} is unavailable`);
  return p[name];
};
function vector(value,name) {
  if (!Array.isArray(value) || value.length !== 3 || !value.every(Number.isFinite))
    throw new Error(`Native opportunity attack ${name} is unavailable`);
  return value;
}

// BroadcastAttackOfOpportunity 140382eb0..14038362f. Candidate-list order
// and live list updates belong to the area provider, not to ID sorting.
// Movement (all candidates, parameter2=1) can roll Tumble. A specified
// candidate never rolls Tumble and omits the native GetDead gate.
export async function broadcastOpportunityAttack(provoker, targetId, movement, p) {
  targetId = integer(targetId,'target ID') >>> 0;
  movement = integer(movement,'movement flag');
  await callback(p,'markAI')(1);
  const all = targetId === OBJECT_INVALID;
  let ids = all ? await callback(p,'areaCreatureIds')(provoker) : [targetId];
  if (ids === null) return;
  if (!Array.isArray(ids)) throw new Error('Native opportunity area creature list is unavailable');
  for (let index = 0; index < ids.length; index++) {
    const candidate = await callback(p,'creature')(integer(ids[index],'candidate ID') >>> 0);
    if (candidate && candidate.id !== provoker.id) {
      const flags = await callback(p,'visibility')(candidate,provoker.id);
      if (flags !== null && !Number.isInteger(flags)) throw new Error('Native opportunity visibility flags are unavailable');
      if (flags !== null && (flags & 1) !== 0) {
        const round = candidate.combatRound;
        if (!round) throw new Error('Native opportunity combat round is unavailable');
        if (integer(round.attacksOfOpportunity,'budget') > 0 && (integer(candidate.nativeField6ed,'field +6ed') & 255) !== 1 &&
            candidate.areaId === provoker.areaId && integer(candidate.nativeField700,'combat state') === 1 &&
            integer(Number(round.infinitePause),'infinite pause') === 0 && integer(Number(candidate.plot),'plot flag') === 0 &&
            (integer(candidate.combatMode,'combat mode') & 255) !== 1 && integer(Number(round.spellCastRound),'spell round') === 0 &&
            (!all || integer(await callback(p,'dead')(candidate),'dead state') === 0)) {
          const position = vector(candidate.position,'candidate position'), origin = vector(provoker.position,'provoker position');
          const range = await callback(p,'maximumRange')(candidate,provoker);
          if (!Number.isFinite(range)) throw new Error('Native opportunity maximum range is unavailable');
          if (nativeDistanceSquared(position,origin) <= f(f(range) * f(range)) &&
              integer(await callback(p,'spellOrHealQueued')(candidate),'spell/heal action state') === 0 &&
              integer(await callback(p,'ranged')(candidate),'ranged state') === 0 &&
              (integer(await callback(p,'reaction')(provoker,candidate.id),'reaction') & 255) === 2 &&
              integer(await callback(p,'invisible')(candidate),'invisibility') === 0) {
            const direction = normalizeOrientation(origin.map((v,i) => f(f(v)-f(position[i]))));
            const facing = vector(candidate.orientation,'candidate orientation');
            // Native X,Y,Z multiply/add order after renderer-axis conversion.
            const dot = f(f(f(f(facing[0])*direction[0]) + f(f(facing[2])*direction[2])) + f(f(facing[1])*direction[1]));
            let provoke = dot >= f(0.707) || dot > f(-0.707);
            if (all && movement === 1 && provoke) {
              const base = (integer(await callback(p,'skillRank')(provoker,21,null,1),'base Tumble') << 24) >> 24;
              if (base > 0) {
                const rank = (integer(await callback(p,'skillRank')(provoker,21,candidate,0),'effective Tumble') << 24) >> 24;
                if (typeof p.random?.dice !== 'function') throw new Error('Native opportunity RNG is unavailable');
                const roll = integer(p.random.dice(1,20),'Tumble roll') & 65535;
                const success = ((rank+roll)|0) >= 15;
                const data = {type:0,objects:[provoker.id>>>0],integers:[0xa87,roll,rank,15,0,success?1:rank < -5?3:0]};
                await callback(p,'broadcastSkill')(provoker,data);
                if (success) provoke = false;
              }
            }
            if (provoke) {
              if ((integer(candidate.attackActionTargetId,'attack action target') >>> 0) === OBJECT_INVALID)
                await callback(p,'requestAttack')(candidate,provoker.id,0,1,0);
              await callback(p,'addAttack')(candidate.combatRound,provoker.id);
              candidate.combatRound.attacksOfOpportunity = (candidate.combatRound.attacksOfOpportunity-1)|0;
              candidate.nativeField750 = 1; candidate.nativeField754 = 1500;
            }
          }
        }
      }
    }
    if (all) {
      ids = await callback(p,'areaCreatureIds')(provoker);
      if (!Array.isArray(ids)) throw new Error('Native live opportunity area list is unavailable');
    }
  }
}

// GetHasInvisbilityEffectApplied 140390bb0..140390c0d scans the live sorted
// array from cached +da2; either type47 (any subtype) or type63 returns one.
export function hasCombatInvisibility(effects,index) {
  if (!Array.isArray(effects)) throw new Error('Native invisibility effect list is unavailable');
  index = integer(index,'invisibility index') & 65535;
  for (; index < effects.length; index++) {
    const type = integer(effects[index]?.type,'effect type') & 65535;
    if (type > 63) return 0;
    if (type === 47 || type === 63) return 1;
  }
  return 0;
}
