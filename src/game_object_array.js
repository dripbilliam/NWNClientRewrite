export const OBJECT_INVALID = 0x7f000000;
export const EXTERNAL_OBJECT = 0x80000000;
export const GAME_OBJECT_TYPE = Object.freeze({ module: 3, area: 4, creature: 5, player: 5, item: 6, trigger: 7, projectile: 8, placeable: 9, door: 10, areaOfEffect: 11, waypoint: 12, encounter: 13, store: 14, portal: 15, sound: 16 });
export const OBJECT_ARRAY_RESULT = Object.freeze({ SUCCESS: 0, BAD_ID: 1, NULL_OBJECT: 4 });
const uint32 = id => Number.isInteger(id) && id >= 0 && id <= 0xffffffff;

// Native CGameObjectArray: two hash-table halves (internal/external), full-ID
// comparison within a bucket, ascending ordinary IDs, descending character IDs.
// CharacterObject is an allocator flag, NOT synonymous with creature/player.
export class GameObjectArray {
  constructor({ clientMode = true, cacheBits = 16 } = {}) {
    if (!Number.isInteger(cacheBits) || cacheBits < 1 || cacheBits > 20) throw new Error('Invalid object cache size');
    this.clientMode = clientMode; this.cacheSize = 2 ** cacheBits;
    this.buckets = Array(this.cacheSize * (clientMode ? 2 : 1)).fill(null);
    this.nextObjectId = [0, 0]; this.nextCharacterId = [0x7fffffff, 0x7fffffff];
    this.objects = new Map();
  }
  bucket(id) { return id % this.cacheSize + (id >= EXTERNAL_OBJECT ? this.cacheSize : 0); }
  getGameObject(id) {
    if (!uint32(id) || this.bucket(id) >= this.buckets.length) return { status: 1, object: null };
    for (let node = this.buckets[this.bucket(id)]; node; node = node.next) if (node.id === (id & 0x7fffffff)) return { status: 0, object: node.object };
    return { status: 1, object: null };
  }
  get(id) { return this.getGameObject(id).object ?? undefined; }
  insert(id, object) {
    const bucket = this.bucket(id), stripped = id & 0x7fffffff;
    const node = { id: stripped, object, next: null };
    let previous = null, current = this.buckets[bucket];
    while (current && current.id > stripped) { previous = current; current = current.next; }
    node.next = current;
    if (previous) previous.next = node; else this.buckets[bucket] = node;
    object.id = id; this.objects.set(id, object); return { status: 0, id, object };
  }
  addInternalObject(object, { characterObject = false } = {}) {
    if (!object) return { status: 4, id: OBJECT_INVALID };
    if (uint32(object.id) && this.get(object.id)) return { status: 1, id: OBJECT_INVALID };
    const id = characterObject ? this.nextCharacterId[0] : this.nextObjectId[0];
    if (characterObject ? id <= 0x7f000001 : id >= 0x7effffff) return { status: 1, id: OBJECT_INVALID };
    // Do not recycle deleted IDs. At-position insertion advances these cursors.
    if (this.get(id)) return { status: 1, id: OBJECT_INVALID };
    if (characterObject) this.nextCharacterId[0]--; else this.nextObjectId[0]++;
    return this.insert(id, object);
  }
  addExternalObject(id, object) {
    if (!object) return { status: 4, id: OBJECT_INVALID };
    if (!uint32(id) || !this.clientMode || this.get(id)) return { status: 1, id: OBJECT_INVALID };
    const externalId = ((id & 0x7fffffff) | EXTERNAL_OBJECT) >>> 0;
    return this.addObjectAtPos(externalId, object);
  }
  addObjectAtPos(id, object) {
    if (!object) return { status: 4, id: OBJECT_INVALID };
    if (!uint32(id) || this.bucket(id) >= this.buckets.length || this.get(id)) return { status: 1, id: OBJECT_INVALID };
    const stripped = id & 0x7fffffff, half = Number(id >= EXTERNAL_OBJECT);
    // Preserve the target's mask classification, including its rejection of
    // the intermediate 0x01000000..0x7effffff range at explicit insertion.
    if (stripped & 0x7f000000) {
      if (stripped < 0x7f000001) return { status: 1, id: OBJECT_INVALID };
      this.nextCharacterId[half] = Math.min(this.nextCharacterId[half], stripped - 1);
    } else this.nextObjectId[half] = Math.max(this.nextObjectId[half], stripped + 1);
    return this.insert(id, object);
  }
  delete(id) {
    if (!uint32(id) || this.bucket(id) >= this.buckets.length) return { status: 1, object: null };
    const bucket = this.bucket(id); let previous = null, node = this.buckets[bucket];
    while (node && node.id !== (id & 0x7fffffff)) { previous = node; node = node.next; }
    if (!node) return { status: 1, object: null };
    if (previous) previous.next = node.next; else this.buckets[bucket] = node.next;
    this.objects.delete(id); return { status: 0, object: node.object };
  }
  // This build's exported CGameObjectArray::Clean is literally RET. Session
  // teardown replaces the registry; callers must not assume Clean deletes it.
  clean(_list) {}
}
