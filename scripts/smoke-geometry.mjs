// Read-only installed-resource geometry checks. No native encounter parity
// assertion: surface loading/traversal is distinct from LOS/object polygons.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { rotateTilePoint } from '../src/tile_surface_mesh.js';

const [install, modulePath] = process.argv.slice(2);
if (!install || !modulePath) throw new Error('Usage: node scripts/smoke-geometry.mjs <install> <module>');
const session = await new ModuleSession(await openLocalModule(install, modulePath), { runStartupScripts: false }).initialize([]);
const results = [];
for (const area of session.areas.values()) {
  const result = { area: area.resRef, size: [area.width, area.height], loaded: 0, missing: [], pointChecks: 0, models: new Set() };
  for (let index = 0; index < area.width * area.height; index++) {
    const x = index % area.width, y = Math.floor(index / area.width);
    let tile;
    try { tile = await area.nativeGeometry.tile(x, y); }
    catch (error) { result.missing.push({ index, reason: error.message }); continue; }
    result.loaded++; result.models.add(tile.model);
    assert.equal(await area.nativeGeometry.tile(x, y), tile);
    for (const indices of tile.mesh.faces) {
      const vertices = indices.map(i => tile.mesh.vertices[i]);
      const point = [x * 10 + vertices.reduce((n, v) => n + v[0], 0) / 3, y * 10 + vertices.reduce((n, v) => n + v[1], 0) / 3];
      // Traverse a real face point through tile rotation/wrapper; the mesh
      // may have no walkable faces or projected overlap, both are retained.
      const world = rotateTilePoint(tile, point, false);
      assert.equal(await area.nativeGeometry.lineWalkable(world, world), 1, `Triangle point rejected: ${area.resRef}/${index}/${tile.model}`);
      result.pointChecks++; break;
    }
  }
  result.models = [...result.models]; results.push(result);
}
assert.ok(results.reduce((n, area) => n + area.loaded, 0), 'No native tile meshes loaded');
console.log(JSON.stringify({ module: session.resolver.moduleName, areas: results, resourceModels: session.geometryResources.models.size,
  diagnostics: session.diagnostics }, null, 2));
