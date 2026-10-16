import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createPointWindList,addPointWind,advancePointWinds,pointWindVector} from '../src/point_wind.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-point-wind-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const list=(winds,capacity=winds.length)=>({capacity,records:winds.map(w=>({position:w.slice(0,3),radius:w[3],duration:w[4],remaining:w[5],strength:w[6]}))});
const snapshot=l=>({capacity:l.capacity,records:l.records.map(w=>[...w.position,w.radius,w.duration,w.remaining,w.strength])});

test('point wind vector matches complete original owner including overlapping sources, center and strict radius boundary',()=>{
 assert.equal(oracle.queries.length,189);
 for(const row of oracle.queries)assert.deepEqual(pointWindVector(list(row.winds),row.position),row.result,JSON.stringify(row));
});
test('point wind append preserves native physical order and 16/doubling allocation without game-object IDs',()=>{
 assert.equal(oracle.adds.length,126);assert.deepEqual(createPointWindList(),{capacity:0,records:[]});
 for(const row of oracle.adds){const l=list(row.winds,row.capacity);addPointWind(l,row.position,row.radius,row.duration,row.strength);assert.deepEqual(snapshot(l),row.result,JSON.stringify(row));}
});
test('point wind lifetime segment matches full native timer execution with noise/profiler captured separately',()=>{
 assert.equal(oracle.advances.length,60);
 for(const row of oracle.advances){const l=list(row.winds,16);advancePointWinds(l,row.delta);assert.deepEqual(snapshot(l),row.result,JSON.stringify(row));}
});
