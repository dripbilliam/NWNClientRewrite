// Audit-only candidate. Production does not import this module.
// This describes the CURRENT replacement builder, not native NWN semantics.
const normalize = names => [...new Set(names.map(name => name.toLowerCase()).filter(name => name && name !== 'null'))];

export function auditModelTextureUsage(model) {
  const catalog = normalize(model.materialNames ?? []), consumedNames = [];
  const uncertain = [];
  for (const node of model.nodes ?? []) {
    if (node.type === 'emitter') {
      if (typeof node.properties?.texture === 'string') consumedNames.push(node.properties.texture);
      continue; // Include dormant emitters: animation can turn them on later.
    }
    if (node.type !== 'trimesh' || node.render === false || node.properties?.render === 0 || node.properties?.render === '0') continue;
    if (!Array.isArray(node.verts) || !Array.isArray(node.faces)) { uncertain.push(node.name ?? '<mesh>'); continue; }
    if (!node.verts.length || !node.faces.length) continue;
    const faces = node.faces.filter(face => Array.isArray(face) && face.length >= 7);
    if (!faces.length) continue;
    if (faces.some(face => face.slice(0, 3).some(i => !node.verts[i] || node.verts[i].length < 3))) {
      uncertain.push(node.name ?? '<mesh>'); continue;
    }
    // buildMesh currently uses ASCII .bitmaps or scalar .bitmap, including all
    // material slots. Binary .textureLayers are catalogued but not yet drawn.
    consumedNames.push(...(node.bitmaps?.length ? node.bitmaps : [node.bitmap || '']));
  }
  const consumed = normalize(consumedNames), catalogSet = new Set(catalog);
  const unlistedConsumed = consumed.filter(name => !catalogSet.has(name));
  const fallback = !!(uncertain.length || unlistedConsumed.length);
  const selected = fallback ? catalog.slice() : catalog.filter(name => consumed.includes(name));
  return {catalog, consumed, selected, skipped: catalog.filter(name => !selected.includes(name)), unlistedConsumed, uncertain, fallback};
}
