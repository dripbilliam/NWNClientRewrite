// Owned fixture serialization only. No installed game resources are copied.
export const field = (type, value) => ({ type, value });
export const record = (fields, type = 0xffffffff) => ({ fields, type });
const text = value => Buffer.from(value, 'latin1');
const u32 = value => { const b = Buffer.alloc(4); b.writeUInt32LE(value >>> 0); return b; };
export function writeGff(fileType, root) {
  const structs = [], fields = [], labels = [], fieldData = [], fieldIndices = [], listIndices = [];
  let dataLength = 0;
  const data = bytes => { const offset = dataLength; fieldData.push(bytes); dataLength += bytes.length; return offset; };
  const label = name => {
    if (!name.length || text(name).length > 16) throw new Error(`Invalid fixture GFF label ${name}`);
    let index = labels.indexOf(name); if (index < 0) { index = labels.length; labels.push(name); } return index;
  };
  const add = node => {
    const index = structs.length, structure = { type: node.type >>> 0, indices: [] }; structs.push(structure);
    for (const [name, entry] of Object.entries(node.fields)) {
      const item = { type: entry.type, label: label(name), value: 0 }, fieldIndex = fields.length; fields.push(item);
      structure.indices.push(fieldIndex);
      const value = entry.value;
      if (entry.type <= 5) item.value = value >>> 0;
      else if (entry.type === 8) { const b = Buffer.alloc(4); b.writeFloatLE(value); item.value = b.readUInt32LE(); }
      else if (entry.type === 10 || entry.type === 11) {
        const bytes = text(value), prefix = entry.type === 11 ? Buffer.from([bytes.length]) : u32(bytes.length);
        if (entry.type === 11 && bytes.length > 16) throw new Error('Fixture resref too long');
        item.value = data(Buffer.concat([prefix, bytes]));
      } else if (entry.type === 12) {
        const bytes = text(value); item.value = data(Buffer.concat([u32(16 + bytes.length), u32(0xffffffff), u32(1), u32(0), u32(bytes.length), bytes]));
      } else if (entry.type === 13) item.value = data(Buffer.concat([u32(value.length), Buffer.from(value)]));
      else if (entry.type === 14) item.value = add(value);
      else if (entry.type === 15) {
        const listOffset = listIndices.length * 4; listIndices.push(value.length, ...Array(value.length).fill(0));
        for (let i = 0; i < value.length; i++) listIndices[listOffset / 4 + 1 + i] = add(value[i]);
        item.value = listOffset;
      } else throw new Error(`Fixture GFF type ${entry.type} is unsupported`);
    }
    return index;
  };
  add(root);
  const structBytes = Buffer.alloc(structs.length * 12);
  structs.forEach((node, index) => {
    structBytes.writeUInt32LE(node.type, index * 12); structBytes.writeUInt32LE(node.indices.length, index * 12 + 8);
    const offset = node.indices.length === 1 ? node.indices[0] : node.indices.length > 1 ? fieldIndices.length * 4 : 0;
    structBytes.writeUInt32LE(offset, index * 12 + 4);
    if (node.indices.length > 1) fieldIndices.push(...node.indices);
  });
  const fieldBytes = Buffer.alloc(fields.length * 12);
  fields.forEach((item, i) => { fieldBytes.writeUInt32LE(item.type, i * 12); fieldBytes.writeUInt32LE(item.label, i * 12 + 4); fieldBytes.writeUInt32LE(item.value, i * 12 + 8); });
  const labelBytes = Buffer.alloc(labels.length * 16); labels.forEach((name, i) => text(name).copy(labelBytes, i * 16));
  const sections = [structBytes, fieldBytes, labelBytes, Buffer.concat(fieldData), Buffer.concat(fieldIndices.map(u32)), Buffer.concat(listIndices.map(u32))];
  const counts = [structs.length, fields.length, labels.length, dataLength, fieldIndices.length * 4, listIndices.length * 4];
  const header = Buffer.alloc(56); header.write(fileType + 'V3.2', 'ascii'); let offset = 56;
  sections.forEach((section, i) => { header.writeUInt32LE(offset, 8 + i * 8); header.writeUInt32LE(counts[i], 12 + i * 8); offset += section.length; });
  return Buffer.concat([header, ...sections]);
}
export function writeMod(resources) {
  const header = Buffer.alloc(160), keys = Buffer.alloc(resources.length * 24), entries = Buffer.alloc(resources.length * 8);
  header.write('MOD V1.0', 'ascii'); header.writeUInt32LE(resources.length, 16);
  header.writeUInt32LE(160, 20); header.writeUInt32LE(160, 24); header.writeUInt32LE(160 + keys.length, 28);
  header.writeUInt32LE(0xffffffff, 40);
  let offset = 160 + keys.length + entries.length;
  resources.forEach(([name, type, bytes], i) => {
    if (text(name).length > 16) throw new Error('Fixture resource name too long');
    text(name).copy(keys, i * 24); keys.writeUInt32LE(i, i * 24 + 16); keys.writeUInt16LE(type, i * 24 + 20);
    entries.writeUInt32LE(offset, i * 8); entries.writeUInt32LE(bytes.length, i * 8 + 4); offset += bytes.length;
  });
  return Buffer.concat([header, keys, entries, ...resources.map(r => r[2])]);
}

