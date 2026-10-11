const SUPPORTED_NODE_FLAGS = 0x000003f7;
const FLAG_HAS_LIGHT = 0x00000002;
const FLAG_HAS_EMITTER = 0x00000004;
const FLAG_HAS_REFERENCE = 0x00000010;
const FLAG_HAS_MESH = 0x00000020;
const FLAG_HAS_SKIN = 0x00000040;
const FLAG_HAS_ANIM = 0x00000080;
const FLAG_HAS_DANGLY = 0x00000100;
const FLAG_HAS_AABB = 0x00000200;
const RESOURCE_TYPE = { TGA: 3, MDL: 2002, DDS: 2033 };
const SKIN_EXTENSION_SIZE = 0x000000c0;

export function parseBinaryMdl(buffer) {
  const data = new DataView(buffer);
  const modelDataOffset = 12;
  const modelDataSize = readU32(data, 4);
  const rawDataOffset = modelDataOffset + modelDataSize;
  const rawDataSize = readU32(data, 8);
  const rootOffset = readU32(data, 84);
  const declaredNodeCount = readU32(data, 88);
  const modelName = readString(data, 20, 64);

  requireRange(data, modelDataOffset, modelDataSize + rawDataSize);
  if (!modelName || !declaredNodeCount || declaredNodeCount > 100000) {
    throw new Error('Invalid binary MDL header.');
  }

  const nodes = [];
  const visited = new Set();

  function readArrayDefinition(offset) {
    return {
      offset: readU32(data, offset),
      count: readU32(data, offset + 4),
      allocated: readU32(data, offset + 8)
    };
  }

  function readNode(relativeOffset, parentName = 'NULL') {
    if (nodes.length >= declaredNodeCount) throw new Error('Binary MDL node count exceeded.');
    if (visited.has(relativeOffset)) throw new Error('Binary MDL node cycle detected.');
    visited.add(relativeOffset);

    const start = modelDataOffset + relativeOffset;
    requireRange(data, start, 112);
    const name = readString(data, start + 32, 32);
    const children = readArrayDefinition(start + 72);
    const controllerKeys = readArrayDefinition(start + 84);
    const controllerValues = readArrayDefinition(start + 96);
    const flags = readU32(data, start + 108);
    if ((flags & ~SUPPORTED_NODE_FLAGS) !== 0) {
      throw new Error(`Unsupported binary MDL node flags 0x${flags.toString(16)} in ${name}.`);
    }

    const node = {
      type: flags & FLAG_HAS_MESH ? 'trimesh' : 'dummy',
      name,
      parent: parentName,
      position: [0, 0, 0],
      orientation: [0, 0, 0, 1],
      scale: 1,
      bitmap: '',
      skinned: false,
      skinData: null,
      verts: [],
      tverts: [],
      faces: []
    };
    readStaticControllers(node, controllerKeys, controllerValues);

    let cursor = start + 112;
    if (flags & FLAG_HAS_LIGHT) cursor += 0x5c;
    if (flags & FLAG_HAS_EMITTER) cursor += 0xd8;
    if (flags & FLAG_HAS_REFERENCE) cursor += 0x44;
    if (flags & FLAG_HAS_MESH) cursor = readMesh(node, cursor);
    if (flags & FLAG_HAS_SKIN) {
      node.skinned = true;
      node.skinData = readSkin(node, cursor);
      cursor += SKIN_EXTENSION_SIZE;
    }
    if (flags & FLAG_HAS_ANIM) cursor += 56;
    if (flags & FLAG_HAS_DANGLY) throw new Error(`Dangly binary meshes are not supported yet (${name}).`);
    if (flags & FLAG_HAS_AABB) cursor += 4;
    requireRange(data, start, cursor - start);

    nodes.push(node);
    const childBytes = children.count * 4;
    requireRange(data, modelDataOffset + children.offset, childBytes);
    for (let index = 0; index < children.count; index += 1) {
      readNode(readU32(data, modelDataOffset + children.offset + index * 4), name);
    }
  }

  function readStaticControllers(node, keys, values) {
    if (keys.count === 0 || values.count === 0) return;
    requireRange(data, modelDataOffset + keys.offset, keys.count * 12);
    requireRange(data, modelDataOffset + values.offset, values.count * 4);
    const controllerData = Array.from({ length: values.count }, (_, index) =>
      readF32(data, modelDataOffset + values.offset + index * 4));

    for (let index = 0; index < keys.count; index += 1) {
      const offset = modelDataOffset + keys.offset + index * 12;
      const type = readU32(data, offset);
      const rows = readU16(data, offset + 4);
      const timeIndex = readU16(data, offset + 6);
      const valueIndex = readU16(data, offset + 8);
      const columns = data.getUint8(offset + 10);
      if (!rows || rows === 0xffff || !columns || timeIndex >= controllerData.length) continue;
      if (controllerData[timeIndex] !== 0) continue;
      const valuesAtTime = controllerData.slice(valueIndex, valueIndex + columns);
      if (valuesAtTime.length !== columns || valuesAtTime.some((value) => !Number.isFinite(value))) continue;
      if (type === 8 && columns === 3) node.position = valuesAtTime;
      else if (type === 20 && columns === 4) node.orientation = valuesAtTime;
      else if (type === 36 && columns === 1) node.scale = valuesAtTime[0];
    }
  }

  function readMesh(node, cursor) {
    const meshStart = cursor;
    cursor += 8;
    const faces = readArrayDefinition(cursor);
    cursor += 12;
    cursor += 24 + 4 + 12 + 12 + 12 + 12 + 4;
    cursor += 16 + 4;
    const textureNamesOffset = cursor;
    cursor += 64 * 4;
    cursor += 4 + 12 + 12 + 12 + 12 + 8;
    const triangleModeOffset = cursor;
    const triangleMode = data.getUint8(cursor);
    cursor += 1 + 3 + 4;
    const vertexOffset = readU32(data, cursor);
    const vertexCount = readU16(data, cursor + 4);
    const textureCount = readU16(data, cursor + 6);
    cursor += 8;
    const textureOffsets = Array.from({ length: 4 }, (_, index) => readU32(data, cursor + index * 4));
    cursor += 16;
    const normalOffset = readU32(data, cursor);
    cursor += 4;
    const colorOffset = readU32(data, cursor);
    cursor += 4 + 24 + 1 + 1 + 2 + 4 + 4;

    if (triangleMode !== 3) throw new Error(`Binary mesh ${node.name} has mode ${triangleMode} at 0x${triangleModeOffset.toString(16)} (mesh 0x${meshStart.toString(16)}).`);
    if (!vertexCount || !faces.count || vertexCount > 1000000 || faces.count > 1000000) {
      throw new Error(`Invalid binary mesh counts in ${node.name}.`);
    }
    requireRange(data, rawDataOffset + vertexOffset, vertexCount * 12);
    requireRange(data, modelDataOffset + faces.offset, faces.count * 32);

    const textureName = readString(data, textureNamesOffset, 64);
    node.bitmap = textureName && textureName.toLowerCase() !== 'null' ? textureName : '';
    node.verts = Array.from({ length: vertexCount }, (_, index) => {
      const offset = rawDataOffset + vertexOffset + index * 12;
      return [readF32(data, offset), readF32(data, offset + 4), readF32(data, offset + 8)];
    });

    if (textureCount > 0 && textureOffsets[0] !== 0xffffffff) {
      requireRange(data, rawDataOffset + textureOffsets[0], vertexCount * 8);
      node.tverts = Array.from({ length: vertexCount }, (_, index) => {
        const offset = rawDataOffset + textureOffsets[0] + index * 8;
        return [readF32(data, offset), readF32(data, offset + 4), 0];
      });
    }

    node.faces = Array.from({ length: faces.count }, (_, index) => {
      const offset = modelDataOffset + faces.offset + index * 32 + 26;
      const a = readU16(data, offset);
      const b = readU16(data, offset + 2);
      const c = readU16(data, offset + 4);
      if (a >= vertexCount || b >= vertexCount || c >= vertexCount) {
        throw new Error(`Binary face index outside ${node.name} vertex array.`);
      }
      return [a, b, c, 0, a, b, c, 0];
    });

    if (normalOffset !== 0xffffffff) requireRange(data, rawDataOffset + normalOffset, vertexCount * 12);
    if (colorOffset !== 0xffffffff) requireRange(data, rawDataOffset + colorOffset, vertexCount * 4);
    return cursor;
  }

  function readSkin(node, cursor) {
    requireRange(data, cursor, SKIN_EXTENSION_SIZE);
    const vertexCount = node.verts.length;
    const weightsOffset = readU32(data, cursor + 0x0c);
    const boneIndicesOffset = readU32(data, cursor + 0x10);
    const boneIndexTableOffset = readU32(data, cursor + 0x14);
    const boneIndexTableCount = readU32(data, cursor + 0x18);
    const qboneOffset = readU32(data, cursor + 0x1c);
    const qboneCount = readU32(data, cursor + 0x20);
    const tboneOffset = readU32(data, cursor + 0x28);
    const tboneCount = readU32(data, cursor + 0x2c);
    const boneConstantOffset = readU32(data, cursor + 0x34);
    const boneConstantCount = readU32(data, cursor + 0x38);

    requireRange(data, rawDataOffset + weightsOffset, vertexCount * 16);
    requireRange(data, rawDataOffset + boneIndicesOffset, vertexCount * 8);
    requireRange(data, modelDataOffset + boneIndexTableOffset, boneIndexTableCount * 2);
    requireRange(data, modelDataOffset + qboneOffset, qboneCount * 16);
    requireRange(data, modelDataOffset + tboneOffset, tboneCount * 12);
    requireRange(data, modelDataOffset + boneConstantOffset, boneConstantCount * 4);

    return {
      weights: Array.from({ length: vertexCount }, (_, vertexIndex) => {
        const offset = rawDataOffset + weightsOffset + vertexIndex * 16;
        return Array.from({ length: 4 }, (_, component) => readF32(data, offset + component * 4));
      }),
      boneIndices: Array.from({ length: vertexCount }, (_, vertexIndex) => {
        const offset = rawDataOffset + boneIndicesOffset + vertexIndex * 8;
        return Array.from({ length: 4 }, (_, component) => readU16(data, offset + component * 2));
      }),
      boneIndexTable: Array.from({ length: boneIndexTableCount }, (_, index) =>
        readU16(data, modelDataOffset + boneIndexTableOffset + index * 2)),
      qboneRefInv: readVectorArray(qboneOffset, qboneCount, 4),
      tboneRefInv: readVectorArray(tboneOffset, tboneCount, 3),
      boneConstantIndices: Array.from({ length: boneConstantCount }, (_, index) =>
        data.getInt32(modelDataOffset + boneConstantOffset + index * 4, true)),
      boneConstantSlots: Array.from({ length: 64 }, (_, index) =>
        data.getInt16(cursor + 0x40 + index * 2, true))
    };
  }

  function readVectorArray(offset, count, components) {
    return Array.from({ length: count }, (_, index) => {
      const start = modelDataOffset + offset + index * components * 4;
      return Array.from({ length: components }, (_, component) => readF32(data, start + component * 4));
    });
  }

  readNode(rootOffset);
  if (nodes.length !== declaredNodeCount) {
    throw new Error(`Binary MDL declares ${declaredNodeCount} nodes, parsed ${nodes.length}.`);
  }
  return {
    modelName,
    format: 'Binary MDL',
    nodes,
    hasSkinnedMeshes: nodes.some((node) => node.skinned),
    materialNames: [...new Set(nodes.filter((node) => node.type === 'trimesh' && node.bitmap).map((node) => node.bitmap))]
  };
}

function requireRange(data, offset, length) {
  if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 || offset + length > data.byteLength) {
    throw new Error('Binary MDL contains an out-of-range offset.');
  }
}

function readU16(data, offset) {
  requireRange(data, offset, 2);
  return data.getUint16(offset, true);
}

function readU32(data, offset) {
  requireRange(data, offset, 4);
  return data.getUint32(offset, true);
}

function readF32(data, offset) {
  requireRange(data, offset, 4);
  return data.getFloat32(offset, true);
}

function readString(data, offset, length) {
  requireRange(data, offset, length);
  const bytes = new Uint8Array(data.buffer, data.byteOffset + offset, length);
  const end = bytes.indexOf(0);
  return new TextDecoder('ascii').decode(end < 0 ? bytes : bytes.subarray(0, end));
}
