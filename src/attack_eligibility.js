import { OBJECT_INVALID } from './game_object_array.js';
import { nativeDistanceSquared } from './nearest_objects.js';
import { targetVisibilityAllowsAttack } from './perception.js';

const f = Math.fround;
const intResult = (value, name) => {
  if (!Number.isInteger(value)) throw new Error(`Native attack ${name} is unavailable`);
  return value | 0;
};
const position = object => {
  if (!Array.isArray(object.position) || object.position.length !== 3 || !object.position.every(Number.isFinite))
    throw new Error('Native attack position is unavailable');
  return object.position.map(f);
};
const areaResult = value => {
  if (value === undefined) throw new Error('Native attack area is unavailable');
  return value;
};

// AIActionAttackObject 0x1403dd41f..1403dd8b8, eligibility and spatial gates
// only. Decisions requiring ChangeAttackTarget, approach action insertion or
// StartCombatRound are returned to their owner. Never infer LOS/path success.
export async function evaluateAttackEligibility(actor, targetId, providers = {}) {
  for (const name of ['getArea', 'getDead', 'getDying', 'getObject', 'asObject', 'asCreature', 'visibilityFlags'])
    if (typeof providers[name] !== 'function') throw new Error(`Native attack eligibility provider ${name} is unavailable`);
  if (!Number.isInteger(targetId) || !Number.isInteger(actor.id)) throw new Error('Native attack target ID is unavailable');
  targetId >>>= 0;
  const area = areaResult(await providers.getArea(actor));
  actor.nativeAttackField748 = 6000;
  if (intResult(await providers.getDead(actor), 'actor dead state') !== 0 ||
      intResult(await providers.getDying(actor), 'actor dying state') !== 0)
    return { decision: 'clearTarget', targetId: OBJECT_INVALID, targetValid: false };
  if (!Number.isInteger(actor.perceptionUpdateFlags)) throw new Error('Native actor perception update flags are unavailable');
  if ((actor.perceptionUpdateFlags & 132) !== 132)
    return { decision: 'clearTarget', targetId: OBJECT_INVALID, targetValid: false };
  // 1403dd478..486 requests SetAnimation(0), then returns action result3.
  // It does NOT call SetCombatState(0) or ChangeAttackTarget here.
  if (targetId === (actor.id >>> 0)) return { decision: 'clearAnimation', targetId, targetValid: false };
  const gameObject = await providers.getObject(targetId), target = gameObject && await providers.asObject(gameObject);
  if (!target) return { decision: 'round', targetId, targetValid: false };
  let valid = intResult(await providers.getDead(target), 'target dead state') === 0;
  const creature = await providers.asCreature(gameObject);
  if (creature && intResult(await providers.getDead(creature), 'target creature dead state') === 0 &&
      (creature.isPC || creature.isPossessedFamiliar) && intResult(await providers.getDying(creature), 'target dying state') === 1) valid = true;
  const flags = await providers.visibilityFlags(actor, targetId);
  valid = valid && targetVisibilityAllowsAttack(actor, Boolean(creature), flags);
  if (!valid) return { decision: 'round', targetId, targetValid: false };
  let targetPosition = position(target);
  const targetArea = areaResult(await providers.getArea(target));
  for (const name of ['maximumRange', 'desiredRange']) if (typeof providers[name] !== 'function')
    throw new Error(`Native attack eligibility provider ${name} is unavailable`);
  const maximum = f(await providers.maximumRange(actor, targetId)), desired = f(await providers.desiredRange(actor, targetId));
  if (!Number.isFinite(maximum) || !Number.isFinite(desired)) throw new Error('Native attack ranges are unavailable');
  if (actor.attackActionTargetId === OBJECT_INVALID) actor.attackActionTargetId = targetId;
  if (!creature) {
    if (typeof providers.useRange !== 'function') throw new Error('Native noncreature attack use point is unavailable');
    targetPosition = position({ position: await providers.useRange(actor, targetId, targetPosition) });
  }
  let spatialResult = 0;
  if (area !== null && area === targetArea) {
    for (const name of ['rangedEquipped', 'lineOfSight']) if (typeof providers[name] !== 'function')
      throw new Error(`Native attack eligibility provider ${name} is unavailable`);
    const actorPosition = position(actor);
    const lineTarget = targetPosition.every(value => value === f(-10000000)) ? position(target) : targetPosition.slice();
    actorPosition[1] = f(actorPosition[1] + f(1)); lineTarget[1] = f(lineTarget[1] + f(1));
    const ranged = intResult(await providers.rangedEquipped(actor), 'ranged equipment state');
    const los = intResult(await providers.lineOfSight(area, actorPosition, lineTarget, actor.id >>> 0, targetId, ranged), 'line-of-sight result');
    if (los !== 0) {
      if (ranged === 0 && creature) {
        if (typeof providers.meleeSpatialQuery !== 'function' || !actor.nativePathInfo)
          throw new Error('Native melee spatial query is unavailable');
        const path = actor.nativePathInfo, saved8 = path.field8, saved28 = path.field28;
        if (!Number.isFinite(saved8) || !Number.isInteger(saved28)) throw new Error('Native melee path information is unavailable');
        path.field8 = f(0.01); path.field28 = targetId;
        // The virtual area query consumes horizontal coordinates, not the
        // raised LOS ray. Geometry providers use replacement coordinates.
        const from = [f(actor.position[0]), f(actor.position[2])], to = [lineTarget[0], lineTarget[2]];
        try { spatialResult = intResult(await providers.meleeSpatialQuery(area, from, to, path), 'melee spatial result'); }
        finally { path.field8 = saved8; path.field28 = saved28; }
      } else spatialResult = 1;
    }
  }
  const reach = f(maximum + f(0.01));
  const outsideMaximumRange = targetArea !== area || nativeDistanceSquared(position(actor), targetPosition) > f(reach * reach);
  return { decision: !outsideMaximumRange && spatialResult !== 0 ? 'round' : 'approach', targetId,
    targetValid: true, targetPosition, area, targetArea, maximum, desired, spatialResult, outsideMaximumRange };
}
