import * as THREE from 'three';
import { decodeModelOrientation } from './mdl_format.js';

// One hierarchy contract for rendering, playback, and resource smoke checks.
export function createModelHierarchy(model) {
  const root = new THREE.Group();
  root.name = model.modelName;
  const groups = new Map();
  const basis = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2);
  const inverseBasis = basis.clone().invert();
  for (const node of model.nodes) {
    const group = new THREE.Group();
    group.name = node.name;
    group.userData = { mdlNode: node.name, mdlModel: model.modelName };
    group.position.set(node.position[0], node.position[2], -node.position[1]);
    group.scale.setScalar(node.scale ?? 1);
    group.quaternion.copy(basis).multiply(new THREE.Quaternion(...decodeModelOrientation(node.orientation, node.orientationFormat))).multiply(inverseBasis);
    groups.set(node.name, group);
  }
  for (const node of model.nodes) {
    (groups.get(node.parent) ?? root).add(groups.get(node.name));
  }
  root.updateMatrixWorld(true);
  return { root, groups };
}
