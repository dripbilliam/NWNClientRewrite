import {openLocalModule} from './local-module.mjs';
import {parseAreaModule,loadAreaWalkmesh} from '../src/area.js';
import {parseModel} from '../src/model_parser.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {findWalkableHeight} from '../src/walkmesh.js';
import * as THREE from 'three';
const install='../FullDecomp/NwnRootInstall',r=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),area=await parseAreaModule('m0q1a',r);
const coverage=[],models=[],walk=await loadAreaWalkmesh(area,r);
for(const [i,tile]of area.tiles.entries()){
 const model=parseModel(await r.getResource(tile.model,RESOURCE_TYPE.MDL)),{root,groups}=createModelHierarchy(model);
 root.position.set(i%area.width*10+5,tile.height*area.tileHeight,-(Math.floor(i/area.width)*10+5));root.rotation.y=tile.orientation*Math.PI/2;root.updateMatrixWorld(true);
 const tris=[];
 for(const n of model.nodes){if(n.type!=='trimesh'||n.render===false||n.properties?.render===0)continue;
  const vertices=n.verts.map(v=>new THREE.Vector3(v[0],v[2],-v[1]).applyMatrix4(groups.get(n.name).matrixWorld).toArray());
  for(const f of n.faces)tris.push({vertices:f.slice(0,3).map(j=>vertices[j])});
 }
 coverage.push(...tris);models.push({i,name:tile.model,triangles:tris.length});
}
const holes=[];
for(let y=.25;y<30;y+=.5)for(let x=.25;x<30;x+=.5){const h=findWalkableHeight(walk.triangles,x,-y);if(h===null)continue;
 const render=findWalkableHeight(coverage,x,-y,h,.15);if(render===null)holes.push({x,y,h});
}
console.log(JSON.stringify({models,holes},null,2));
