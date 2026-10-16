import { OBJECT_INVALID } from './game_object_array.js';
import { reactionFromReputation } from './perception.js';
import {subtractWorldTimes as subtractNativeWorldTimes} from './world_timer.js';

const integer = (value, name) => {
  if (!Number.isInteger(value)) throw new Error(`Native reputation ${name} is unavailable`);
  return value | 0;
};
const id = value => integer(value, 'object ID') >>> 0;
const independent = object => ((integer(object.associateType, 'associate type') - 7) & 65535) < 2;
const f = Math.fround;
const cvtt = value => Number.isFinite(value) && value >= -2147483648 && value < 2147483648 ? Math.trunc(value) : -2147483648;

// CFactionManager +28/+30; LoadReputations 0x140357f40. Row FactionID2
// owns the reputation toward column FactionID1. Missing cells initialize 100.
export class FactionReputationTable {
  constructor(npcCount, entries = []) {
    this.npcCount = integer(npcCount, 'NPC faction count');
    if (npcCount < 0) throw new Error('Negative native NPC faction count');
    this.values = Array((npcCount + 1) * npcCount).fill(100);
    for (const entry of entries) {
      const source = integer(entry.FactionID1, 'FAC source faction'), owner = integer(entry.FactionID2, 'FAC owner faction');
      const amount = integer(entry.FactionRep, 'FAC amount');
      if (owner > 0 && owner <= npcCount && source >= 0 && source <= npcCount)
        this.values[(npcCount + 1) * (owner - 1) + source] = Math.max(0, Math.min(100, amount));
    }
  }
  isNPC(faction) { faction = integer(faction, 'faction'); return faction > 0 && faction <= this.npcCount; }
  // GetNPCFactionReputation 0x140357cc0 swaps once when the FIRST argument
  // is outside the NPC table but the second is inside; two PC factions return
  // 50. The first argument selects the row, despite its source-faction name.
  get(source, owner) {
    source = integer(source, 'source faction'); owner = integer(owner, 'owner faction');
    if (!this.isNPC(source)) {
      if (!this.isNPC(owner)) return 50;
      [source, owner] = [owner, source];
    }
    const index = Math.imul(this.npcCount + 1, source - 1) + owner | 0;
    return index >= 0 && index < this.values.length ? this.values[index] : 50;
  }
  // PostProcess 0x14039b72b -> GetDefaultPCReputation 0x1403577e0.
  defaultPC() {
    return Array.from({ length: this.npcCount }, (_, index) => this.values[index * (this.npcCount + 1)]);
  }
  // SetNPCFactionReputation 1403583d0. Unlike Get, this never swaps.
  // FactionID2 selects the row, FactionID1 the column; reject invalid IDs.
  set(source,owner,amount){
    source=integer(source,'source faction');owner=integer(owner,'owner faction');amount=integer(amount,'amount');
    if(owner>0&&owner<=this.npcCount&&source>=0&&source<=this.npcCount){
      const index=Math.imul(this.npcCount+1,owner-1)+source|0;
      if(index<this.values.length)this.values[index]=Math.max(0,Math.min(100,amount));
    }
  }
}

// CNWSArea::GetPVPSetting 0x14035ea70, including inherited area value 3.
export function effectivePVPSetting(areaSetting, serverSetting) {
  areaSetting = integer(areaSetting, 'area PVP setting') & 255;
  serverSetting = integer(serverSetting, 'server PVP setting') & 255;
  if (areaSetting === 3) return serverSetting;
  if (serverSetting === 1) return areaSetting === 2 ? 1 : areaSetting;
  return serverSetting === 2 ? areaSetting : 0;
}

// CWorldTimer::SubtractWorldTimes 0x140597a20. Failure leaves the caller's
// output untouched; JS exposes failure rather than inventing those bytes.
export function subtractWorldTimes(now, then, dayLength) {
  const result=subtractNativeWorldTimes(now,then,dayLength);
  return result.status===0?{status:0,days:result.day,milliseconds:result.time}:result;
}

