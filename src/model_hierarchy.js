import * as THREE from 'three';
import { decodeModelOrientation } from './mdl_format.js';

// Binary children are offset references; duplicate names are legal. Retain
// their physical parent identity rather than resolving that edge by label.
export function modelParentIndices(model){
  const names=new Map(model.nodes.map((n,i)=>[n.name,i]));
  const parents=model.nodes.map(n=>Number.isInteger(n.parentIndex)?n.parentIndex:n.parent==='NULL'?-1:names.get(n.parent)??-1),visited=new Set(),active=new Set();
  const visit=i=>{if(visited.has(i))return;if(active.has(i))throw new Error(`Model ${model.modelName} has a parent cycle at ${model.nodes[i].name}`);active.add(i);const p=parents[i];if(p!==-1){if(p<0||p>=parents.length)throw new Error(`Model ${model.modelName} parent index is invalid`);visit(p);}active.delete(i);visited.add(i);};
  parents.forEach((_p,i)=>visit(i));return parents;
}

// One hierarchy contract for rendering, playback, and resource smoke checks.
export function createModelHierarchy(model) {
  const root = new THREE.Group();
  root.name = model.modelName;
  const groups = new Map();
  const nodeGroups=new Map(),parents=modelParentIndices(model);
  const basis = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2);
  const inverseBasis = basis.clone().invert();
  for (const [index,node] of model.nodes.entries()) {
    const group = new THREE.Group();
    group.name = node.name;
    group.userData = { mdlNode: node.name, mdlModel: model.modelName,mdlNodeIndex:index,mdlNodeId34:node.nativeNode?.id34 };
    group.position.set(node.position[0], node.position[2], -node.position[1]);
    group.scale.setScalar(node.scale ?? 1);
    group.quaternion.copy(basis).multiply(new THREE.Quaternion(...decodeModelOrientation(node.orientation, node.orientationFormat))).multiply(inverseBasis);
    groups.set(node.name, group);
    nodeGroups.set(node,group);
  }
  for (const [i,node] of model.nodes.entries()) {
    (nodeGroups.get(model.nodes[parents[i]]) ?? root).add(nodeGroups.get(node));
  }
  root.updateMatrixWorld(true);
  return { root, groups,nodeGroups };
}
