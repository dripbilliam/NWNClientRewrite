const valid = id => Number.isInteger(id) && id >= 0 && id <= 0xffffffff;

// CExoArrayList<uint32> Add14008ae10 / SetSize14007c830. IDs retain
// all32 bits; capacity grows16,32... on append but exactly to SetSize request.
export class NativeIdList {
  constructor() { this.ids = new Uint32Array(0); this.count = 0; this.capacity = 0; }
  view() { return this.ids.subarray(0, this.count); }
  indexOf(id) { if (!valid(id)) throw new Error('Native ID list value is invalid'); return this.view().indexOf(id); }
  reserve(capacity) {
    if (!Number.isInteger(capacity) || capacity < 0 || capacity > 16_777_216) throw new Error('Native ID list allocation is unsupported');
    if (capacity <= this.capacity) return;
    const ids = new Uint32Array(capacity); ids.set(this.view()); this.ids = ids; this.capacity = capacity;
  }
  append(id) {
    if (!valid(id)) throw new Error('Native ID list value is invalid');
    if (this.count === this.capacity) this.reserve(this.capacity === 0 ? 16 : this.capacity * 2);
    this.ids[this.count++] = id;
  }
  remove(id) {
    const index = this.indexOf(id);
    if (index >= 0) { this.count--; this.ids.copyWithin(index, index + 1, this.count + 1); }
  }
  setSize(size) {
    if (!Number.isInteger(size) || size < 0) throw new Error('Native ID list size is invalid');
    if (size === 0) { this.ids = new Uint32Array(0); this.count = 0; this.capacity = 0; return; }
    this.reserve(size); this.count = size;
    // Newly exposed native memory is uninitialized. Owners must fill before read.
  }
  copyFrom(other) { this.setSize(other.count); this.ids.set(other.view()); }
}