// CalculatePersonalReputationAdjustment 0x1403d10b0. Decay uses a fixed
// 180000 ms divisor, NOT the record's Duration; Duration only gates expiry.
// The native caller uses the time remainder and ignores elapsed days.
export function personalReputationAdjustment(owner, targetId, providers) {
  const target = providers.creature(id(targetId));
  if (!target || owner.personalReputationList === null) return 0;
  if (!Array.isArray(owner.personalReputationList)) throw new Error('Native personal reputation list is unavailable');
  const master = id(target.masterId);
  if (master === id(owner.id) && (integer(target.associateType, 'associate type') & 65535) === 5) return 0;
  let amount = 0;
  for (let index = owner.personalReputationList.length - 1; index >= 0; index--) {
    const entry = owner.personalReputationList[index], recordId = id(entry.objectId);
    if (recordId !== id(targetId) && recordId !== master) continue;
    const value = integer(entry.amount, 'personal amount');
    // Native queries/subtracts time even for a nondecaying record. Preserve
    // that callback order and fail for unavailable/undefined output on decay.
    if (typeof providers.elapsed !== 'function') throw new Error('Native personal reputation world time is unavailable');
    const elapsed = providers.elapsed(entry);
    if (integer(entry.decays, 'decay flag') === 0) amount = (amount + value) | 0;
    else {
      const milliseconds = f(id(elapsed.milliseconds));
      if (milliseconds <= f(f(integer(entry.duration, 'duration')) * f(1000)))
        amount = (amount + cvtt(f(f(f(f(180000) - milliseconds) / f(180000)) * f(value)))) | 0;
      else owner.personalReputationList.splice(index, 1);
    }
  }
  return amount;
}

// GetCreatureReputation 0x1403d4e20. Providers own canonical lookups,
// actual PVP settings and world time; this helper does not infer perception.
export function creatureReputation(owner, targetId, sourceFaction, associateFlag, providers, ancestry = new Set()) {
  targetId = id(targetId); sourceFaction = integer(sourceFaction, 'source faction'); associateFlag = integer(associateFlag, 'associate flag');
  const key = `${id(owner.id)}:${targetId}:${associateFlag}`;
  if (ancestry.has(key)) throw new Error('Cyclic native reputation ownership is unsupported');
  ancestry = new Set(ancestry); ancestry.add(key);
  const target = providers.creature(targetId), master = id(owner.masterId);
  if (targetId === master || target && id(target.masterId) === id(owner.id)) return 100;
  const adjustment = () => personalReputationAdjustment(owner, targetId, providers);
  const pc = integer(owner.reputationPCFlag, 'PC flag');
  const npc = faction => providers.table.get(sourceFaction, integer(faction, 'owner faction'));
  if (master === OBJECT_INVALID || independent(owner)) {
    if (pc !== 1) return (npc(owner.factionId) + adjustment()) | 0;
    if (target) {
      if (integer(target.reputationPCFlag, 'target PC flag') !== 0) {
        const area = providers.area(owner);
        if (area) {
          if (integer(providers.pvp(area), 'PVP result') === 0 || integer(target.factionId, 'target faction') === integer(owner.factionId, 'owner faction'))
            return (100 + adjustment()) | 0;
          const list = owner.pvpReputationList;
          if (list !== null) {
            if (!Array.isArray(list)) throw new Error('Native PVP reputation list is unavailable');
            if (list.length) {
              const entry = list.find(entry => id(entry.objectId) === targetId);
              if (!entry) return (50 + adjustment()) | 0;
              if (integer(entry.field8, 'PVP node field +8') === 0) return adjustment();
            }
          }
        }
        return (50 + adjustment()) | 0;
      }
      if (id(target.masterId) !== OBJECT_INVALID && !independent(target))
        return (creatureReputation(owner, target.masterId, sourceFaction, 0, providers, ancestry) + adjustment()) | 0;
      const vector = owner.factionReputation;
      if (vector === null || sourceFaction < 1 || vector.length < sourceFaction) {
        providers.warning('Native warning: Source faction id invalid');
        return (100 + adjustment()) | 0;
      }
      return (integer(vector[sourceFaction - 1], 'PC faction vector') + adjustment()) | 0;
    }
    const object = providers.object(targetId);
    if (object && [13, 10, 9, 7].includes(object.objectType) && owner.factionReputation !== null && sourceFaction <= owner.factionReputation.length) {
      if (sourceFaction < 1) throw new Error('Native PC reputation vector underflow is unsupported');
      return (integer(owner.factionReputation[sourceFaction - 1], 'PC faction vector') + adjustment()) | 0;
    }
    return (50 + adjustment()) | 0;
  }
  if (associateFlag !== 0) {
    if (pc !== 0) {
      if (owner.factionReputation !== null && sourceFaction <= owner.factionReputation.length) {
        if (sourceFaction < 1) throw new Error('Native PC reputation vector underflow is unsupported');
        return (integer(owner.factionReputation[sourceFaction - 1], 'PC faction vector') + adjustment()) | 0;
      }
      return (50 + adjustment()) | 0;
    }
    return (npc(owner.originalFactionId) + adjustment()) | 0;
  }
  const masterObject = providers.creature(master);
  if (masterObject) return (creatureReputation(masterObject, targetId, sourceFaction, 0, providers, ancestry) + adjustment()) | 0;
  return (npc(owner.originalFactionId) + adjustment()) | 0;
}

