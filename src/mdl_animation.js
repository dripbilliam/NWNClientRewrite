import { decodeModelOrientation } from './mdl_format.js';
import { BINARY_LIGHT_CHANNELS, LIGHT_PROPERTIES } from './mdl_light.js';
import { BINARY_EMITTER_CHANNELS, EMITTER_ASCII_CHANNELS } from './mdl_emitter.js';
import {readModelControllerStorage} from './model_controller_remap.js';

const CHANNELS = { 8: ['position', 3], 20: ['orientation', 4], 36: ['scale', 1], 100: ['selfillumcolor', 3], 128: ['alpha', 1] };
const MAX_ANIMATION_NODES = 100_000;

export function parseBinaryAnimations(buffer) {
  const data = new DataView(buffer);
  const base = 12;
  const end = base + data.getUint32(4, true);
  const range = (offset, size) => {
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(size) || offset < base || size < 0 || offset + size > end || end > data.byteLength) {
      throw new Error('Binary MDL animation range exceeds model data.');
    }
  };
  const u32 = offset => { range(offset, 4); return data.getUint32(offset, true); };
  const f32 = offset => { range(offset, 4); const v = data.getFloat32(offset, true); if (!Number.isFinite(v)) throw new Error('Non-finite MDL animation value.'); return v; };
  const string = (offset, size) => { range(offset, size); return new TextDecoder('ascii').decode(new Uint8Array(buffer, offset, size)).split('\0')[0]; };
  const array = offset => {
    const result = { offset: base + u32(offset), count: u32(offset + 4) };
    return result;
  };
  const animationArray = array(base + 120);
  range(animationArray.offset, animationArray.count * 4);
  const animations = [];
  const unsupported = new Set();
  let totalNodes = 0;
  for (let index = 0; index < animationArray.count; index += 1) {
    const start = base + u32(animationArray.offset + index * 4);
    range(start, 196);
    const animation = { name: string(start + 8, 64).toLowerCase(), length: f32(start + 112),
      transition: f32(start + 116), root: string(start + 120, 64), tracks: [], events: [] };
    if (animation.length < 0 || animation.transition < 0) throw new Error('Invalid MDL animation duration.');
    const events = array(start + 184);
    range(events.offset, events.count * 36);
    for (let event = 0; event < events.count; event += 1) animation.events.push({
      time: f32(events.offset + event * 36), name: string(events.offset + event * 36 + 4, 32)
    });
    const visited = new Set();
    const rootRelative=u32(start+72),nativeNodes=new Map(),pending = [rootRelative];
    const declared = u32(start + 76);
    while (pending.length) {
      const relative = pending.pop();
      if (visited.has(relative) || visited.size >= declared || ++totalNodes > MAX_ANIMATION_NODES) throw new Error('Invalid MDL animation node hierarchy.');
      visited.add(relative);
      const node = base + relative;
      range(node, 112);
      const name = string(node + 32, 32);
      const flags = u32(node + 108);
      const children = array(node + 72), keys = array(node + 84), values = array(node + 96);
      range(children.offset, children.count * 4);
      range(keys.offset, keys.count * 12);
      range(values.offset, values.count * 4);
      const native=readModelControllerStorage(data,node,range);native.name=name;
      native.childOffsets=Array.from({length:children.count},(_,i)=>u32(children.offset+i*4));native.childCount70=children.count;nativeNodes.set(relative,native);
      for (let child = 0; child < children.count; child += 1) pending.push(u32(children.offset + child * 4));
      for (let key = 0; key < keys.count; key += 1) {
        const at = keys.offset + key * 12;
        const type = u32(at);
        const rows = data.getUint16(at + 4, true), timeIndex = data.getUint16(at + 6, true), valueIndex = data.getUint16(at + 8, true);
        const columns = data.getUint8(at + 10);
        if (!rows || rows === 0xffff) { if (rows === 0xffff) unsupported.add(`controller ${type}: sentinel rows`); continue; }
        // Controller IDs overlap across mesh, light and emitter payloads.
        const channel = flags & 4 && BINARY_EMITTER_CHANNELS[type] ? BINARY_EMITTER_CHANNELS[type] : flags & 2 && BINARY_LIGHT_CHANNELS[type] ? BINARY_LIGHT_CHANNELS[type] : [100,128].includes(type) && !(flags & 0x20) ? null : CHANNELS[type];
        if (!channel || (columns & 0xf) !== channel[1] || (columns & 0xf0) > 0x10 || (type === 20 && columns !== 4)) {
          unsupported.add(`controller ${type} (${columns} columns)`); continue;
        }
        const [property, components] = channel;
        const bezier = (columns & 0xf0) === 0x10;
        const stride = components * (bezier ? 3 : 1);
        if (timeIndex + rows > values.count || valueIndex + rows * stride > values.count) throw new Error('MDL controller indices exceed its value pool.');
        const frames = Array.from({ length: rows }, (_, row) => {
          const time = f32(values.offset + (timeIndex + row) * 4);
          const value = Array.from({ length: components }, (_, c) => f32(values.offset + (valueIndex + row * stride + c) * 4));
          const frame = { time, value: property === 'orientation' ? decodeModelOrientation(value) : value };
          if (bezier) {
            frame.in = Array.from({ length: components }, (_, c) => f32(values.offset + (valueIndex + row * stride + components + c) * 4));
            frame.out = Array.from({ length: components }, (_, c) => f32(values.offset + (valueIndex + row * stride + components * 2 + c) * 4));
          }
          return frame;
        });
        validateFrames(frames);
        animation.tracks.push({ node: name, property, interpolation: bezier ? 'bezier' : property === 'orientation' ? 'slerp' : 'linear', frames });
      }
    }
    for(const native of nativeNodes.values()){native.children68=native.childOffsets.map(offset=>nativeNodes.get(offset));delete native.childOffsets;}
    animation.nativeRoot=nativeNodes.get(rootRelative);
    animations.push(animation);
  }
  return { animations, supermodel: string(base + 168, 64), animationScale: f32(base + 164), unsupportedAnimations: [...unsupported] };
}

