import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {tileSubdivision,findSubdivisionTriangle,subdivisionTriangleVertices,subdivisionTriangleAdjacency} from '../src/tile_subdivision.js';
test('tile subdivision and encoded queries match two original subdivision passes, physical adjacency and seeded boundary ties',()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-subdivision-observations.json',import.meta.url))).rows;
  for(const row of rows){const mesh=structuredClone(row.mesh),levels=tileSubdivision(mesh);assert.deepEqual(levels.slice(1),row.levels,JSON.stringify(row.mesh));
    for(const q of row.queries)assert.equal(findSubdivisionTriangle(mesh,q.level,q.remaining,q.point,q.seed),q.result|0,JSON.stringify(q));
    for(const q of row.getters){assert.deepEqual(subdivisionTriangleVertices(mesh,q.level,q.index),q.vertices,JSON.stringify(q));assert.deepEqual(subdivisionTriangleAdjacency(mesh,q.level,q.index),q.adjacency,JSON.stringify(q));}
  }
});
