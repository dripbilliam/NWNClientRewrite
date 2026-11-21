import {openLocalModule} from './local-module.mjs';
import {parseAreaModule,loadAreaWalkmesh} from '../src/area.js';
import {loadAreaCollisions,activeObjectCollisions} from '../src/door.js';
import {NativeGeometryResources,NativeAreaGeometry} from '../src/area_geometry.js';
import {parseGff} from '../src/gff.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {findWalkableHeight,moveOnWalkmesh} from '../src/walkmesh.js';
import {parseModel} from '../src/model_parser.js';
import {WalkmeshNavigator} from '../src/navigation.js';
const install='../FullDecomp/NwnRootInstall',resRef=process.argv[2]??'m0q1a';
const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`);
const area=await parseAreaModule(resRef,resolver),raw=parseGff(await resolver.getResource(resRef,RESOURCE_TYPE.ARE)).root;
const walk=await loadAreaWalkmesh(area,resolver),collisions=await loadAreaCollisions(area,resolver),obstacles=activeObjectCollisions(collisions);
const native=new NativeAreaGeometry({resRef,width:area.width,height:area.height,tilePlacements:raw.Tile_List,tilesetResRef:raw.Tileset},new NativeGeometryResources(resolver,(e,c)=>console.error(e.message,c)));
const mismatches=[],blocked=[],unsupported=[];
for(let y=.5;y<area.height*10;y+=.5)for(let x=.5;x<area.width*10;x+=.5){
 const h=findWalkableHeight(walk.triangles,x,-y);if(h===null)continue;
 const nh=await native.height([x,y]);if(Math.abs(h-nh)>.01)mismatches.push({x,y,h,nh});
 const start=[x,h,-y],end=[x,h,-y-.1];
 if(!moveOnWalkmesh(walk.triangles,start,0,-.1,.22,.9))unsupported.push({x,y,h});
 else if(!moveOnWalkmesh(walk.triangles,start,0,-.1,.22,.9,obstacles))blocked.push({x,y,h});
}
const route=new WalkmeshNavigator(walk.triangles).path([15,0,-19],[15,0,-21],obstacles);
const models=[];for(const name of new Set(area.tiles.map(t=>t.model))){const m=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));models.push({name,format:m.format,animations:m.animations.map(a=>a.name),nodes:m.nodes.filter(n=>n.verts.length).map(n=>({name:n.name,type:n.type,render:n.render,verts:n.verts.length,faces:n.faces.length,bitmap:n.bitmap}))});}
console.log(JSON.stringify({resRef,width:area.width,height:area.height,tiles:area.tiles,triangles:walk.triangles.length,obstacles:obstacles.length,placeables:area.placeables.map(p=>({model:p.model,tag:p.tag})),mismatches,unsupported,blocked,route,models},null,2));
