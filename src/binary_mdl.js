import { parseBinaryAnimations } from './mdl_animation.js';
import { BINARY_LIGHT_CHANNELS, LIGHT_PROPERTIES } from './mdl_light.js';
import { BINARY_EMITTER_CHANNELS, EMITTER_FLAGS } from './mdl_emitter.js';
import {readModelControllerStorage} from './model_controller_remap.js';

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

  function readNode(relativeOffset, parentName = 'NULL', parentIndex = -1) {
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
      nativeNode:readModelControllerStorage(data,start,(at,size)=>{requireRange(data,at,size);if(at<modelDataOffset||at+size>modelDataOffset+modelDataSize)throw new Error('Binary MDL controller storage exceeds model data.');}),
      unsupportedFeatures: [
        [FLAG_HAS_EMITTER, 'Emitter runtime simulation'],
        [FLAG_HAS_REFERENCE, 'Referenced model attachment'], [FLAG_HAS_ANIM, 'Animated vertex/UV channels'],
        [FLAG_HAS_DANGLY, 'Dangly-mesh simulation']
      ].filter(([flag]) => flags & flag).map(([, feature]) => feature),
      type: flags & FLAG_HAS_MESH ? 'trimesh' : flags & FLAG_HAS_LIGHT ? 'light' : flags & FLAG_HAS_EMITTER ? 'emitter' : flags & FLAG_HAS_REFERENCE ? 'reference' : 'dummy',
      properties: Object.assign(Object.create(null), flags & FLAG_HAS_LIGHT ? { color: [0,0,0], radius: 0, shadowradius: 0, verticaldisplacement: 0, multiplier: 1 } : {}),
      name,
      parent: parentName,
      parentIndex,
      position: [0, 0, 0],
      orientation: [0, 0, 0, 1],
      scale: 1,
      alpha: 1,
      bitmap: '',
      ambient: null,
      diffuse: null,
      specular: null,
      shininess: 0,
      render: true,
      textureLayers: [],
      skinned: false,
      skinData: null,
      verts: [],
      tverts: [],
      tvertsByLayer: [],
      faces: []
    };
    readStaticControllers(node, controllerKeys, controllerValues);

    let cursor = start + 112;
    if (flags & FLAG_HAS_LIGHT) { readLight(node, cursor); cursor += 0x5c; }
    if (flags & FLAG_HAS_EMITTER) { readEmitter(node,cursor); cursor += 0xd8; }
    if (flags & FLAG_HAS_REFERENCE) {readReference(node,cursor);cursor += 0x44;}
    if (flags & FLAG_HAS_MESH) cursor = readMesh(node, cursor);
    if (flags & FLAG_HAS_SKIN) {
      node.skinned = true;
      node.skinData = readSkin(node, cursor);
      cursor += SKIN_EXTENSION_SIZE;
    }
    if (flags & FLAG_HAS_ANIM) cursor += 56;
    if (flags & FLAG_HAS_DANGLY) cursor += 0x18;
    if (flags & FLAG_HAS_AABB) cursor += 4;
    requireRange(data, start, cursor - start);

    const nodeIndex=nodes.length;nodes.push(node);
    const childBytes = children.count * 4;
    requireRange(data, modelDataOffset + children.offset, childBytes);
    for (let index = 0; index < children.count; index += 1) {
      const child=readNode(readU32(data, modelDataOffset + children.offset + index * 4), name,nodeIndex);node.nativeNode.children68.push(child.nativeNode);
    }
    node.nativeNode.childCount70=children.count;return node;
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
      // Controller IDs overlap with emitter fields; 128 is opacity only on meshes.
      else if (type === 128 && columns === 1 && node.type === 'trimesh') node.alpha = valuesAtTime[0];
      else if (node.type === 'light' && BINARY_LIGHT_CHANNELS[type]?.[1] === columns) {
        node.properties[LIGHT_PROPERTIES[BINARY_LIGHT_CHANNELS[type][0]]] = columns === 1 ? valuesAtTime[0] : valuesAtTime;
      }
      else if (node.type === 'emitter' && BINARY_EMITTER_CHANNELS[type]?.[1] === columns) {
        node.properties[BINARY_EMITTER_CHANNELS[type][0].slice(8)] = columns === 1 ? valuesAtTime[0] : valuesAtTime;
      }
    }
  }

  function readReference(node,cursor){
    // ReadBinaryNode07b3dc..07b416 copies disk70..af -> runtimea0..df,
    // diskb0 DWORD -> runtimee0. A model name is64 bytes, not CResRef16.
    requireRange(data,cursor,0x44);
    const rawModel=Array.from(new Uint8Array(data.buffer,data.byteOffset+cursor,64));
    node.reference={model:readString(data,cursor,64),rawModel,reattachable:readU32(data,cursor+64)|0};
    node.properties.refmodel=node.reference.model;node.properties.reattachable=node.reference.reattachable;
    node.nativeNode.referenceModelA0=rawModel;node.nativeNode.reattachableE0=node.reference.reattachable;
  }

  function readLight(node, cursor) {
    // Full serialized reader14007a790..14007abd4: flags at node+b0..c8.
    // Runtime light texture handles are constructed, never serialized pointers.
    requireRange(data, cursor, 0x5c);
    node.properties.flareradius = readF32(data, cursor);
    for (const [index, name] of ['lightpriority', 'ambientonly', 'isdynamic', 'affectdynamic', 'shadow', 'generateflare', 'fadinglight'].entries()) {
      node.properties[name] = readU32(data, cursor + 64 + index * 4);
    }
    // Keep unresolved flare payloads visible to diagnostics. The renderer does
    // not yet implement native lens flare texture/occlusion/fade passes.
    if (node.properties.generateflare || [4,16,28,40,52].some(at => readU32(data, cursor + at + 4))) {
      node.unsupportedFeatures.push('Light lens flare presentation');
    }
  }

  function readEmitter(node,cursor) {
    // Complete ReadBinaryNode14007abe0 emitter branch14007b13f..14007b28a.
    // The ASCII parse-field owner independently names the runtime destinations.
    requireRange(data,cursor,0xd8);const p=node.properties;
    for(const [i,name]of ['deadspace','blastradius','blastlength'].entries())p[name]=readF32(data,cursor+i*4);
    for(const [i,name]of ['xgrid','ygrid','spawntype'].entries())p[name]=readU32(data,cursor+12+i*4);
    for(const [offset,size,name]of [[24,32,'update'],[56,32,'render'],[88,32,'blend'],[120,64,'texture'],[184,16,'chunkname']])p[name]=readString(data,cursor+offset,size);
    p.twosidedtex=readU32(data,cursor+200);p.loop=readU32(data,cursor+204);p.renderorder=readU16(data,cursor+208);p.flags=readU32(data,cursor+212);
    for(const [name,mask]of Object.entries(EMITTER_FLAGS))p[name]=Number((p.flags&mask)!==0);
  }

  function readMesh(node, cursor) {
    const meshStart = cursor;
    // Original header copier078ab0: disk268 -> runtime2bc (stored area).
    // Relative to the mesh extension this is1f8, independent of skin payload.
    requireRange(data,meshStart+0x1f8,4);node.nativeTriMeshArea=readF32(data,meshStart+0x1f8);
    cursor += 8;
    const faces = readArrayDefinition(cursor);
    cursor += 12;
    cursor += 24 + 4 + 12;
    node.ambient = Array.from({ length: 3 }, (_, index) => readF32(data, cursor + index * 4));
    cursor += 12;
    node.diffuse = Array.from({ length: 3 }, (_, index) => readF32(data, cursor + index * 4));
    cursor += 12;
    node.specular = Array.from({ length: 3 }, (_, index) => readF32(data, cursor + index * 4));
    cursor += 12;
    node.shininess = readF32(data, cursor);
    cursor += 4;
    node.shadow = readU32(data, cursor) === 1;
    node.beaming = readU32(data, cursor + 4) === 1;
    node.render = readU32(data, cursor + 8) === 1;
    node.transparencyHint = readU32(data, cursor + 12) === 1;
    cursor += 16 + 4;
    const textureNamesOffset = cursor;
    cursor += 64 * 4;
    cursor += 4 + 12 + 12;
    const drawCounts = readArrayDefinition(cursor); cursor += 12;
    const drawOffsets = readArrayDefinition(cursor); cursor += 12 + 8;
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

    if (isEmptyBinaryMeshRecord(triangleMode, faces.count, vertexCount, textureCount)) {
      return cursor;
    }
    if (triangleMode !== 3) throw new Error(`Binary mesh ${node.name} has mode ${triangleMode} at 0x${triangleModeOffset.toString(16)} (mesh 0x${meshStart.toString(16)}).`);
    if (!vertexCount || (!faces.count && !drawOffsets.count) || vertexCount > 1000000 || faces.count > 1000000) {
      throw new Error(`Invalid binary mesh counts in ${node.name}.`);
    }
    requireRange(data, rawDataOffset + vertexOffset, vertexCount * 12);
    requireRange(data, modelDataOffset + faces.offset, faces.count * 32);

    const textureLayerCount = Math.min(textureCount, 4);
    node.textureLayers = Array.from({ length: textureLayerCount }, (_, index) =>
      readString(data, textureNamesOffset + index * 64, 64));
    node.bitmap = node.textureLayers[0] && node.textureLayers[0].toLowerCase() !== 'null'
      ? node.textureLayers[0]
      : '';
    node.verts = Array.from({ length: vertexCount }, (_, index) => {
      const offset = rawDataOffset + vertexOffset + index * 12;
      return [readF32(data, offset), readF32(data, offset + 4), readF32(data, offset + 8)];
    });

    node.tvertsByLayer = textureOffsets.slice(0, textureLayerCount).map((textureOffset) => {
      if (textureOffset === 0xffffffff) return [];
      requireRange(data, rawDataOffset + textureOffset, vertexCount * 8);
      return Array.from({ length: vertexCount }, (_, index) => {
        const offset = rawDataOffset + textureOffset + index * 8;
        return [readF32(data, offset), readF32(data, offset + 4), 0];
      });
    });
    node.tverts = node.tvertsByLayer[0] ?? [];

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
    // ReadBinaryMesh7be10 copies MaxFace records unchanged (32 bytes each).
    // PartTriMesh::HitCheckGeom905b0 uses these, not the optimized draw list.
    node.nativeCollisionFaces=node.faces.map((face,index)=>{
      const at=modelDataOffset+faces.offset+index*32;
      return{indices:face.slice(0,3),normal:[0,4,8].map(n=>readF32(data,at+n)),constant:readF32(data,at+12),surfaceType:readU32(data,at+16)};
    });

    // FUN_14007be10 loads draw counts at serialized node +0x204 and
    // raw-data index offsets at +0x210 into runtime +0x248/+0x258.
    // Optimized/combined meshes retain only the original MaxFace list;
    // the draw buffers include the additional joined geometry.
    if (drawOffsets.count) {
      if (drawOffsets.count !== drawCounts.count || drawOffsets.count > 1000000)
        throw new Error(`Invalid binary draw groups in ${node.name}.`);
      requireRange(data, modelDataOffset + drawCounts.offset, drawCounts.count * 4);
      requireRange(data, modelDataOffset + drawOffsets.offset, drawOffsets.count * 4);
      const renderedFaces = [];
      for (let group = 0; group < drawOffsets.count; group++) {
        const count = readU32(data, modelDataOffset + drawCounts.offset + group * 4);
        const offset = rawDataOffset + readU32(data, modelDataOffset + drawOffsets.offset + group * 4);
        if (count % 3 || count > 3000000) throw new Error(`Invalid binary triangle-list draw count in ${node.name}.`);
        requireRange(data, offset, count * 2);
        for (let index = 0; index < count; index += 3) {
          const indices = [0, 1, 2].map(corner => readU16(data, offset + (index + corner) * 2));
          if (indices.some(vertex => vertex >= vertexCount)) throw new Error(`Binary draw index outside ${node.name} vertex array.`);
          renderedFaces.push([...indices, 0, ...indices, 0]);
        }
      }
      node.faces = renderedFaces;
    }

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

  const nativeRoot=readNode(rootOffset).nativeNode;
  let animationMetadata;
  try { animationMetadata = parseBinaryAnimations(buffer); }
  catch (error) { animationMetadata = { animations: [], supermodel: readString(data, modelDataOffset + 168, 64), animationScale: 1, unsupportedAnimations: [error.message] }; }
  return {
    modelName,
    ...animationMetadata,
    format: 'Binary MDL',
    nodes,
    nativeRoot,
    hasSkinnedMeshes: nodes.some((node) => node.skinned),
    materialNames: [...new Set(nodes
      .flatMap((node) => node.type === 'trimesh' ? node.textureLayers.length ? node.textureLayers : [node.bitmap] : node.type === 'emitter' ? [node.properties.texture] : [])
      .filter((name) => name && name.toLowerCase() !== 'null'))]
  };
}

export function isEmptyBinaryMeshRecord(triangleMode, faceCount, vertexCount, textureCount) {
  return triangleMode === 0 && faceCount === 0 && vertexCount === 0 && textureCount === 0;
}

function requireRange(data, offset, length) {
  if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 || offset + length > data.byteLength) {
    throw new Error(`Binary MDL range 0x${offset.toString(16)} + 0x${length.toString(16)} exceeds file size 0x${data.byteLength.toString(16)}.`);
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
