import * as THREE from 'three';
import { DiagnosticWarnings, runtimeDiagnostics } from './runtime_diagnostics.js';
import { TGALoader } from 'three/addons/loaders/TGALoader.js';
import { parseModel } from './model_parser.js';
import { decodeModelOrientation } from './mdl_format.js';
import { parseGff } from './gff.js';
import { RESOURCE_TYPE } from './resource_archive.js';
import { sampleTrack } from './model_animation.js';
import {modelParentIndices} from './model_hierarchy.js';

export const UI_PIXELS_PER_UNIT = 100;

// NWN GUI is a model hierarchy, not a collection of flat background images.
// Render its actual MDL/UVs unlit in the source XY plane, preserving node hooks.
export function buildUiModel(model, textures = new Map()) {
  const root = new THREE.Group(), groups = new Map(),nodeGroups=new Map(),parents=modelParentIndices(model);
  for (const node of model.nodes) {
    const group = new THREE.Group(); group.name = node.name;
    group.position.fromArray(node.position); group.scale.setScalar(node.scale ?? 1);
    group.quaternion.fromArray(decodeModelOrientation(node.orientation, node.orientationFormat)); groups.set(node.name, group);nodeGroups.set(node,group);
    if (node.type !== 'trimesh' || node.render === false || node.properties?.render === 0 || !node.faces.length) continue;
    const positions = [], uvs = [];
    for (const face of node.faces) for (let i = 0; i < 3; i++) {
      positions.push(...node.verts[face[i]]); uvs.push(...(node.tverts[face[4 + i]] ?? [0, 0]).slice(0, 2));
    }
    const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3)); geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    const texture = textures.get(node.bitmap?.toLowerCase());
    const diffuse = node.diffuse ?? node.properties?.diffuse ?? [.1, .1, .1];
    const material = new THREE.MeshBasicMaterial({ map: texture ?? null, color: texture ? 0xffffff : new THREE.Color(...diffuse), transparent: true, opacity: node.alpha ?? 1, side: THREE.DoubleSide, depthWrite: false });
    group.add(new THREE.Mesh(geometry, material));
  }
  for (const [i,node] of model.nodes.entries()) (nodeGroups.get(model.nodes[parents[i]]) ?? root).add(nodeGroups.get(node));
  root.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(root), hooks = new Map();
  for (const [name, group] of groups) hooks.set(name.toLowerCase(), group.getWorldPosition(new THREE.Vector3()).toArray());
  const bindings = new Map(model.nodes.map(n => { const group = groups.get(n.name); return [n.name.toLowerCase(), { group, position: group.position.clone(), quaternion: group.quaternion.clone(), scale: group.scale.clone(), alpha: n.alpha ?? 1 }]; }));
  return { root, bounds, hooks, model, bindings };
}

export function poseUiModel(ui, state = 'up') {
  for (const binding of ui.bindings.values()) {
    const g = binding.group; g.position.copy(binding.position); g.quaternion.copy(binding.quaternion); g.scale.copy(binding.scale);
    for (const child of g.children) if (child.isMesh) { child.material.opacity = binding.alpha; child.visible = binding.alpha > 0; }
  }
  const clip = ui.model.animations?.find(a => a.name === state) ?? ui.model.animations?.find(a => a.name === 'up');
  for (const track of clip?.tracks ?? []) {
    const g = ui.bindings.get(track.node.toLowerCase())?.group, v = sampleTrack(track, clip.length); if (!g || !v) continue;
    if (track.property === 'position') g.position.fromArray(v);
    else if (track.property === 'orientation') g.quaternion.fromArray(v);
    else if (track.property === 'scale') g.scale.setScalar(v[0]);
    else if (track.property === 'alpha') for (const child of g.children) if (child.isMesh) { child.material.opacity = Math.max(0, Math.min(1, v[0])); child.visible = v[0] > 0; }
  }
  ui.root.updateMatrixWorld(true);
}

