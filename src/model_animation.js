import * as THREE from 'three';
import { runtimeDiagnostics } from './runtime_diagnostics.js';

const BASIS = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2);
const INVERSE_BASIS = BASIS.clone().invert();

export function sampleTrack(track, time) {
  const frames = track.frames;
  if (!frames.length) return null;
  if (time <= frames[0].time) return [...frames[0].value];
  if (time >= frames.at(-1).time) return [...frames.at(-1).value];
  let index = 1;
  while (frames[index].time < time) index += 1;
  const from = frames[index - 1], to = frames[index];
  const t = (time - from.time) / (to.time - from.time);
  if (track.interpolation === 'slerp') {
    return new THREE.Quaternion(...from.value).slerp(new THREE.Quaternion(...to.value), t).normalize().toArray();
  }
  return from.value.map((value, component) => {
    if (track.interpolation !== 'bezier') return value + (to.value[component] - value) * t;
    const a = value + from.out[component], b = to.value[component] + to.in[component];
    return (1 - t) ** 3 * value + 3 * (1 - t) ** 2 * t * a + 3 * (1 - t) * t * t * b + t ** 3 * to.value[component];
  });
}

export class ModelAnimator {
  constructor(model, root, updateSkin = null) {
    this.model = model;
    this.root = root;
    this.updateSkin = updateSkin;
    this.bindings = new Map();
    this.clip = null;
    this.time = 0;
    this.playing = false;
    this.loop = true;
    this.onComplete = null;
    const names = new Set(model.nodes.map(node => node.name.toLowerCase()));
    root.traverse(object => {
      const name = object.userData.mdlNode?.toLowerCase();
      if (!name || object.userData.mdlModel?.toLowerCase() !== model.modelName.toLowerCase() || !names.has(name) || this.bindings.has(name)) return;
      const materials = object.children.filter(child => child.isMesh).flatMap(mesh => {
        // Opacity tracks must not modify another instance's shared materials.
        const hasAlpha = model.animations.some(animation => animation.tracks.some(track => track.node.toLowerCase() === name && track.property === 'alpha'));
        if (hasAlpha) mesh.material = Array.isArray(mesh.material) ? mesh.material.map(material => material.clone()) : mesh.material.clone();
        return (Array.isArray(mesh.material) ? mesh.material : [mesh.material]).map(material => ({ material, opacity: material.opacity, visible:material.visible, transparent: material.transparent, depthWrite: material.depthWrite }));
      });
      this.bindings.set(name, { object, position: object.position.clone(), quaternion: object.quaternion.clone(), scale: object.scale.clone(), materials });
    });
    this.missingNodes = [];
    this.reportedMissing = new Set();
  }

  reset() {
    for (const binding of this.bindings.values()) {
      binding.object.position.copy(binding.position);
      binding.object.quaternion.copy(binding.quaternion);
      binding.object.scale.copy(binding.scale);
      for (const saved of binding.materials) {
        saved.material.opacity = saved.opacity;
        saved.material.visible = saved.visible;
        saved.material.transparent = saved.transparent;
        saved.material.depthWrite = saved.depthWrite;
      }
    }
  }

  apply(clip, time) {
    this.reset();
    const missing = new Set();
    for (const track of clip?.tracks ?? []) {
      const binding = this.bindings.get(track.node.toLowerCase());
      if (!binding) { missing.add(track.node); continue; }
      const value = sampleTrack(track, time);
      if (!value) continue;
      if (track.property === 'position') binding.object.position.set(value[0], value[2], -value[1]);
      else if (track.property === 'orientation') binding.object.quaternion.copy(BASIS).multiply(new THREE.Quaternion(...value)).multiply(INVERSE_BASIS);
      else if (track.property === 'scale') binding.object.scale.setScalar(value[0]);
      else if (track.property === 'alpha') for (const { material, transparent, depthWrite } of binding.materials) {
        material.opacity = Math.max(0, Math.min(1, value[0]));
        if (material.userData.mdlOpacityDriven) material.visible = material.opacity > 0;
        const authoredHint = material.userData.mdlTransparencyHint;
        material.transparent = (authoredHint ?? transparent) || material.opacity < 1;
        material.depthWrite = (authoredHint === undefined ? depthWrite : !authoredHint) && material.opacity >= 1;
        if (material.userData.animationTransparent !== material.transparent) {
          material.needsUpdate = true;
          material.userData.animationTransparent = material.transparent;
        }
      }
    }
    this.missingNodes = [...missing];
    for (const node of missing) {
      const key = `${clip.name}:${node}`;
      if (!this.reportedMissing.has(key)) { this.reportedMissing.add(key); runtimeDiagnostics.record('animation.node-unavailable', `Animation ${clip.name} has no binding for ${node}`, { model: this.model.modelName, instance: this.root.name, clip: clip.name, node }); }
    }
    // Refresh blend programs when switching back to a clip without alpha tracks.
    for (const binding of this.bindings.values()) for (const { material } of binding.materials) {
      if (material.userData.animationTransparent !== undefined && material.userData.animationTransparent !== material.transparent) {
        material.needsUpdate = true;
        material.userData.animationTransparent = material.transparent;
      }
    }
    this.root.updateWorldMatrix(true, true);
    this.updateSkin?.();
    this.root.userData.animationClip = clip?.name ?? '';
    this.root.userData.animationTime = time;
  }

  play(name, { loop = true, onComplete = null } = {}) {
    const clip = this.model.animations.find(animation => animation.name === String(name).toLowerCase());
    if (!clip) { runtimeDiagnostics.record('animation.clip-unavailable', `Animation ${name} is unavailable`, { model: this.model.modelName, instance: this.root.name, clip: name }); return false; }
    this.clip = clip;
    this.time = 0;
    this.loop = loop;
    this.onComplete = onComplete;
    this.playing = clip.length > 0;
    this.apply(clip, 0);
    return true;
  }

  pose(name) {
    if (!this.play(name, { loop: false })) return false;
    this.time = this.clip.length;
    this.apply(this.clip, this.time);
    this.playing = false;
    return true;
  }

  update(delta) {
    if (!this.playing || !this.clip || !Number.isFinite(delta) || delta < 0) return;
    this.time += delta;
    if (this.loop) this.time %= this.clip.length;
    else this.time = Math.min(this.time, this.clip.length);
    this.apply(this.clip, this.time);
    if (!this.loop && this.time >= this.clip.length) {
      this.playing = false;
      const callback = this.onComplete;
      this.onComplete = null;
      callback?.();
    }
  }
}
