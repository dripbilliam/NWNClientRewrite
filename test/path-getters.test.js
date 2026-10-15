import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {tileRegionCoords,tileExit,tileExitNumber,tileTotalExits,tileRegionEntrance} from '../src/tile_path_node.js';
test('path-node getter adapters match full original surface/tile bodies and quarter-turn rotations',()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-path-getter-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,tile={orientation:c.orientation,pathNodes:{path:c.kind,pathOrientation:c.nodeOrientation}};
    if(c.mode==='coords'){assert.equal(row.result,1);assert.deepEqual(tileRegionCoords(tile,c.index),row.point,JSON.stringify(c));}
    else if(c.mode==='exit'){assert.equal(row.result,1);assert.deepEqual(tileExit(tile,c.index),{point:row.point,region:row.region},JSON.stringify(c));}
    else{const value=c.mode==='total'?tileTotalExits(tile):c.mode==='number'?tileExitNumber(tile,c.point):tileRegionEntrance(tile,c.point);
      assert.equal(value,row.result|0,JSON.stringify(c));}
  }
});
test('empty region query matches original zero status when outputs are ignored, while required coordinates remain unavailable',()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-empty-region-observations.json',import.meta.url))).rows;
  for(const row of rows){
    const tile={x:8,y:11,orientation:row.orientation,pathNodes:{path:row.kind,pathOrientation:0}};
    assert.equal(row.result,0);assert.equal(tileRegionCoords(tile,row.index,{outputRequired:false}),null);
    assert.throws(()=>tileRegionCoords(tile,row.index),error=>error.message.includes('unavailable')&&error.diagnosticContext.region===row.index);
  }
});
