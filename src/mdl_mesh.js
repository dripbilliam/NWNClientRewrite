export function groupFacesByMaterial(faces, bitmapCount) {
  const groups = [];
  for (const face of faces) {
    if (!Array.isArray(face) || face.length < 7) continue;
    const requestedIndex = Number.isInteger(face[7]) ? face[7] : 0;
    const materialIndex = requestedIndex >= 0 && requestedIndex < bitmapCount ? requestedIndex : 0;
    let group = groups.at(-1);
    if (!group || group.materialIndex !== materialIndex) {
      group = { materialIndex, faces: [] };
      groups.push(group);
    }
    group.faces.push(face);
  }
  return groups;
}