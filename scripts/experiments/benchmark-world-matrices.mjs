// Rejected experiment, never imported by the production client.
import fs from 'node:fs/promises';
import {Scene,Group,Mesh,BoxGeometry,MeshBasicMaterial} from 'three';
import {RendererWorldMatrices} from './world-matrices-candidate.mjs';
const cases=[];
for(let pass=0;pass<3;pass++)for(const mode of ['stock','cached']){
 const root=new Scene(),geometry=new BoxGeometry(),material=new MeshBasicMaterial(),cache=new RendererWorldMatrices();
 for(let i=0;i<100;i++){const parent=new Group();root.add(parent);for(let j=0;j<200;j++)parent.add(new Mesh(geometry,material));}
 const step=i=>{root.children[i%100].position.x=Math.sin(i*.017);if(mode==='stock')root.updateMatrixWorld();else cache.update(root);};
 for(let i=0;i<30;i++)step(i);const started=performance.now();for(let i=30;i<130;i++)step(i);cases.push({pass,mode,nodes:20101,frames:100,ms:performance.now()-started,stats:mode==='cached'?cache.snapshot():null});geometry.dispose();material.dispose();
}
const report={scope:'Paired authored scene arithmetic benchmark; rejected candidate, not full client FPS',productionEnabled:false,cases};await fs.writeFile(new URL('../../backups/animations/world-matrices-rejected-v1.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
