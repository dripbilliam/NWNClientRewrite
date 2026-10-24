import {withWorldPickFrame} from '../src/world_picking.js';
import * as THREE from 'three';
import {WorldHighlightView} from '../src/world_highlight_view.js';
import {NetworkScene} from '../src/network_scene.js';
import {highlightCreatureDetails} from '../src/world_highlight_assets.js';
import {NativeUiAssets} from '../src/native_ui_assets.js';
import {GameText,parseTalkTable} from '../src/talk_table.js';
import {networkResourceResult} from '../src/network_resource_bridge.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
const viewport=document.querySelector('#fixture'),canvas=document.querySelector('#world'),scene=new THREE.Scene(),root=new THREE.Group();scene.background=new THREE.Color('#273339');scene.add(root);
const renderer=new THREE.WebGLRenderer({canvas,antialias:true});renderer.setSize(1000,640);renderer.setPixelRatio(1);const camera=new THREE.PerspectiveCamera(44,1000/640,.1,100);camera.position.set(11,13,18);camera.lookAt(0,0,0);camera.updateMatrixWorld();
scene.add(new THREE.HemisphereLight(0xdfeeff,0x445544,2));const sun=new THREE.DirectionalLight(0xffffff,2);sun.position.set(3,8,4);scene.add(sun);
const floor=new THREE.Mesh(new THREE.PlaneGeometry(24,24),new THREE.MeshLambertMaterial({color:0x4f5551}));floor.rotation.x=-Math.PI/2;floor.position.y=-.04;root.add(floor);
const objects=new Map(),bindings=new Map();
const part=(parent,size,position,color)=>{const mesh=new THREE.Mesh(new THREE.BoxGeometry(...size),new THREE.MeshLambertMaterial({color}));mesh.position.set(...position);mesh.userData.nativeModelMesh=true;parent.add(mesh);return mesh;};
function add(id,type,position,name,options={}){
 const object={id,objectType:type,areaId:1,replicated:{name:{text:name},...options}},wrapper=new THREE.Group();wrapper.position.set(...position);wrapper.userData.worldObjectId=id;wrapper.userData.worldPickingPlayer=id===1;
 if(type===5){part(wrapper,[.7,1,.4],[0,1.2,0],0x9a866c);part(wrapper,[.48,.5,.45],[0,1.95,0],0xc4b096);part(wrapper,[.25,.9,.3],[-.48,1.1,0],0x8d775d);part(wrapper,[.25,.9,.3],[.48,1.1,0],0x8d775d);part(wrapper,[.28,.7,.3],[-.2,.35,0],0x564c3e);part(wrapper,[.28,.7,.3],[.2,.35,0],0x564c3e);const gear=new THREE.Group();gear.position.set(.7,1.1,0);wrapper.add(gear);part(gear,[.1,1.2,.1],[0,0,0],0xa5b3b4);}
 else part(wrapper,type===10?[1.4,2.7,.3]:type===6?[.25,.15,.45]:[1.2,.8,.8],type===10?[0,1.35,0]:type===6?[0,.08,0]:[0,.4,0],0x8d7054);
 objects.set(id,object);bindings.set(id,{wrapper});root.add(wrapper);return object;
}
add(1,5,[-5,0,-1],'Player');add(2,5,[-2,0,0],'Friendly guard',{reaction:1});add(3,5,[1,0,0],'Hostile creature',{reaction:2});add(4,9,[4,0,1],'Usable chest',{field264:1});add(5,10,[-3,0,-4],'Door');add(6,6,[0,0,3],'Dropped item');add(7,9,[4,0,-4],'Static scenery',{field264:1}).staticState={};add(8,9,[-5,0,3],'Unusable object',{field264:0});add(9,5,[3,0,-8],'Occluded creature',{reaction:2});
const wall=new THREE.Mesh(new THREE.BoxGeometry(5,4,.4),new THREE.MeshLambertMaterial({color:0x474a50}));wall.position.set(3,2,-5);root.add(wall);
const world={registry:{get:id=>objects.get(id)},areaId:1};let picks=0,worldClicks=0,enabled=true,textVersion=0,labelResolver=null;
const picking={root,world,objects:bindings,closed:false},context=()=>({identity:world,root,areaId:world.areaId,playerId:1,objects,render:id=>bindings.get(id)?.wrapper,pick:ray=>{picks++;return NetworkScene.prototype.pick.call(picking,ray,{includePlayer:true,objectsOnly:true});},textVersion});
let current=context;
const portraitCanvas=document.createElement('canvas');portraitCanvas.width=16;portraitCanvas.height=25;const brush=portraitCanvas.getContext('2d');brush.fillStyle='#334259';brush.fillRect(0,0,16,25);brush.fillStyle='#cdb18f';brush.fillRect(5,3,7,8);brush.fillStyle='#887454';brush.fillRect(3,12,11,13);
let detailReads=0;
let installedDetails=null;
if(new URLSearchParams(location.search).has('installed')){
 const resolver={getResource:async(ref,type)=>networkResourceResult(await creationFixture.resource(ref,type),ref,type)},assets=new NativeUiAssets(resolver),talk=await creationFixture.talk(),text=new GameText({base:parseTalkTable(talk.base)}),portraits=parse2da(decodeResourceText(await resolver.getResource('portraits',2017))),portrait=[...portraits.rows].find(([,r])=>r.BaseResRef&&r.BaseResRef!=='****')?.[0];
 for(const object of objects.values())if(object.objectType===5){object.replicated.portrait=portrait;object.replicated.damageLevel=0;}
 installedDetails=object=>highlightCreatureDetails(object,{assets,tables:{portraits},resolve:value=>text.resolve(value)});
}
const view=new WorldHighlightView({viewport,canvas,camera,scene,context:()=>current?.(),enabled:()=>enabled,resolve:async value=>labelResolver?labelResolver(value):value?.text??'',details:async object=>{detailReads++;return installedDetails?installedDetails(object):{portrait:portraitCanvas.toDataURL(),condition:object.replicated.damageLevel===2?'Injured':'Uninjured',level:object.replicated.damageLevel??0};},report:error=>{throw error;}});
canvas.onclick=()=>worldClicks++;
window.fixture={view,scene,root,camera,renderer,objects,bindings,world,get detailReads(){return detailReads;},get picks(){return picks;},get worldClicks(){return worldClicks;},get enabled(){return enabled;},set enabled(value){enabled=value;},set labelResolver(value){labelResolver=value;},textChanged:()=>textVersion++,disconnect:()=>{current=null;},reconnect:()=>{current=context;},screen(id,height=1){const p=bindings.get(id).wrapper.getWorldPosition(new THREE.Vector3());p.y+=height;p.project(camera);return{x:Math.round((p.x+1)*500),y:Math.round((1-p.y)*320)};},frame:0};
renderer.setAnimationLoop(()=>{withWorldPickFrame(picking,()=>view.update());renderer.render(scene,camera);fixture.frame++;});fixture.ready=true;