export function parseAsciiAnimations(text) {
  const lines = text.replaceAll('\r', '').split('\n');
  const animations = [];
  const unsupported = new Set();
  let animation = null, node = null, nodeType = null;
  const lightNames = Object.fromEntries(Object.entries(LIGHT_PROPERTIES).map(([channel, property]) => [property, channel]));
  let supermodel = '', animationScale = 1;
  for (let index = 0; index < lines.length; index += 1) {
    const tokens = lines[index].trim().split(/\s+/);
    const command = tokens[0].toLowerCase();
    if (!command || command.startsWith('#')) continue;
    if (command === 'setsupermodel') supermodel = tokens[2] ?? '';
    if (command === 'setanimationscale') animationScale = Number(tokens[1]);
    if (command === 'newanim') {
      if (animation) throw new Error('Nested ASCII MDL animation.');
      animation = { name: tokens[1].toLowerCase(), length: 0, transition: 0, root: tokens[2], tracks: [], events: [] };
      animations.push(animation);
    } else if (command === 'doneanim') { animation = null; node = null; }
    else if (animation) {
      if (command === 'length' || command === 'transtime') {
        const value = Number(tokens[1]);
        if (!Number.isFinite(value) || value < 0) throw new Error('Invalid ASCII animation duration.');
        animation[command === 'length' ? 'length' : 'transition'] = value;
      } else if (command === 'animroot') animation.root = tokens[1];
      else if (command === 'event') animation.events.push({ time: Number(tokens[1]), name: tokens.slice(2).join(' ') });
      else if (command === 'node') { node = tokens[2]; nodeType = tokens[1]?.toLowerCase(); }
      else if (command === 'endnode') node = null;
      else if (node) {
        const match = command.match(/^([a-z][a-z0-9_]*?)(bezierkey|key)?$/);
        if (!match) { if (command.endsWith('key')) unsupported.add(command); continue; }
        const emitterChannel=nodeType==='emitter'?EMITTER_ASCII_CHANNELS[match[1]]:null;
        if(!emitterChannel&&!lightNames[match[1]]&&!['position','orientation','scale','alpha','selfillumcolor'].includes(match[1])){if(match[2])unsupported.add(command);continue;}
        if(match[1]==='selfillumcolor'&&!['trimesh','skin','danglymesh','animmesh','aabb'].includes(nodeType)){unsupported.add(command);continue;}
        if (lightNames[match[1]] && nodeType !== 'light') { unsupported.add(command); continue; }
        const property = emitterChannel?.[0] ?? lightNames[match[1]] ?? match[1];
        const components = emitterChannel?.[1] ?? (match[1] === 'color' ? 3 : lightNames[match[1]] ? 1 : { position: 3, orientation: 4, scale: 1, alpha: 1, selfillumcolor: 3 }[property]);
        const bezier = match[2] === 'bezierkey';
        if (bezier && property === 'orientation') { unsupported.add(command); continue; }
        const uncounted = Boolean(match[2] && tokens.length === 1);
        const count = uncounted ? MAX_ANIMATION_NODES : match[2] ? Number(tokens[1]) : 1;
        if (!Number.isInteger(count) || count < 0 || count > MAX_ANIMATION_NODES) throw new Error('Invalid ASCII animation key count.');
        const frames = [];
        for (let row = 0; row < count; row += 1) {
          let values;
          if (!match[2]) values = [0, ...tokens.slice(1).map(Number)];
          else {
            do { index += 1; } while (index < lines.length && (!lines[index].trim() || lines[index].trim().startsWith('#')));
            if (uncounted && lines[index]?.trim().toLowerCase() === 'endlist') break;
            values = (lines[index] ?? '').trim().split(/\s+/).map(Number);
          }
          if (values.length !== 1 + components * (bezier ? 3 : 1) || !values.every(Number.isFinite)) throw new Error(`Invalid ASCII ${command} values.`);
          const raw = values.slice(1, 1 + components);
          const frame = { time: values[0], value: property === 'orientation' ? decodeModelOrientation(raw, 'axis-angle') : raw };
          if (bezier) { frame.in = values.slice(1 + components, 1 + components * 2); frame.out = values.slice(1 + components * 2); }
          frames.push(frame);
        }
        if (uncounted && lines[index]?.trim().toLowerCase() !== 'endlist') throw new Error(`Truncated ASCII ${command} list.`);
        validateFrames(frames);
        if (frames.length) animation.tracks.push({ node, property, interpolation: bezier ? 'bezier' : property === 'orientation' ? 'slerp' : 'linear', frames });
      }
    }
  }
  if (animation) throw new Error('Truncated ASCII MDL animation.');
  if (!Number.isFinite(animationScale) || animationScale < 0) throw new Error('Invalid ASCII animation scale.');
  if (animations.some(clip => clip.events.some(event => !Number.isFinite(event.time) || event.time < 0 || !event.name))) throw new Error('Invalid ASCII animation event.');
  return { animations, supermodel, animationScale, unsupportedAnimations: [...unsupported] };
}

