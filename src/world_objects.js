import { GameObjectArray, GAME_OBJECT_TYPE, OBJECT_INVALID } from './game_object_array.js';

// Area membership is a view of the shared object array, never an ID allocator.
export class WorldObjects {
  constructor(areaId, registry = new GameObjectArray()) {
    if (!Number.isInteger(areaId) || areaId < 0 || areaId > 0xffffffff) throw new Error('Area membership requires an OBJECT_ID');
    this.areaId = areaId; this.registry = registry; this.objects = new Map(); this.tags = new Map(); this.sources = new Set();
    this.renderBindings = new Map();
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
    if (renderObject) { renderObject.userData.worldObjectId = id; this.renderBindings.set(id, renderObject); }
    return object;
  }
  get(id) { return this.objects.get(id); }
  byTag(tag) { return (this.tags.get(String(tag).slice(0, 64)) ?? []).map(id => this.get(id)); }
  // A view of canonical state. No simulation objects retain disposed meshes;
  // callers synchronize only between scheduler pumps. Facing/clips have their
  // own owners and are deliberately not derived from displacement here.
  syncCreaturePositions(onMove = () => {}) {
    for (const [id, render] of this.renderBindings) {
      const actor = this.objects.get(id);
      if (!actor || this.registry.get(id) !== actor || actor.areaId !== this.areaId || actor.objectType !== GAME_OBJECT_TYPE.creature) continue;
      if (!Array.isArray(actor.position) || actor.position.length !== 3 || !actor.position.every(Number.isFinite)) throw new Error(`Creature ${id} has no renderable canonical position`);
      const next = actor.position, previous = [render.position.x, render.position.y, render.position.z];
      if (next.every((value, axis) => value === previous[axis])) continue;
      render.position.set(...next);
      onMove(actor, next.map((value, axis) => value - previous[axis]));
    }
  }
}