// CNWSObject::GetReputation 0x1404abcd0. AOE owner traversal, symmetric
// NPC/PC delegation, same-faction output, self=100, and final clamp.
export function objectReputation(owner, targetId, associateFlag, providers, ancestry = new Set()) {
  targetId = id(targetId);
  const key = `${id(owner.id)}:${targetId}`;
  if (ancestry.has(key)) throw new Error('Cyclic native reputation delegation is unsupported');
  ancestry = new Set(ancestry); ancestry.add(key);
  let target = providers.object(targetId), sameFaction = 0;
  const visited = new Set();
  while (target?.objectType === 11) {
    const creator = id(target.creatorId);
    if (creator === targetId) return { reputation: 50, sameFaction };
    if (visited.has(targetId)) throw new Error('Cyclic native AOE reputation ownership is unsupported');
    visited.add(targetId); targetId = creator; target = providers.object(targetId);
  }
  if (!target || owner.isDM || target.isDM || !providers.table) return { reputation: 50, sameFaction };
  if (owner.objectType === 11) {
    const creator = providers.object(id(owner.creatorId));
    return creator ? objectReputation(creator, targetId, associateFlag, providers, ancestry) : { reputation: 50, sameFaction };
  }
  const sourceFaction = providers.faction(target), ownerFaction = providers.faction(owner);
  if (sourceFaction === null || ownerFaction === null) return { reputation: 50, sameFaction };
  sameFaction = Number(integer(sourceFaction, 'source faction') === integer(ownerFaction, 'owner faction'));
  if (targetId === id(owner.id)) return { reputation: 100, sameFaction };
  if (!providers.table.isNPC(sourceFaction) && providers.table.isNPC(ownerFaction))
    return objectReputation(target, owner.id, associateFlag, providers, ancestry);
  let reputation;
  if (owner.objectType === 5) reputation = creatureReputation(owner, targetId, sourceFaction, associateFlag, providers);
  else if ([13, 10, 9, 7].includes(owner.objectType)) reputation = providers.table.get(sourceFaction, ownerFaction);
  else return { reputation: 50, sameFaction };
  return { reputation: Math.max(0, Math.min(100, integer(reputation, 'result'))), sameFaction };
}

// GetAIStateReaction 0x1404ab6c0 queries TARGET.GetReputation(actor.id).
export function aiStateReaction(actor, targetId, providers) {
  const area = providers.area(actor);
  if (actor.objectType === 5 && (actor.isDM || independent(actor))) return 0;
  const target = providers.object(id(targetId));
  if (!target || ![5, 7, 9, 10, 11, 13].includes(target.objectType) || target.isDM) return 0;
  const result = objectReputation(target, actor.id, 0, providers);
  const creaturePair = actor.objectType === 5 && target.objectType === 5;
  return reactionFromReputation(result.reputation, result.sameFaction,
    creaturePair && area ? providers.pvp(area) : undefined, creaturePair, Boolean(area));
}
