import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {traversalCases} from './tile-traversal-cases.mjs';
import {clippedTileSurfaceLine} from '../src/tile_surface_mesh.js';
const observations=JSON.parse(await fs.readFile('backups/animations/native-tile-traversal-observations.json')),data=await traversalCases(process.argv[2]),bits=v=>new Uint32Array(new Float32Array([v]).buffer)[0];let limits=0;
assert.equal(data.cases.length,observations.rows.length);
for(let i=0;i<data.cases.length;i++){const c=data.cases[i],native=observations.rows[i],warnings=[],r=clippedTileSurfaceLine(data.meshes[c.mesh],...c.tile,c.from,c.to,m=>warnings.push(m));assert.equal(r.status,native.result);assert.equal(Boolean(warnings.length),native.limited);limits+=warnings.length;
 const values=[...(r.entry??[null,null]),...(r.exit??[null,null]),r.minHeight,r.maxHeight];for(let j=0;j<values.length;j++)if(values[j]!==null)assert.equal(bits(values[j]),native.bits[j],JSON.stringify({i,j,c}));
}
console.log(JSON.stringify({validation:'PASS',cases:data.cases.length,matchingNativeLimitRejections:limits,limits:'Same loaded mesh inputs; original complete traversal arithmetic compared. Original asset arrays remained in memory only. Independent complete native mesh loading and whole-area route selection are separate owners.'}));
