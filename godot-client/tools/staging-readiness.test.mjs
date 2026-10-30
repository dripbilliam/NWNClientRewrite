import {test} from 'node:test';
import assert from 'node:assert/strict';
import {stagingReadiness} from './staging-readiness.mjs';
const scope={areaId:7,generation:3},ready={...scope,phase:'playing',controlled:true,models:5,pending:0,graphicsPending:false,failures:[]};
test('an unrelated failed entity does not erase a prepared current world',()=>{assert.deepEqual(stagingReadiness({...ready,failures:[42]},scope),{ready:true,failedEntities:[42]});});
test('retired areas, unfinished assets and a missing controlled actor cannot admit input',()=>{for(const patch of [{areaId:8},{generation:4},{pending:1},{graphicsPending:true},{controlled:false},{models:0},{phase:'area-loading'}])assert.equal(stagingReadiness({...ready,...patch},scope).ready,false);});
