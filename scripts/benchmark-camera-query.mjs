import fs from 'node:fs/promises';import * as T from 'three';
import {cameraSceneQuery} from '../src/camera_scene_query.js';
const version=process.argv[2]??'baseline';if(!/^[a-z0-9-]+$/.test(version))throw Error('Invalid benchmark version');
const root=new T.Group(),geometry=new T.CylinderGeometry(.45,.65,1.8,8),material=new T.MeshBasicMaterial();
for(let i=0;i<1500;i++){const tile=new T.Group();tile.userData.nativeStaticTile=true;tile.position.set(i%50*1.8-45,.9,-Math.floor(i/50)*1.8+27);root.add(tile);const mesh=new T.Mesh(geometry,material);mesh.userData.nativeModelMesh=true;tile.add(mesh);}
const query=cameraSceneQuery(root),times=[],hits=[];
for(let i=0;i<150;i++){query.update();const angle=i*.071,from=[Math.sin(angle)*14,Math.cos(angle)*14,8],to=[.3,-.1,.5],started=performance.now(),result=query.nearestHit(from,to),ms=performance.now()-started;if(i>=30){times.push(ms);hits.push(result);}}
const ordered=times.toSorted((a,b)=>a-b),report={scope:'Offline 1500 authored static meshes, native polygon hit kernel, moving camera segments',meshes:1500,triangles:geometry.index.count/3*1500,samples:times.length,meanMs:times.reduce((n,v)=>n+v,0)/times.length,p95Ms:ordered[Math.floor(ordered.length*.95)],maxMs:Math.max(...times),hits,stats:query.stats?.()??null};
await fs.writeFile(new URL(`../backups/animations/camera-query-${version}.json`,import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,hits:report.hits.filter(Boolean).length}));geometry.dispose();material.dispose();
