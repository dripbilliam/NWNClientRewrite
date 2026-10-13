const HEADER_SIZE = 56;
const MAX_RECORDS = 1_000_000;
const MAX_DEPTH = 128;
const textDecoder = new TextDecoder('windows-1252');
const structTypes = new WeakMap();
// GFF structure type IDs (e.g. equipment slots) are format metadata, not game
// object IDs. Keep them separate from authored fields and from OBJECT_ID.
export function getGffStructType(record) { return structTypes.get(record); }

// Runtime instances must retain format metadata without sharing mutable fields
// with their serialized source (structuredClone loses the WeakMap entries).
export function cloneGff(record, seen = new Map()) {
  if (record === null || typeof record !== 'object') return record;
  if (seen.has(record)) return seen.get(record);
  if (ArrayBuffer.isView(record) || record instanceof ArrayBuffer) return structuredClone(record);
  const result = Array.isArray(record) ? [] : {};
  seen.set(record, result);
  if (structTypes.has(record)) structTypes.set(result, structTypes.get(record));
  for (const [key, value] of Object.entries(record)) result[key] = cloneGff(value, seen);
  return result;
}

export function parseGff(input, expectedType = null) {
  const bytes = toBytes(input);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  requireRange(bytes, 0, HEADER_SIZE, 'GFF header');

  const fileType = readFixedString(bytes, 0, 4);
  const version = readFixedString(bytes, 4, 4);
  if (version !== 'V3.2' && version !== 'V3.3') {
    throw new Error(`Unsupported GFF version ${version}.`);
  }
  if (expectedType && fileType !== expectedType) {
    throw new Error(`Expected ${expectedType} GFF, found ${fileType}.`);
  }

  const header = Array.from({ length: 12 }, (_, index) => view.getUint32(8 + index * 4, true));
  const [structOffset, structCount, fieldOffset, fieldCount, labelOffset, labelCount,
    fieldDataOffset, fieldDataSize, fieldIndicesOffset, fieldIndicesSize,
    listIndicesOffset, listIndicesSize] = header;
  for (const count of [structCount, fieldCount, labelCount, fieldDataSize, fieldIndicesSize, listIndicesSize]) {
    if (count > MAX_RECORDS * 16) throw new Error('GFF table exceeds the supported size.');
  }
  if (structCount === 0 || structCount > MAX_RECORDS || fieldCount > MAX_RECORDS || labelCount > MAX_RECORDS) {
    throw new Error('GFF header contains invalid table counts.');
  }
  if (fieldIndicesSize % 4 !== 0 || listIndicesSize % 4 !== 0) {
    throw new Error('GFF index tables have invalid byte lengths.');
  }
  requireRange(bytes, structOffset, structCount * 12, 'GFF struct table');
  requireRange(bytes, fieldOffset, fieldCount * 12, 'GFF field table');
  requireRange(bytes, labelOffset, labelCount * 16, 'GFF label table');
  requireRange(bytes, fieldDataOffset, fieldDataSize, 'GFF field data');
  requireRange(bytes, fieldIndicesOffset, fieldIndicesSize, 'GFF field indices');
  requireRange(bytes, listIndicesOffset, listIndicesSize, 'GFF list indices');

  const labels = Array.from({ length: labelCount }, (_, index) =>
    readFixedString(bytes, labelOffset + index * 16, 16));
  const structs = Array.from({ length: structCount }, (_, index) => {
    const offset = structOffset + index * 12;
    return {
      id: view.getUint32(offset, true),
      dataOrOffset: view.getUint32(offset + 4, true),
      fieldCount: view.getUint32(offset + 8, true)
    };
  });
  const fields = Array.from({ length: fieldCount }, (_, index) => {
    const offset = fieldOffset + index * 12;
    const type = view.getUint32(offset, true);
    if (type > 18) throw new Error(`Unsupported GFF field type ${type}.`);
    return {
      type,
      labelIndex: view.getUint32(offset + 4, true),
      dataOrOffset: view.getUint32(offset + 8, true)
    };
  });
  const fieldIndices = readUint32Table(view, fieldIndicesOffset, fieldIndicesSize);
  const listIndices = readUint32Table(view, listIndicesOffset, listIndicesSize);
  const structCache = new Map();

  function dataOffset(offset, length, label) {
    if (!Number.isSafeInteger(offset) || offset < 0 || offset + length > fieldDataSize) {
      throw new Error(`${label} points outside GFF field data.`);
    }
    return fieldDataOffset + offset;
  }

  function readSizedString(offset, sizeWidth, label) {
    const position = dataOffset(offset, sizeWidth, label);
    const length = sizeWidth === 1 ? view.getUint8(position) : view.getUint32(position, true);
    if (length > MAX_RECORDS * 16) throw new Error(`${label} string is too large.`);
    const start = dataOffset(offset + sizeWidth, length, label);
    return textDecoder.decode(bytes.subarray(start, start + length));
  }

  function readLocString(offset) {
    const start = dataOffset(offset, 4, 'GFF localized string');
    const size = view.getUint32(start, true);
    if (size < 8) throw new Error('GFF localized string has an invalid size.');
    const body = start + 4;
    requireRange(bytes, body, size, 'GFF localized string body');
    const end = body + size;
    let cursor = body;
    const strRef = view.getUint32(cursor, true);
    const count = view.getUint32(cursor + 4, true);
    cursor += 8;
    if (count > MAX_RECORDS) throw new Error('GFF localized string has too many entries.');
    const entries = [];
    for (let index = 0; index < count; index += 1) {
      if (cursor + 8 > end) throw new Error('GFF localized string entry is truncated.');
      const languageId = view.getUint32(cursor, true);
      const length = view.getUint32(cursor + 4, true);
      cursor += 8;
      if (cursor + length > end) throw new Error('GFF localized string data is truncated.');
      entries.push({ languageId, text: textDecoder.decode(bytes.subarray(cursor, cursor + length)) });
      cursor += length;
    }
    return { strRef, entries };
  }

  function readExtendedUint64(offset, signed, label) {
    const start = dataOffset(offset, 8, label);
    return signed ? view.getBigInt64(start, true) : view.getBigUint64(start, true);
  }

  function readFloatArray(offset, count, label) {
    const start = dataOffset(offset, count * 4, label);
    return Array.from({ length: count }, (_, index) => view.getFloat32(start + index * 4, true));
  }

  function readFieldValue(field, depth) {
    const value = field.dataOrOffset;
    switch (field.type) {
      case 0: return value & 0xff;
      case 1: return (value << 24) >> 24;
      case 2: return value & 0xffff;
      case 3: return (value << 16) >> 16;
      case 4: return value;
      case 5: return value | 0;
      case 6: return readExtendedUint64(value, false, 'GFF uint64');
      case 7: return readExtendedUint64(value, true, 'GFF int64');
      case 8: {
        const scalar = new DataView(new ArrayBuffer(4));
        scalar.setUint32(0, value, true);
        return scalar.getFloat32(0, true);
      }
      case 9: {
        const start = dataOffset(value, 8, 'GFF float64');
        return view.getFloat64(start, true);
      }
      case 10: return readSizedString(value, 4, 'GFF string');
      case 11: return readSizedString(value, 1, 'GFF resref');
      case 12: return readLocString(value);
      case 13: {
        const start = dataOffset(value, 4, 'GFF void');
        const length = view.getUint32(start, true);
        const dataStart = dataOffset(value + 4, length, 'GFF void');
        return bytes.slice(dataStart, dataStart + length);
      }
      case 14: return readStruct(value, depth + 1);
      case 15: {
        if (value % 4 !== 0) throw new Error('GFF list offset is not DWORD-aligned.');
        const index = value / 4;
        if (index >= listIndices.length) throw new Error('GFF list offset is out of range.');
        const count = listIndices[index];
        if (count > MAX_RECORDS || index + count + 1 > listIndices.length) {
          throw new Error('GFF list exceeds the list-index table.');
        }
        return Array.from({ length: count }, (_, item) => readStruct(listIndices[index + item + 1], depth + 1));
      }
      case 16: return readFloatArray(value, 4, 'GFF orientation');
      case 17: return readFloatArray(value, 3, 'GFF vector');
      case 18: {
        const start = dataOffset(value, 4, 'GFF string reference');
        return view.getUint32(start, true);
      }
      default: throw new Error(`Unsupported GFF field type ${field.type}.`);
    }
  }

  function readStruct(index, depth = 0) {
    if (depth > MAX_DEPTH) throw new Error('GFF structure nesting exceeds the supported depth.');
    if (!Number.isInteger(index) || index < 0 || index >= structs.length) {
      throw new Error('GFF struct index is out of range.');
    }
    if (structCache.has(index)) return structCache.get(index);

    const record = structs[index];
    const result = Object.create(null);
    structTypes.set(result, record.id);
    structCache.set(index, result);
    const fieldIds = record.fieldCount === 0
      ? []
      : record.fieldCount === 1
        ? [record.dataOrOffset]
        : (() => {
          if (record.dataOrOffset % 4 !== 0) throw new Error('GFF field-index offset is not DWORD-aligned.');
          const first = record.dataOrOffset / 4;
          if (first + record.fieldCount > fieldIndices.length) throw new Error('GFF struct fields exceed the index table.');
          return fieldIndices.slice(first, first + record.fieldCount);
        })();

    for (const fieldId of fieldIds) {
      if (fieldId >= fields.length) throw new Error('GFF field index is out of range.');
      const field = fields[fieldId];
      if (field.labelIndex >= labels.length) throw new Error('GFF label index is out of range.');
      const label = labels[field.labelIndex];
      if (Object.hasOwn(result, label)) throw new Error(`Duplicate GFF field label ${label}.`);
      result[label] = readFieldValue(field, depth);
    }
    return result;
  }

  return { fileType, version, root: readStruct(0) };
}

function toBytes(input) {
  if (input instanceof Uint8Array) return input;
  if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  if (input instanceof ArrayBuffer) return new Uint8Array(input);
  throw new TypeError('Expected GFF data as an ArrayBuffer or Uint8Array.');
}

function requireRange(bytes, offset, length, label) {
  if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 || offset + length > bytes.byteLength) {
    throw new Error(`${label} is out of range.`);
  }
}

function readUint32Table(view, offset, size) {
  return Array.from({ length: size / 4 }, (_, index) => view.getUint32(offset + index * 4, true));
}

function readFixedString(bytes, offset, length) {
  requireRange(bytes, offset, length, 'GFF string');
  const slice = bytes.subarray(offset, offset + length);
  const end = slice.indexOf(0);
  return new TextDecoder('ascii').decode(end < 0 ? slice : slice.subarray(0, end));
}
