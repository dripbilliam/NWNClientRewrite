// Read-only real resource decoding checks, not a native collision/encounter oracle.
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { RESOURCE_TYPE, decodeResourceText } from '../src/resource_archive.js';
import { parse2da } from '../src/area.js';
const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-object-meshes.mjs <install> <module>');
const session = await new ModuleSession(await openLocalModule(install, modulePath), { runStartupScripts: false }).initialize([]);
const tables = {};
for (const name of ['genericdoors', 'doortypes']) tables[name] = parse2da(decodeResourceText(await session.resolver.getResource(name, RESOURCE_TYPE.TWO_DA)));
const result = { loaded: { placeable: 0, door: 0 }, empty: { placeable: 0, door: 0 }, missing: [], vertices: 0, faces: 0 };
for (const object of session.registry.objects.values()) {
  if (!['placeable', 'door'].includes(object.kind)) continue;
  let model;
  try {
    let surface;
    if (object.kind === 'placeable') ({ model, mesh: surface } = await session.geometryResources.placeableMesh((object.authored.Appearance ?? 0) & 65535));
    else {
      const appearance = object.authored.Appearance ?? 0, generic = object.authored.GenericType_New ?? object.authored.GenericType ?? 0;
      const table = tables[appearance === 0 ? 'genericdoors' : 'doortypes'];
      const row = table.orderedRows[appearance === 0 ? generic : appearance];
      model = row?.[table.columns.find(column => column.toLowerCase() === 'modelname')] ?? row?.[table.columns.find(column => column.toLowerCase() === 'model')];
      if (!model || model === '****') throw new Error('Native door model selection is unavailable');
      surface = await session.geometryResources.objectMesh(model.toLowerCase().slice(0, 16), 'door');
    }
    result.loaded[object.kind]++;
    if (!(surface.states ?? [surface]).some(state => state.vertices.length)) result.empty[object.kind]++;
    for (const state of surface.states ?? [surface]) { result.vertices += state.vertices.length; result.faces += state.faces.length; }
  } catch (error) {
    session.report(error, { area: session.registry.get(object.areaId)?.resRef, objectId: object.id, model, operation: 'native-object-surface-load' });
    result.missing.push({ id: object.id, kind: object.kind, model, reason: error.message });
  }
}
const areas = [];
for (const area of session.areas.values()) {
  const store = await area.nativeGeometry.objects.load();
  for (let slot = 0; slot < store.objectCount; slot++) if (session.registry.get(store.objectIds[slot])?.objectType !== 9) throw new Error('Static collision ID does not identify a canonical placeable');
  for (let slot = 0; slot < store.doorCount; slot++) if (session.registry.get(store.doorIds[slot])?.objectType !== 10) throw new Error('Door collision ID does not identify a canonical door');
  areas.push({ area: area.resRef, staticObjects: store.objectCount, doors: store.doorCount, vertices: store.vertexCount, faces: store.faceCount });
}
console.log(JSON.stringify({ module: session.resolver.moduleName, ...result, areas, resources: session.geometryResources.objectModels.size }, null, 2));
