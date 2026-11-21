import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {nativePolygonHit,nativePolygonPlane,cameraModelHitFaces} from '../src/native_polygon_hit.js';
import {Group,Mesh,MeshBasicMaterial,PlaneGeometry} from 'three';
import {cameraSceneQuery} from '../src/camera_scene_query.js';
import {loadAreaWalkmesh} from '../src/area.js';
import {openLocalModule} from '../scripts/local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {fileURLToPath} from 'node:url';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-polygon-observations.json',import.meta.url))),f=Math.fround;
const bits=v=>{const b=new ArrayBuffer(4),d=new DataView(b);d.setFloat32(0,v,true);return d.getUint32(0,true).toString(16).padStart(8,'0');};
test('complete original polyhit agrees bit-for-bit for finite front/back/edge/endpoint and aliased output cases',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,1876);let hits=0;
 for(const [index,row]of fixture.rows.entries()){const c=row.case,vertices=c.vertices.map(v=>v.map(f)),normal=c.normal.map(f),point=nativePolygonHit(vertices,normal,f(c.constant),c.start.map(f),c.end.map(f));assert.equal(Boolean(point),Boolean(row.result),JSON.stringify(c));if(point){hits++;assert.deepEqual(point.map(bits),row.bits,JSON.stringify(c));}
  if(index>=1620){const plane=nativePolygonPlane(vertices);assert.deepEqual(plane.normal.map(bits),normal.map(bits));assert.equal(bits(plane.constant),bits(c.constant));}
 }assert.ok(hits>100);
});
test('installed binary MaxFace records retain every original plane and index before draw-list reconstruction',async t=>{
 const install=new URL('../../FullDecomp/NwnRootInstall',import.meta.url);if(!fs.existsSync(install)){t.skip('Installed native resources unavailable');return;}
 const resolver=await openLocalModule(fileURLToPath(install),fileURLToPath(new URL('../../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm',import.meta.url))),bytes=await resolver.getResource('plc_a08',2002),model=parseModel(bytes),data=new DataView(bytes);let faces=0,parts=0;
 const read=offset=>data.getUint32(offset,true),walk=relative=>{const start=12+relative,flags=read(start+108);if(flags&32){assert.equal(flags,33,'fixture mesh has no preceding extension');const node=model.nodes.find(n=>n.name===new TextDecoder('ascii').decode(new Uint8Array(bytes,start+32,32)).split('\0')[0]),offset=12+read(start+120),count=read(start+124);assert.equal(node.nativeCollisionFaces.length,count);parts++;
   for(let i=0;i<count;i++){const at=offset+i*32,face=node.nativeCollisionFaces[i];assert.deepEqual(face.normal.map(bits),[0,4,8].map(n=>bits(data.getFloat32(at+n,true))));assert.equal(bits(face.constant),bits(data.getFloat32(at+12,true)));assert.deepEqual(face.indices,[26,28,30].map(n=>data.getUint16(at+n,true)));faces++;}
  }const children=12+read(start+72);for(let i=0;i<read(start+76);i++)walk(read(children+i*4));};walk(read(84));assert.ok(parts>1&&faces>100);
});
test('clear-view query uses source hit faces even when the visible draw plane is elsewhere',()=>{
 const root=new Group(),tile=new Group(),mesh=new Mesh(new PlaneGeometry(2,2),new MeshBasicMaterial());tile.userData.nativeStaticTile=true;mesh.userData.nativeModelMesh=true;tile.add(mesh);root.add(tile);mesh.geometry.userData.nativeCameraHitFaces=[];
 assert.equal(cameraSceneQuery(root)([0,-2,0],[0,2,0]),false,'empty original faces ignore visible draw triangles');
 const vertices=[[-1,-1,1],[1,-1,1],[0,1,1]];mesh.geometry.userData.nativeCameraHitFaces=[{vertices,...nativePolygonPlane(vertices)}];assert.equal(cameraSceneQuery(root)([0,0,2],[0,0,.5]),true,'retained native Z=1 face participates');assert.equal(cameraSceneQuery(root)([0,-2,0],[0,2,0]),false,'unrelated visible Three Z=0 draw plane stays excluded');mesh.geometry.dispose();mesh.material.dispose();
});
test('camera WOK collection includes non-walkable faces without admitting them to movement',async()=>{
 const wok='node aabb authored\nposition -5 -5 0\nverts 4\n0 0 0\n1 0 0\n0 1 0\n0 0 1\nfaces 3\n0 1 2 0 0 0 0 0\n0 3 1 0 0 0 0 1\n0 2 3 0 0 0 0 30\nendnode',surface='2DA V2.0\n\nWalk\n0 1\n1 0\n30 0\n',resolver={getResource:async name=>new TextEncoder().encode(name==='surfacemat'?surface:wok)},area={resRef:'authored',width:1,tileHeight:1,tiles:[{model:'authored',height:0,orientation:0}]};
 const loaded=await loadAreaWalkmesh(area,resolver);assert.deepEqual(loaded.missing,[]);assert.equal(loaded.triangles.length,1);assert.equal(loaded.cameraTriangles.length,3);const query=cameraSceneQuery(new Group(),loaded.cameraTriangles);assert.equal(query([.25,1,.25],[.25,-1,.25]),true);assert.equal(query([-1,.25,.25],[1,.25,.25]),false,'surface30 is excluded');assert.equal(loaded.triangles.some(t=>t.surfaceType!==0),false);
});
test('original model hit faces retain cached planes independently from optimized draw geometry',()=>{
 const node={verts:[[0,0,0],[1,0,0],[0,1,0],[0,0,5],[1,0,5],[0,1,5]],faces:[[3,4,5]],nativeCollisionFaces:[{indices:[0,1,2],normal:[0,0,1],constant:0}]},faces=cameraModelHitFaces(node);
 assert.equal(faces.length,1);assert.deepEqual(faces[0].vertices,node.verts.slice(0,3));assert.deepEqual(nativePolygonHit(faces[0].vertices,faces[0].normal,faces[0].constant,[.25,.25,1],[.25,.25,-1]),[.25,.25,0]);
 node.nativeCollisionFaces=[];assert.deepEqual(cameraModelHitFaces(node),[],'an empty original hit list stays empty even when draw triangles exist');
 delete node.nativeCollisionFaces;assert.equal(cameraModelHitFaces(node)[0].constant,-5,'ASCII original faces compute their native planes');
});

test('static polygon query returns the native crossing and normal for particle bounce without changing camera point queries',()=>{
 const root=new Group(),vertices=[[0,0,0],[2,0,0],[0,2,0]],walkmesh=[{vertices:vertices.map(v=>[v[0],v[2],-v[1]]),surfaceType:0}],query=cameraSceneQuery(root,walkmesh);
 assert.deepEqual(query.nearest([.25,.25,1],[.25,.25,-1]),[.25,.25,0]);
 assert.deepEqual(query.nearestHit([.25,.25,1],[.25,.25,-1]),{position:[.25,.25,0],normal:[0,-0,1]});
 assert.equal(query.nearestHit([.25,.25,-1],[.25,.25,1]),null);
});
