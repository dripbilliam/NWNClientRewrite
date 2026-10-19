const f=Math.fround;
import {addCameraRate} from './camera_rate_input.js';
// Native mouse deltas6f1300/6f13b0 are resolution-scaled angular impulses,
// independent of frame rate. Height deliberately uses native GUI width too.
export function cameraPointerDelta(dx,dy,width){return{yaw:f(f(f(dx*-75)*.2)/f(f(width/1920)/.01)),pitch:f(f(f(-dy*75)*.15)/f(f(width/1080)/.01))};}
export class GameCameraInput{
 constructor(canvas,{active,enabled,controller}){
  this.drag=null;this.keys=new Set();this.controller=controller;this.active=active;this.enabled=enabled;
  canvas.addEventListener('pointerdown',e=>{if(!active()||!enabled()||e.button!==1)return;e.preventDefault();this.drag={id:e.pointerId,x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);});
  canvas.addEventListener('pointermove',e=>{const d=this.drag;if(!d||!active()||!enabled()||d.id!==e.pointerId)return;controller().input(cameraPointerDelta(e.clientX-d.x,e.clientY-d.y,canvas.getBoundingClientRect().width));d.x=e.clientX;d.y=e.clientY;});
  const clear=e=>{if(this.drag?.id===e.pointerId)this.drag=null;};for(const name of ['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(name,clear);
  canvas.addEventListener('wheel',e=>{if(!active()||!enabled())return;e.preventDefault();const notches=e.deltaMode===1?e.deltaY/3:e.deltaMode===2?e.deltaY:e.deltaY/100;controller().input({zoom:-notches*7.5});},{passive:false});
  window.addEventListener('keydown',e=>{if(!active()||!enabled()||e.altKey||e.ctrlKey||e.metaKey||['INPUT','TEXTAREA','SELECT'].includes(e.target?.tagName))return;if(['PageUp','PageDown','Home','End','Insert','Delete'].includes(e.key)){e.preventDefault();this.keys.add(e.key);}});
  window.addEventListener('keyup',e=>this.keys.delete(e.key));window.addEventListener('blur',()=>{this.keys.clear();this.drag=null;});
 }
 update(){if(!this.active()||!this.enabled()){this.keys.clear();this.drag=null;return;}const s=this.controller(),k=this.keys,turn=(Number(k.has('Home'))-Number(k.has('End')))*75,tilt=(Number(k.has('Insert'))-Number(k.has('Delete')))*75,zoom=(Number(k.has('PageUp'))-Number(k.has('PageDown')))*7.5;addCameraRate(s,'yaw',turn);addCameraRate(s,'pitch',tilt);if(zoom)s.zoomImpulse=f((s.zoomImpulse??0)+zoom);}
}