function validateFrames(frames) {
  if (frames.some((frame, index) => frame.time < 0 || (index && frame.time < frames[index - 1].time))) {
    throw new Error('MDL animation keys must have ordered, nonnegative times.');
  }
}

export async function inheritAnimations(model, loadModel, ancestors = []) {
  if (model.animationsInherited) return model;
  const parentName = String(model.supermodel ?? '').toLowerCase();
  if (!parentName || parentName === 'null' || parentName === '****') return model;
  if (ancestors.length >= 16 || ancestors.includes(parentName) || parentName === model.modelName.toLowerCase()) throw new Error('MDL supermodel inheritance cycle.');
  const parent = await loadModel(parentName);
  await inheritAnimations(parent, loadModel, [...ancestors, model.modelName.toLowerCase()]);
  const own = new Set(model.animations.map(animation => animation.name));
  // FindAnimScale140050ed0 multiplies each child's animationScale until the
  // model that owns the clip. The parent's inherited tracks already contain
  // its factor; dividing by that factor cancels race scaling on attached robes.
  const scale = model.animationScale ?? 1;
  model.animations.push(...parent.animations.filter(animation => !own.has(animation.name)).map(animation => ({
    ...animation, inheritedFrom: parentName,
    tracks: animation.tracks.map(track => ({ ...track,
      node: track.node.toLowerCase() === parent.modelName.toLowerCase() ? model.modelName : track.node,
      frames: track.frames.map(frame => track.property === 'position' ? { ...frame,
        value: frame.value.map(v => v * scale), in: frame.in?.map(v => v * scale), out: frame.out?.map(v => v * scale) } : frame)
    }))
  })));
  model.animationsInherited = true;
  model.unsupportedAnimations = [...new Set([...(model.unsupportedAnimations ?? []), ...(parent.unsupportedAnimations ?? []).map(message => `${parentName}: ${message}`)])];
  return model;
}
