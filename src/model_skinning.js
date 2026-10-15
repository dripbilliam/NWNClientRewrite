import * as THREE from 'three';

export function deformSkinnedVertices(node, nodes, groups, skinGroup,nodeGroups=null) {
  const inverseSkinMatrix = skinGroup.matrixWorld.clone().invert();
  const boneMatrices = node.skinData.boneConstantSlots.map((nodeIndex) => {
    const boneNode = nodes[nodeIndex];
    if (!boneNode) return null;
    const boneGroup = nodeGroups?.get(boneNode)??groups.get(boneNode.name);
    return boneGroup ? inverseSkinMatrix.clone().multiply(boneGroup.matrixWorld) : null;
  });

  return node.verts.map((vertex, vertexIndex) => {
    const basePosition = new THREE.Vector3(vertex[0], vertex[2], -vertex[1]);
    const skinnedPosition = new THREE.Vector3();
    let totalWeight = 0;

    for (let component = 0; component < 4; component += 1) {
      const weight = node.skinData.weights[vertexIndex][component];
      const matrix = boneMatrices[node.skinData.boneIndices[vertexIndex][component]];
      if (weight <= 0 || !matrix) continue;
      skinnedPosition.add(basePosition.clone().applyMatrix4(matrix).multiplyScalar(weight));
      totalWeight += weight;
    }

    return totalWeight > 0 ? skinnedPosition.toArray() : basePosition.toArray();
  });
}

