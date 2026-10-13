const f = Math.fround;
const idValue = id => {
  if (!Number.isInteger(id) || id < 0 || id > 0xffffffff) throw new Error('Native area spatial ID is invalid');
  return id;
};
const xPosition = object => {
  if (!object || !Array.isArray(object.position) || !Number.isFinite(object.position[0]) || !Number.isFinite(f(object.position[0])))
    throw new Error('Native area spatial position is unavailable');
  return f(object.position[0]);
};

// CNWSArea+228/+230/+234 retains an ordered CExoArrayList<uint32>.
// This implements its spatial-array operations, not AddObjectToArea's separate
// client-count, AI activation or event12/13 side effects.
export class NativeAreaSpatialArray {
  constructor(registry, warning = () => {}) {
    this.registry = registry; this.warning = warning;
    this.ids = new Uint32Array(0); this.count = 0; this.capacity = 0;
  }
  view() { return this.ids.subarray(0, this.count); }
  indexOf(id) { return this.view().indexOf(idValue(id)); }
  // GetFirstObjectIndiceByX14035e820..14035e93d; preserve lookup order,
  // last-index special case and native failure on a stale canonical ID.
  firstByX(x) {
    x = f(x); if (!Number.isFinite(x)) throw new Error('Native area spatial query X is unavailable');
    let low = 0, high = this.count - 1;
    const last = high;
    while (low < high || low === last) {
      const middle = (low + high) >> 1;
      const object = this.registry.get(this.ids[middle]);
      if (!object) { this.warning('Native GetFirstObjectIndiceByX warning: Bad OBJECT_ID in Game Object Array'); return null; }
      if (xPosition(object) < x) low = middle + 1;
      else { if (middle === high) return middle; high = middle; }
    }
    return low === high ? low : null;
  }
  append(id) {
    idValue(id);
    // CExoArrayList<uint32>::Add14008ae10 grows when old count==capacity.
    if (this.count === this.capacity) {
      const capacity = this.capacity === 0 ? 16 : this.capacity * 2;
      if (capacity > 16_777_216) throw new Error('Native area spatial allocation is unsupported');
      const ids = new Uint32Array(capacity); ids.set(this.view()); this.ids = ids; this.capacity = capacity;
    }
    this.ids[this.count++] = id;
  }
  remove(id) {
    const index = this.indexOf(id);
    if (index >= 0) { this.count--; this.ids.copyWithin(index, index + 1, this.count + 1); }
    // Native leaves the old last element/capacity allocated.
  }
  insert(id) {
    idValue(id); const object = this.registry.get(id); if (!object) return 0;
    const x = xPosition(object);
    if (this.indexOf(id) >= 0) this.remove(id);
    const index = this.firstByX(x);
    this.append(id);
    if (index !== null) { this.ids.copyWithin(index + 1, index, this.count - 1); this.ids[index] = id; }
    return 1;
  }
  // UpdatePositionInObjectsArray140368370..14036852a swaps only strictly
  // out-of-order neighbors. Equal X retains prior array order after movement.
  update(object) {
    let index = this.indexOf(object.id), count = this.count;
    if (index < 0) throw new Error('Native position update references an object absent from the area spatial array');
    const x = xPosition(object), next = index + 1;
    let neighbor = next === count ? null : this.registry.get(this.ids[next]);
    if (next !== count && (!neighbor || x > xPosition(neighbor))) {
      while (index + 1 < count) {
        neighbor = this.registry.get(this.ids[index + 1]);
        if (!neighbor || x <= xPosition(neighbor)) return 1;
        const id = this.ids[index]; this.ids[index] = this.ids[index + 1]; this.ids[++index] = id;
      }
    } else if (index > 0) {
      neighbor = this.registry.get(this.ids[index - 1]);
      if (neighbor && x >= xPosition(neighbor)) return 1;
      while (index > 0) {
        neighbor = this.registry.get(this.ids[index - 1]);
        if (!neighbor || xPosition(neighbor) <= x) return 1;
        const id = this.ids[index]; this.ids[index] = this.ids[index - 1]; this.ids[--index] = id;
      }
    }
    return 1;
  }
}

// CNWSObject::SetPosition14049bb40..14049bbd9. Render vector mapping
// is a storage adaptation only. Flag exactly1 suppresses area lookup/order.
// Unchanged values (including +/-0 equality) suppress all writes/calls.
export function setObjectPosition(object, point, flag, providers) {
  if (!Number.isInteger(flag) || !Array.isArray(point) || point.length !== 3 || !point.every(v => Number.isFinite(v) && Number.isFinite(f(v))))
    throw new Error('Native object position arguments are unavailable');
  if (!Array.isArray(object.position) || object.position.length !== 3) throw new Error('Native object position is unavailable');
  point = point.map(f);
  if (point.every((value, axis) => value === f(object.position[axis]))) return;
  let area = null;
  if (flag !== 1) {
    if (typeof providers.area !== 'function') throw new Error('Native object SetPosition area provider is unavailable');
    area = providers.area(object);
    if (area && typeof providers.update !== 'function') throw new Error('Native object SetPosition array update is unavailable');
  }
  object.position.splice(0, 3, ...point);
  object.nativePosition = [point[0], f(-point[2]), point[1]];
  if (area) providers.update(area, object);
}
