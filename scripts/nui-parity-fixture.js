import {nuiImage} from '../src/nui_image.js';
import {NetworkFeedbackView} from '../src/network_feedback_view.js';
import {NetworkFloatingTextView} from '../src/network_floating_text_view.js';
import * as THREE from 'three';
import {parse2da} from '../src/area.js';
import {decodeResourceText,RESOURCE_TYPE} from '../src/resource_archive.js';

// Synthetic toolbar and server feedback only. Installed resources stay external.
export async function checkNuiParity(){
 const check=(v,label)=>{if(!v)throw Error(label);},pause=()=>new Promise(r=>setTimeout(r,0)),report={};
 ui.reset();ui.owner=world();const pixels=new Uint8ClampedArray(64*32*4);for(let i=0;i<pixels.length;i+=4)pixels.set(i%256<128?[230,50,30,255]:[30,80,230,255],i);
 const assets={image:async()=>({width:64,height:32,data:pixels})},originalImage=ui.image;
 ui.image=(name,region)=>nuiImage(assets,name,region);
 const icon={type:'button_image',id:'slot',label:{bind:'icon'},image_region:{bind:'region'},width:40,height:40};
 apply({kind:'nui-create',token:4,id:'toolbar',layout:{title:{bind:'toolbar_title'},collapsed:false,closable:false,resizable:false,border:false,transparent:true,geometry:{x:60,y:100,w:544,h:48},root:{type:'row',children:[icon,...Array.from({length:11},(_,i)=>({type:'button_image',label:'atlas',image_region:{x:32,y:0,w:32,h:32},width:40,height:40,id:'slot'+i}))]}}});
 bind('toolbar_title','',4);bind('region',{x:0,y:0,w:32,h:32},4);bind('icon','atlas',4);await pause();
 const r=ui.windows.get(4),img=r.host.querySelector('[data-nui-id="slot"] img');await img.decode();check(img.naturalWidth===32&&img.naturalHeight===32,'Pixel crop dimensions');
 const c=document.createElement('canvas');c.width=c.height=1;c.getContext('2d').drawImage(img,0,0,1,1);check(c.getContext('2d').getImageData(0,0,1,1).data[0]===230,'Pixel crop source');
 check(r.header.hidden,'Empty-title toolbar has no header');const slot=r.host.querySelector('[data-nui-id="slot"]'),slotBounds=slot.getBoundingClientRect(),windowBounds=r.host.getBoundingClientRect();check(slotBounds.height===40&&slotBounds.width===40,'Toolbar slots stay40px square');check(slotBounds.bottom<=windowBounds.bottom&&slotBounds.top>=windowBounds.top,'Entire toolbar slot is inside the48px window');report.slotBounds={width:slotBounds.width,height:slotBounds.height,windowHeight:windowBounds.height,clippedBottom:Math.max(0,slotBounds.bottom-windowBounds.bottom)};check(r.host.querySelectorAll('button img').length===12,'Twelve toolbar slots');report.pixelCrop=true;report.headerlessToolbar=true;bind('toolbar_title','Edit toolbar',4);check(!r.header.hidden,'Nonempty bound title restores header');bind('toolbar_title','',4);check(r.header.hidden&&slot.getBoundingClientRect().height===40,'Empty bound title restores full toolbar');report.boundTitle=true;
 bind('region',{x:0,y:0,w:0,h:0},4);await pause();await img.decode();check(img.naturalWidth===64&&img.naturalHeight===32,'Zero region means full image');report.zeroRegion=true;
 bind('icon','',4);check(!img.hasAttribute('src'),'Icon cleared');bind('icon','atlas',4);await pause();await img.decode();check(img.naturalWidth===64,'Same icon restored');report.reassignment=true;
 const pending=[];ui.image=()=>new Promise(resolve=>pending.push(resolve));bind('icon','deferred',4);bind('icon','',4);bind('icon','deferred',4);check(pending.length===2,'Two distinct image requests');pending[1](await nuiImage(assets,'atlas',{x:0,y:0,w:32,h:32}));await pause();const latest=img.src;pending[0](await nuiImage(assets,'atlas'));await pause();check(img.src===latest,'Old request cannot overwrite new request');bind('icon','cleared',4);bind('icon','',4);pending[2](latest);await pause();check(!img.hasAttribute('src'),'Pending cleared icon cannot resurrect');report.imageRace=true;
 ui.image=(name,region)=>nuiImage(assets,name,region);bind('icon','atlas',4);bind('region',{x:0,y:0,w:32,h:32},4);await pause();await img.decode();ui.image=originalImage;
 // A populated2x3-toolbar grid exercises the actual icon and counter layers,
 // not just a colored image or an empty slot. Assets remain in the install.
 const icons=actualAssets?[...new Set([...parse2da(decodeResourceText(await actualAssets.resolver.getResource('spells',RESOURCE_TYPE.TWO_DA))).rows.values()].map(row=>row[Object.keys(row).find(k=>k.toLowerCase()==='iconresref')]).filter(v=>v&&v!=='****'))].slice(0,24):['test_icon'];
 for(let group=0;group<2;group++)for(let row=0;row<3;row++){
  const token=10+group*3+row,children=Array.from({length:12},(_,i)=>{const icon=icons[(group*12+row*5+i)%icons.length],draw_list=[];if(i%4!==1){if(i===2)draw_list.push({type:5,image:icon,rect:{x:4,y:4,w:32,h:32},order:1});draw_list.push({type:4,text:String(i===3?12:i%3),rect:{x:2,y:0,w:24,h:16},color:{r:255,g:255,b:0,a:255},order:1});if(i%5===0)draw_list.push({type:4,text:'X',rect:{x:28,y:22,w:12,h:16},color:{r:255,g:255,b:0,a:255},order:1});}return{type:i===2||i%4===1?'button':'button_image',label:i%4===1||i===2?'':icon,width:40,height:40,id:'filled_'+token+'_'+i,draw_list};});
  apply({kind:'nui-create',token,id:'populated',layout:{title:'',closable:false,collapsed:false,resizable:false,border:false,transparent:true,geometry:{x:24+group*570,y:380+row*52,w:544,h:48},root:{type:'col',children:[{type:'row',children}]}}});
 }
 await Promise.all([...ui.windows.values()].map(r=>r.queue));
 await Promise.all([...ui.layer.querySelectorAll('img')].filter(n=>n.src).map(n=>n.decode()));
 for(const r of [...ui.windows.values()].filter(r=>r.token>=10)){check(r.header.hidden,'Populated toolbar header hidden');for(const slot of r.host.querySelectorAll('[data-nui-id]')){const a=slot.getBoundingClientRect(),b=r.host.getBoundingClientRect();check(a.width===40&&a.height===40&&a.bottom<=b.bottom,'Full populated square remains visible');}}
 check(ui.layer.querySelectorAll('.nui-draw-list text').length>=54,'Counters and X overlays present');const deadline=performance.now()+5000;while(ui.layer.querySelectorAll('.nui-draw-list image[href]').length<6&&performance.now()<deadline)await new Promise(r=>setTimeout(r,10));check(ui.layer.querySelectorAll('.nui-draw-list image[href]').length===6,'Draw-list icons present: '+ui.layer.querySelectorAll('.nui-draw-list image[href]').length);report.populatedToolbars={windows:6,slots:72,installedIcons:Boolean(actualAssets),counterLayers:ui.layer.querySelectorAll('.nui-draw-list text').length,drawListImages:6,clippedBottom:0};
 if(actualAssets){
  const actor={id:0xfffffffe,objectType:5,areaId:1},registry=new Map([[actor.id,actor]]);Object.assign(fixtureWorld,{registry,areaId:1,localObjectId:actor.id});
  const camera=new THREE.PerspectiveCamera(45,1180/800,.1,100);camera.position.set(0,3,7);camera.lookAt(0,1,0);camera.updateMatrixWorld();const wrapper=new THREE.Object3D(),canvas=document.querySelector('#viewport');wrapper.updateMatrixWorld();
  const float=new NetworkFloatingTextView(canvas,{world,scene:()=>({objects:new Map([[actor.id,{wrapper}]])}),camera:()=>camera,canvas:()=>canvas,getResource:(...args)=>actualAssets.resolver.getResource(...args),report:(code,message)=>{throw Error(code+': '+message);}});
  const rows=[],text={raw:async v=>v.text};const view=new NetworkFeedbackView({world,text:()=>text,tables:()=>null,display:r=>rows.push(r),floating:e=>float.add(e),options:()=>({enabled:false}),report:()=>{throw Error('Unhandled script feedback');}});
  await view.receive({kind:'combat-feedback',type:94,data:{objects:{0:actor.id},integers:{0:1},strings:{0:{text:'Select the slot to assign.'}}}});await float.font('fnt_galahad14');await pause();float.update(0);check(float.entries.length===1&&float.entries[0].node,'Native-font overhead ready');check(!float.entries[0].node.hidden,'Overhead projected');check(rows[0].text==='Select the slot to assign.','Independent chat echo');check(float.entries[0].state.shadow===false,'Original prompt has no shadow');report.overhead={font:'fnt_galahad14',chatEcho:true,combatToggleIgnored:true};window.parityFloat=float;
 }
 return report;
}
