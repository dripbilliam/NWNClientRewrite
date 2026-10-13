import { GameObjectArray, GAME_OBJECT_TYPE, OBJECT_INVALID } from './game_object_array.js';

// Area membership is a view of the shared object array, never an ID allocator.
export class WorldObjects {
  constructor(areaId, registry = new GameObjectArray()) {
    if (!Number.isInteger(areaId) || areaId < 0 || areaId > 0xffffffff) throw new Error('Area membership requires an OBJECT_ID');
    this.areaId = areaId; this.registry = registry; this.objects = new Map(); this.tags = new Map(); this.sources = new Set();
  }
  add(kind, sourceKey, record, renderObject = null) {
    if (this.sources.has(sourceKey)) throw new Error(`Duplicate world placement ${sourceKey}`);
    let object = record;
    if (!Number.isInteger(record.id) || this.registry.get(record.id) !== record) {
      const result = this.registry.addInternalObject(record);
      if (result.status) throw new Error('Cannot register world object');
    }
    const id = record.id;
    if (this.objects.has(id)) throw new Error(`Duplicate world object ${id}`);
    Object.assign(object, { kind, objectType: GAME_OBJECT_TYPE[kind], areaId: this.areaId, sourceKey,
      lastUsedBy: object.lastUsedBy ?? OBJECT_INVALID });
    this.objects.set(id, object);
    this.sources.add(sourceKey);
    if (object.tag) {
      const key = object.tag.slice(0, 64);
      this.tags.set(key, [id, ...(this.tags.get(key) ?? [])]);
    }
    if (renderObject) renderObject.userData.worldObjectId = id;
    return object;
  }
  get(id) { return this.objects.get(id); }
  byTag(tag) { return (this.tags.get(String(tag).slice(0, 64)) ?? []).map(id => this.get(id)); }
}
