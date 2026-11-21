// Read-only installed-resource query exercise; counts/diagnostics only.
// These results are not an independent native LOS or encounter oracle.
import assert from 'node:assert/strict';
import { openLocalModule } from './local-module.mjs';
import { ModuleSession } from '../src/module_session.js';
import { clearAreaTileLOS } from '../src/tile_los.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

const [install,modulePath]=process.argv.slice(2);
if(!install||!modulePath)throw new Error('Usage: node scripts/smoke-los.mjs <install> <module>');
const session=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false}).initialize([]);
const results=[],materials=await session.geometryResources.losMaterialMask();
for(const area of session.areas.values()){
  const result={area:area.resRef,tiles:0,trees:0,nodes:0,leaves:0,tileClear:0,tileBlocked:0,areaClear:0,areaBlocked:0,failures:[]};
  for(let index=0;index<area.width*area.height;index++){
    const x=index%area.width,y=Math.floor(index/area.width);
    try{
      const tile=await area.nativeGeometry.tile(x,y);result.tiles++;
      if(tile.mesh.aabb){
        result.trees++;const pending=[tile.mesh.aabb];
        while(pending.length){const node=pending.pop();result.nodes++;
          if(node.sourceFace===-1){assert.ok(node.left&&node.right);pending.push(node.left,node.right);}
          else{result.leaves++;const part=node.denied?tile.mesh.denied:tile.mesh;assert.ok(part.faces[node.face]);}
        }
      }
      const from=[x*10+4,y*10+5,tile.heightOffset+1],to=[x*10+6,y*10+5,tile.heightOffset+1];
      const hit=[];const status=clearAreaTileLOS(tile,49,from,to,hit,materials);
      assert.ok([0,1].includes(status));assert.ok(hit.every(Number.isFinite));result[status?'tileClear':'tileBlocked']++;
      // Full canonical objects/door store is exercised once per area.
      if(index===0){const areaHit=[],object={id:OBJECT_INVALID};
        const answer=await area.nativeGeometry.lineOfSight(from,to,areaHit,object,OBJECT_INVALID,OBJECT_INVALID,0);
        assert.ok([0,1].includes(answer));assert.ok(areaHit.every(Number.isFinite));result[answer?'areaClear':'areaBlocked']++;
      }
    }catch(error){result.failures.push({index,reason:error.message});}
  }
  results.push(result);
}
console.log(JSON.stringify({module:session.resolver.moduleName,materialMask:materials.toString(16),areas:results,diagnostics:session.diagnostics},null,2));
if(results.some(area=>area.failures.length))process.exitCode=1;
