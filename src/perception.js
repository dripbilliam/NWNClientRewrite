// Native CNWVisibilityNode is eight bytes: uint32 ID, flag byte at +4,
// and reserved bytes. Bits 0/1 are seen/heard; bits 2/3 and 4 are distinct
// state inputs to attack gates. Reserved bits are not inferred from geometry.
function objectId(value) {
  if (!Number.isInteger(value)) throw new Error('Native visibility object ID is unavailable');
  return value >>> 0;
}

// GetBlind 0x140390210..0x14039022e reads +770, distinct from the
// +8d4 perception-update byte used by GetFlatFooted and attack eligibility.
// Its overrides are not equivalent to checking a single blindness bit.
export function getBlind(object) {
  if(!Number.isInteger(object.visionFlags))throw new Error('Native vision flags are unavailable');
  const flags=object.visionFlags&255;
  return flags&0x24?0:flags&0x10?1:Number((flags&0x0a)===8);
}

export class VisibilityList {
  constructor(ownerId, onWarning = () => {}) { this.ownerId = objectId(ownerId); this.nodes = []; this.capacity = 0; this.onWarning = onWarning; }
  node(id) { id = objectId(id); return this.nodes.find(node => node.id === id) ?? null; }
  get(id) { return this.node(id)?.flags; }
  // GetVisibleListElement 0x1403d5850; AddToVisibleList 0x1403d0db0.
  add(id, seen, heard, state, retained) {
    id = objectId(id);
    if (this.node(id)) return;
    if (this.nodes.length === this.capacity) this.capacity = this.capacity ? this.capacity * 2 : 16;
    this.nodes.push({ id, flags: (seen & 1) | (heard & 1) << 1 | (state & 3) << 2 | (retained & 1) << 4 });
  }
  // Explicit cached flag updates retain upper bits supplied by their provider.
  set(id, flags) {
    if (!Number.isInteger(id) || !Number.isInteger(flags)) throw new Error('Native visibility node is unavailable');
    let node = this.node(id);
    if (!node) { this.add(id, 0, 0, 0, 0); node = this.node(id); }
    node.flags = flags & 255; return this;
  }
  // RemoveFromVisibleList 0x1403d7390 removes every matching node, in reverse.
  remove(id) {
    id = objectId(id);
    if (id === this.ownerId) this.onWarning("Native warning: You're trying to remove yourself from your own visibility list!");
    for (let index = this.nodes.length - 1; index >= 0; index--) if (this.nodes[index].id === id) this.nodes.splice(index, 1);
  }
  // ClearVisibleList 0x1403d3760 retains the FIRST self record and capacity 1.
  clear() {
    const self = this.node(this.ownerId);
    this.nodes = self ? [{ ...self }] : []; this.capacity = self ? 1 : 0;
  }
}

// AddAttackActions rejects the state==1 pair even if seen/heard are set.
export function requestVisibilityAllowsAttack(flags) {
  if (flags !== null && !Number.isInteger(flags)) throw new Error('Native visibility flags are unavailable');
  return flags === null || (flags & 12) !== 4;
}

// AIActionAttackObject 0x1403dd4e2..1403dd593. Missing nodes reject creature
// targets for ordinary PC/familiar attackers, but not NPC/DM/noncreature cases.
export function targetVisibilityAllowsAttack(actor, targetCreature, flags) {
  if (flags !== null && !Number.isInteger(flags)) throw new Error('Native visibility flags are unavailable');
  if (flags === null) return !targetCreature || !(actor.isPC || actor.isPossessedFamiliar) || Boolean(actor.isDM);
  return (flags & 12) !== 4 && (flags & 19) !== 16;
}

// GetAIStateReaction 0x1404ab6c0, reputation/PVP classification only.
// Native reputation ownership, associate/DM gates and same-faction output
// must be provided by the caller; static FAC data alone is insufficient.
export function reactionFromReputation(reputation, sameFaction, pvpSetting, creaturePair, hasArea) {
  if (!Number.isInteger(reputation) || !Number.isInteger(sameFaction) ||
      creaturePair && hasArea && !Number.isInteger(pvpSetting) || typeof creaturePair !== 'boolean' || typeof hasArea !== 'boolean')
    throw new Error('Native AI reaction inputs are unavailable');
  reputation |= 0;
  if (creaturePair && hasArea) {
    pvpSetting &= 255;
    if (pvpSetting === 1 && reputation >= 90 && sameFaction === 0) return 0;
    if (pvpSetting === 2 && reputation >= 90) return 0;
  }
  return reputation >= 90 ? 1 : reputation <= 10 ? 2 : 0;
}
