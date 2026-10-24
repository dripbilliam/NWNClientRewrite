import * as THREE from 'three';
import {placeableUsable} from './placeable_hit_mesh.js';

// Scoped to synchronous presentation consumers. A new scope owns fresh world
// matrices and ray intersections; nothing survives movement, input, or frames.
export class WorldPickFrame{
 constructor(root){this.root=root;this.ready=false;this.rays=[];}
 intersections(raycaster){
  if(!this.ready){this.root.updateWorldMatrix(true,true);this.ready=true;}
  const {origin,direction}=raycaster.ray,key=[origin.x,origin.y,origin.z,direction.x,direction.y,direction.z,raycaster.near,raycaster.far,raycaster.layers.mask];
  let row=this.rays.find(r=>r.key.every((value,i)=>Object.is(value,key[i])));
  if(!row){row={key,hits:raycaster.intersectObject(this.root,true)};this.rays.push(row);}return row.hits;
 }
}
export function withWorldPickFrame(owner,callback){
 if(!owner)return callback();
 const previous=owner.pickFrame;owner.pickFrame=new WorldPickFrame(owner.root);
 try{return callback();}finally{owner.pickFrame=previous;}
}
export function pickedWorldObject(raycaster, sceneRoot, registry, { includePlayer = false,frame=null } = {}) {
  if(frame&&frame.root!==sceneRoot)throw Error('Picking frame belongs to another scene');
  const hits=frame?frame.intersections(raycaster):(sceneRoot.updateWorldMatrix(true,true),raycaster.intersectObject(sceneRoot,true));
  const visible = object => {
    for (let ancestor = object; ancestor; ancestor = ancestor.parent) if (!ancestor.visible) return false;
    return true;
  };
  let nearest = null;
  for (const hit of hits) {
    if (!hit.object.isMesh || !visible(hit.object) || hit.object.userData.ignoreWorldPicking) continue;
    let playerHelper = false;
    for (let owner = hit.object; owner; owner = owner.parent) if (owner.userData.worldPickingPlayer) playerHelper = true;
    if (playerHelper && !includePlayer) continue;
    const materials = Array.isArray(hit.object.material) ? hit.object.material : [hit.object.material];
    const material = materials[hit.face?.materialIndex ?? 0];
    if (!hit.object.userData.nativeObjectHitMesh&&material && (!material.visible || material.opacity <= 0.01)) continue;
    for (let owner = hit.object; owner; owner = owner.parent) {
      const id = owner.userData.worldObjectId;
      if (id !== undefined) {const object=registry.get(id);if(hit.object.userData.nativeObjectHitMesh&&(!placeableUsable(object)||object.replicationRemoved))break;nearest = { object, point: hit.point, distance:hit.distance }; break; }
    }
    if (nearest) break;
    if(hit.object.userData.nativeObjectHitMesh)continue;
    // Scenery is an occluder: never select an object through the nearest wall.
    nearest = { object: null, point: hit.point, distance:hit.distance }; break;
  }
  // Door interaction regions stay at the doorway when a leaf swings into a
  // wall. Native picking uses object hit checks and priorities, not only the
  // animated render triangles. The closed-DWK region is our bounded proxy.
  let region = null;
  for (const object of registry.objects.values()) {
    if (!object.pickBounds || (!visible(object.object ?? sceneRoot) && !object.proxy?.visible)) continue;
    const box = new THREE.Box3(new THREE.Vector3(...object.pickBounds.min),new THREE.Vector3(...object.pickBounds.max));
    const point = raycaster.ray.intersectBox(box,new THREE.Vector3());
    if (!point) continue;
    const distance = raycaster.ray.origin.distanceTo(point);
    if (distance < raycaster.near || distance > raycaster.far) continue;
    // Allow a small seam tolerance at the door's own frame; unrelated walls
    // and nearer objects still occlude the doorway.
    if (distance > (nearest?.distance ?? Infinity)+0.08 || distance >= (region?.distance ?? Infinity)) continue;
    region = { object,point,distance };
  }
  return region ?? nearest;
}

export function pointerRay(clientX, clientY, bounds, camera) {
  const pointer = new THREE.Vector2((clientX - bounds.left) / bounds.width * 2 - 1,
    1 - (clientY - bounds.top) / bounds.height * 2);
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(pointer, camera);
  return raycaster;
}