export class NativeUiAssets {
  constructor(resolver) {
    this.resolver = resolver; this.models = new Map(); this.textures = new Map(); this.layouts = new Map(); this.skins = new Map(); this.warnings = new DiagnosticWarnings(() => ({ module: resolver.moduleName })); this.disposed = false;
    this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, preserveDrawingBuffer: true });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace; this.renderer.setClearColor(0, 0);
    this.fonts = [];
  }
  async initializeFonts() {
    await Promise.all([['NWN Default', 'fnt_default'], ['NWN Main Text', 'fnt_maintext']].map(async ([family, resref]) => {
      try { const face = await new FontFace(family, await this.resolver.getResource(resref, RESOURCE_TYPE.TTF)).load(); if (!this.disposed) { document.fonts.add(face); this.fonts.push(face); } }
      catch (error) { this.warnings.add(`${resref}: ${error.message}`); }
    }));
  }
  names() { return [...new Set([...this.resolver.key.resources.keys(), ...this.resolver.module.entries.keys(), ...this.resolver.haks.flatMap(h => [...h.entries.keys()])])].filter(k => k.endsWith(`:${RESOURCE_TYPE.GUI}`)).map(k => k.split(':')[0]).sort(); }
  layout(name) {
    if (!this.layouts.has(name)) this.layouts.set(name, this.resolver.getResource(name, RESOURCE_TYPE.GUI).then(b => parseGff(b, 'GUI ').root));
    return this.layouts.get(name);
  }
  texture(name) {
    name = name.toLowerCase();
    if (!this.textures.has(name)) this.textures.set(name, (async () => {
      const image = new TGALoader().parse(await this.resolver.getResource(name, RESOURCE_TYPE.TGA));
      const t = new THREE.DataTexture(image.data, image.width, image.height, THREE.RGBAFormat); t.flipY = image.flipY; t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.magFilter = t.minFilter = THREE.LinearFilter; t.needsUpdate = true;
      if (this.disposed) t.dispose(); return t;
    })());
    return this.textures.get(name);
  }
  model(name) {
    if (!this.models.has(name)) this.models.set(name, (async () => {
      const model = parseModel(await this.resolver.getResource(name, RESOURCE_TYPE.MDL)), textures = new Map();
      for (const message of model.unsupportedAnimations) runtimeDiagnostics.record('animation.unsupported', message, { model: name, domain: 'ui' });
      await Promise.all(model.materialNames.map(async n => { try { textures.set(n.toLowerCase(), await this.texture(n)); } catch (e) { this.warnings.add(`${n}: ${e.message}`); } }));
      const result = buildUiModel(model, textures); if (this.disposed) this.releaseModel(result); return result;
    })());
    return this.models.get(name);
  }
  skin(name, state = 'up') {
    const key = `${name}:${state}`;
    if (!this.skins.has(key)) this.skins.set(key, (async () => {
      const model = await this.model(name); if (this.disposed) return null;
      poseUiModel(model, state);
      return this.raster(model,name);
    })());
    return this.skins.get(key);
  }
  // The native map replaces gui_replace01 on CTL_ICON_AREAMAP and rotates
  // its icon node by Tile_Orientation*90 degrees. Each variant owns geometry
  // and materials; cached GUI templates and shared textures remain unchanged.
  mapTileSkin(image,orientation){
    const name='CTL_ICON_AREAMAP',key=`map-tile:${image.toLowerCase()}:${orientation}`;
    if(!this.skins.has(key))this.skins.set(key,(async()=>{
      const template=await this.model(name),textures=new Map();
      await Promise.all(template.model.materialNames.map(async n=>textures.set(n.toLowerCase(),await this.texture(n.toLowerCase()==='gui_replace01'?image:n))));
      if(this.disposed)return null;
      const model=buildUiModel(template.model,textures);
      try{
        poseUiModel(model);const icon=model.bindings.get('icon')?.group;if(!icon)throw new Error('Native map template icon node is unavailable');
        icon.rotateZ(orientation*Math.PI/2);model.root.updateMatrixWorld(true);model.bounds=new THREE.Box3().setFromObject(model.root);
        return this.raster(model,`${name}/${image}`);
      }finally{this.releaseModel(model);}
    })());
    return this.skins.get(key);
  }
  raster(model,name){
      const b = model.bounds; if (b.isEmpty()) return { url: null, min: [0, 0], max: [0, 0], width: 0, height: 0, hooks: model.hooks };
      const width = Math.max(1, Math.ceil((b.max.x - b.min.x) * UI_PIXELS_PER_UNIT)), height = Math.max(1, Math.ceil((b.max.y - b.min.y) * UI_PIXELS_PER_UNIT));
      if (width > 4096 || height > 4096) throw new Error(`UI model ${name} exceeds raster limits`);
      const camera = new THREE.OrthographicCamera(b.min.x, b.max.x, b.max.y, b.min.y, 0.1, 200); camera.position.z = 100;
      const scene = new THREE.Scene(); scene.add(model.root); this.renderer.setSize(width, height, false); this.renderer.render(scene, camera); scene.remove(model.root);
      return { url: this.renderer.domElement.toDataURL(), min: [b.min.x, b.min.y], max: [b.max.x, b.max.y], width, height, hooks: model.hooks };
  }
  releaseModel(model) { model.root.traverse(o => { o.geometry?.dispose(); o.material?.dispose(); }); }
  dispose() {
    this.disposed = true; for (const p of this.models.values()) p.then(m => this.releaseModel(m)).catch(() => {});
    for (const p of this.textures.values()) p.then(t => t.dispose()).catch(() => {}); this.renderer.dispose();
    for (const font of this.fonts) document.fonts.delete(font);
  }
}
