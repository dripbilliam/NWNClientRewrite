import * as THREE from 'three';

export function pickedWorldObject(raycaster, sceneRoot, registry, { includePlayer = false } = {}) {
  sceneRoot.updateWorldMatrix(true, true);
  const visible = object => {
    for (let ancestor = object; ancestor; ancestor = ancestor.parent) if (!ancestor.visible) return false;
    return true;
  };
  let nearest = null;
  for (const hit of raycaster.intersectObject(sceneRoot, true)) {
    if (!hit.object.isMesh || !visible(hit.object) || hit.object.userData.ignoreWorldPicking) continue;
    let playerHelper = false;
    for (let owner = hit.object; owner; owner = owner.parent) if (owner.userData.worldPickingPlayer) playerHelper = true;
    if (playerHelper && !includePlayer) continue;
    const materials = Array.isArray(hit.object.material) ? hit.object.material : [hit.object.material];
    const material = materials[hit.face?.materialIndex ?? 0];
    if (material && (!material.visible || material.opacity <= 0.01)) continue;
    for (let owner = hit.object; owner; owner = owner.parent) {
      const id = owner.userData.worldObjectId;
      if (id !== undefined) { nearest = { object: registry.get(id), point: hit.point, distance:hit.distance }; break; }
    }
    if (nearest) break;
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
