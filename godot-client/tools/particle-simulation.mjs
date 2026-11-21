import * as T from 'three';
import {ModelParticlePresentation, createModelEmitter} from '../../src/model_particles.js';
import {packParticleBuffers, validateParticleLayout} from './particle-buffers.mjs';
import {sampleTrack} from '../../src/model_animation.js';

const identity = () => new T.Matrix4().toArray();
const matrix = value => {
 if (!Array.isArray(value) || value.length !== 16 || !value.every(Number.isFinite)) throw Error('Invalid particle pose matrix');
 return value;
};
function setWorld(object, value) {
 object.matrix.fromArray(matrix(value));
 object.matrix.decompose(object.position, object.quaternion, object.scale);
 object.matrixWorldNeedsUpdate = true;
}

// CPU-only scene adapter: no WebGLRenderer, DOM, network or frame timer. Godot
// supplies the camera/poses/deltas. All physics/atlas/random calls stay in the
// retained original-derived owners, including their explicit unsupported paths.
export class NativeParticleSimulation {
 constructor({layout, seed = 1, maxEmitters = 4096} = {}) {
  this.layout = validateParticleLayout(layout); this.seed = seed; this.maxEmitters = maxEmitters;
  this.epoch = 0; this.sequence = -1; this.closed = false; this.nodes = new Map(); this.capacities = new Map(); this.diagnostics = []; this.resources = new Set();
  this.scene = new T.Scene(); this.camera = new T.PerspectiveCamera(); this.camera.matrixAutoUpdate = false;
  this.referenceScenes = new WeakMap();
  this.simulation = new ModelParticlePresentation({camera:this.camera, seed, reuseFrameState:true,
   // Only explicitly tagged native materials delegate tint to Godot's scene
   // light pass. Neutral CPU tint avoids applying engine lighting twice.
   lightColor:mesh=>{if(this.nodes.get(mesh.userData.nativeParticleId)?.engineLighting)return [1,1,1];throw Error('Native particle scene light-color provider is unavailable');},
   referenceScene:root=>this.referenceScenes.get(root)??null,
   report:(code, message, data) => this.diagnostics.push({code, message, data})});
  this.simulation.upload = (entry, out) => {
   if (out?.count && !entry.mesh.material.uniforms?.particleMap?.value) throw Error('Emitter bitmap is unavailable for drawing');
   const id = entry.mesh.userData.nativeParticleId;
   const packed = packParticleBuffers(out, this.layout, this.capacities.get(id) ?? 0);
   this.capacities.set(id, packed.capacity); entry.drawCount = packed.count;
   this.output.push({id, ...packed});
  };
 }
 reset({epoch, emitters, collision = []}) {
  if (this.closed) throw Error('Particle simulation is closed');
  if (!Number.isSafeInteger(epoch) || epoch <= this.epoch || !Array.isArray(emitters) || emitters.length > this.maxEmitters || !Array.isArray(collision)) throw Error('Invalid particle simulation reset');
  // Validate before retiring a working scene. A source reference endpoint must
  // be wired explicitly; omitting it would make lightning silently aim at self.
  const ids = new Set();
  for (const row of emitters) this.validateDescriptor(row,ids);
  /* validation and allocation stay separate so invalid replacement metadata
     cannot retire a working simulation. */
  const collisionMeshes = collision.map(row => {
   if (!Array.isArray(row.faces) || row.faces.length > 100000) throw Error('Invalid particle collision faces');
   for (const face of row.faces) if (!Array.isArray(face.vertices) || face.vertices.length < 3 || face.vertices.some(v => !Array.isArray(v) || v.length !== 3 || !v.every(Number.isFinite)) || !Array.isArray(face.normal) || face.normal.length !== 3 || !face.normal.every(Number.isFinite) || !Number.isFinite(face.constant)) throw Error('Invalid particle collision plane');
   matrix(row.matrix ?? identity()); return row;
  });
  this.simulation.dispose(); for (const resource of this.resources) resource.dispose(); this.resources.clear();
  this.scene.clear(); this.nodes.clear(); this.capacities.clear(); this.diagnostics = [];
  this.simulation.random.seed(this.seed); this.simulation.reported.clear();
  this.referenceScenes=new WeakMap();
  this.epoch = epoch; this.sequence = -1;
  for (const row of collisionMeshes) {
   const tile = new T.Group(); tile.userData.nativeStaticTile = true; tile.matrixAutoUpdate = false; setWorld(tile, row.matrix ?? identity());
   const geometry = new T.BufferGeometry(); geometry.userData.nativeCameraHitFaces = structuredClone(row.faces);
   const mesh = new T.Mesh(geometry); this.resources.add(geometry); this.resources.add(mesh.material); mesh.userData.nativeModelMesh = true; tile.add(mesh); this.scene.add(tile);
  }
  for (const row of emitters) this.add(row);
 }
 validateDescriptor(row, ids=new Set()) {
   if (!Number.isSafeInteger(row.id) || row.id < 0 || ids.has(row.id) || !row.properties || typeof row.properties !== 'object') throw Error('Invalid particle descriptor');
   ids.add(row.id); matrix(row.rootMatrix ?? identity()); matrix(row.matrix ?? identity());
   if (row.referenceTarget) matrix(row.referenceTarget.matrix);
 }
 add(row) {
   const root = new T.Group(), parent = new T.Group(); root.userData.mdlRoot = true;
   root.matrixAutoUpdate = parent.matrixAutoUpdate = false;
   setWorld(root, row.rootMatrix ?? identity());
   const local = new T.Matrix4().fromArray(row.rootMatrix ?? identity()).invert().multiply(new T.Matrix4().fromArray(row.matrix ?? identity())).toArray();
   setWorld(parent, local); root.add(parent); this.scene.add(root);
   // A boolean descriptor is only a CPU texture-presence marker; original
   // pixels belong to Godot's texture resource and never enter this worker.
   const texture = row.textureAvailable ? new T.Texture() : null;
   const mesh = createModelEmitter({name:row.node ?? '', properties:row.properties}, new Map([[String(row.properties.texture ?? '').toLowerCase(), texture]]), row.model ?? '');
   mesh.userData.nativeParticleId = row.id; parent.add(mesh);
   this.resources.add(mesh.geometry); this.resources.add(mesh.material); if (texture) this.resources.add(texture);
   const record={root, parent, mesh, engineLighting:row.engineLighting===true,properties:structuredClone(row.properties),clips:row.clips??{},awaitPose:row.awaitPose===true,resources:[mesh.geometry,mesh.material,...(texture?[texture]:[])]};
   if(row.referenceTarget){
    const targetRoot=new T.Group();targetRoot.matrixAutoUpdate=false;setWorld(targetRoot,row.referenceTarget.matrix);this.scene.add(targetRoot);
    const part={node:{type:'reference'},model68:{root:targetRoot}};
    record.reference={root:targetRoot,part,available:true};
    this.referenceScenes.set(root,{partForGroup:group=>group===parent?{children38:[part]}:null});
   }
   if(record.awaitPose){root.removeFromParent();record.reference?.root.removeFromParent();}
   this.nodes.set(row.id, record);
 }
 patch({epoch,add=[],remove=[]}) {
  if(this.closed||epoch!==this.epoch) return {stale:true};
  const ids=new Set([...this.nodes.keys()].filter(id=>!remove.includes(id)));
  for(const row of add)this.validateDescriptor(row,ids);
  if(ids.size>this.maxEmitters)throw Error('Particle patch exceeds emitter limit');
  for(const id of remove){const row=this.nodes.get(id);if(!row)continue;const entry=this.simulation.entries.get(row.mesh);if(entry?.e){row.mesh.geometry.dispose();row.mesh.material.dispose();entry.e.target1c0=null;if(entry.e.targetListener128)entry.e.targetListener128.active=false;}this.simulation.entries.delete(row.mesh);row.root.removeFromParent();row.reference?.root.removeFromParent();this.referenceScenes.delete(row.root);for(const resource of row.resources){resource.dispose();this.resources.delete(resource);}this.nodes.delete(id);this.capacities.delete(id);}
  for(const row of add)this.add(row);
  return {stale:false};
 }
 frame({epoch, sequence, delta, camera, poses = []}) {
  if (this.closed) throw Error('Particle simulation is closed');
  if (epoch !== this.epoch) return {epoch, sequence, stale:true, emitters:[]};
  if (!Number.isSafeInteger(sequence) || sequence <= this.sequence || !Number.isFinite(delta) || delta < 0 || delta > 10 || !Array.isArray(poses) || poses.length > this.maxEmitters) throw Error('Invalid particle simulation frame');
  matrix(camera);
  const seen = new Set();
  for (const pose of poses) {
   if (seen.has(pose.id) || !this.nodes.has(pose.id)) throw Error('Unknown or duplicate particle pose'); seen.add(pose.id);
   matrix(pose.matrix); matrix(pose.rootMatrix);
   if (pose.properties && (typeof pose.properties !== 'object' || Array.isArray(pose.properties))) throw Error('Invalid particle property sample');
   if(pose.animation&&(typeof pose.animation.clip!=='string'||!Number.isFinite(pose.animation.time)))throw Error('Invalid particle model clock');
   if(pose.referenceMatrix!==undefined&&pose.referenceMatrix!==null)matrix(pose.referenceMatrix);
  }
  this.sequence = sequence; this.diagnostics = [];setWorld(this.camera, camera);
  for (const pose of poses) {
   const row = this.nodes.get(pose.id);
   if(row.awaitPose){this.scene.add(row.root);if(row.reference)this.scene.add(row.reference.root);row.awaitPose=false;}
   setWorld(row.root, pose.rootMatrix);
   setWorld(row.parent, new T.Matrix4().fromArray(pose.rootMatrix).invert().multiply(new T.Matrix4().fromArray(pose.matrix)).toArray());
   const animated={};for(const track of row.clips[pose.animation?.clip]?.tracks??[]){const value=sampleTrack(track,pose.animation.time);if(value)animated[track.property.slice(8)]=value.length===1?value[0]:value;}
   row.parent.userData.mdlEmitterProperties = {...row.properties, ...animated, ...pose.properties};
   if (pose.detonate) row.mesh.userData.mdlPendingDetonate = true;
   if(row.reference&&pose.referenceMatrix!==undefined){
    if(pose.referenceMatrix===null){
     // The native owner invalidated the physical endpoint lifetime. It may
     // not rebind this old emitter to a recycled canonical object ID.
     if(row.reference.available)this.simulation.once('particle.endpoint-retired','Physical endpoint was retired; the old emitter cannot bind a recycled object ID',{model:row.mesh.userData.mdlEmitter.model,node:row.mesh.userData.mdlEmitter.node});
     row.reference.available=false;this.referenceScenes.set(row.root,{partForGroup:group=>group===row.parent?{children38:[]}:null});
     const entry=this.simulation.entries.get(row.mesh);if(entry?.e){entry.e.target1c0=null;if(entry.e.targetListener128)entry.e.targetListener128.active=false;}
    }else if(row.reference.available)setWorld(row.reference.root,pose.referenceMatrix);
   }
  }
  this.output = [];this.simulation.update(this.scene, delta);
  const drawn = new Set(this.output.map(row => row.id));
  for (const id of this.nodes.keys()) if (!drawn.has(id)) this.output.push({id, ...packParticleBuffers(null, this.layout, this.capacities.get(id) ?? 0)});
  return {epoch, sequence, emitters:this.output, diagnostics:this.diagnostics.splice(0), state:this.simulation.snapshot(), randomDraws:this.simulation.random.draws};
 }
 close() {
  if (this.closed) return; this.closed = true; this.simulation.dispose();
  for (const resource of this.resources) resource.dispose(); this.resources.clear();
  this.scene.clear(); this.nodes.clear(); this.capacities.clear();
  this.referenceScenes=new WeakMap();
 }
}