// Restricted compiler for the fixture's own call/constant/concat/arithmetic
// AST. Command ordinals come from the installed table, never a guessed API.
export class OracleScript {
  constructor(api) { this.api = new Map(api.map(entry => [entry.name, entry])); this.code = []; }
  byte(...values) { this.code.push(...values.map(value => value & 255)); }
  i32(value) { const b = Buffer.alloc(4); b.writeInt32BE(value | 0); this.byte(...b); }
  expr(node) {
    if (typeof node === 'string') { const bytes = text(node); this.byte(4, 5, bytes.length >>> 8, bytes.length); this.byte(...bytes); }
    else if (typeof node === 'number') { this.byte(4, 3); this.i32(node); }
    else if (typeof node.float === 'number') { const bytes = Buffer.alloc(4); bytes.writeFloatBE(node.float); this.byte(4, 4, ...bytes); }
    else if (node.self) { this.byte(4, 6); this.i32(0); }
    else if (node.call) {
      const spec = this.api.get(node.call); if (!spec || spec.args.length !== node.args.length) throw new Error(`Fixture argument mismatch: ${node.call}`);
      for (const arg of [...node.args].reverse()) this.expr(arg);
      this.byte(5, 0, spec.id >>> 8, spec.id, node.args.length);
    } else if (node.concat) {
      this.expr(node.concat[0]); for (const part of node.concat.slice(1)) { this.expr(part); this.byte(0x14, 0x23); }
    } else if (node.add) { this.expr(node.add[0]); this.expr(node.add[1]); this.byte(0x14, 0x20); }
    else if (node.ge) { this.expr(node.ge[0]); this.expr(node.ge[1]); this.byte(0x0d, 0x20); }
    else if (node.equalString) { this.expr(node.equalString[0]); this.expr(node.equalString[1]); this.byte(0x0b, 0x23); }
    else throw new Error('Unsupported owned oracle AST');
  }
  statement(node) { this.expr(node); }
  patchBranch(at, target) {
    const encoded = Buffer.alloc(4); encoded.writeInt32BE(target - at); this.code.splice(at + 2, 4, ...encoded);
  }
  ifThen(condition, body, otherwise = null) {
    this.expr(condition); const at = this.code.length; this.byte(0x1f, 0); this.i32(0);
    body();
    if (otherwise) {
      const skip = this.code.length; this.byte(0x1d, 0); this.i32(0);
      this.patchBranch(at, this.code.length); otherwise(); this.patchBranch(skip, this.code.length);
    } else this.patchBranch(at, this.code.length);
  }
  finish() {
    this.byte(0x20, 0); const bytes = Buffer.alloc(13 + this.code.length); bytes.write('NCS V1.0', 'ascii'); bytes[8] = 0x42;
    bytes.writeUInt32BE(bytes.length, 9); Buffer.from(this.code).copy(bytes, 13); return bytes;
  }
}
