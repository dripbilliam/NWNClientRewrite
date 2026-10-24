import {Object3D,Material} from 'three';
import {isLocalRendererHook} from './renderer_local_hooks.js';
const fields=['ambientLightColor','lightProbe','directionalLights','directionalLightShadows','spotLights','spotLightShadows','pointLights','pointLightShadows','hemisphereLights','rectAreaLights','directionalShadowMatrix','spotLightMatrix','pointShadowMatrix'];
const textureFields=['map','alphaMap','lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','envMap'];
const records=new WeakMap(),ob=Object3D.prototype,mb=Material.prototype;
// One shared call target; no accessors on Three's hot needsUpdate fields and
// no sampler interception. A new pass always executes the first numeric upload.
function numericSet(gl,value,textures){const record=records.get(this),owner=record.owner;if(owner.active&&record.pass===owner.pass&&record.value===value){owner.stats.skipped++;return;}const result=record.before.call(this,gl,value,textures);if(owner.active){record.pass=owner.pass;record.value=value;owner.stats.uploads++;}return result;}
export class RendererNumericLightCache{
 constructor(renderer,{enabled=false}={}){this.renderer=renderer;this.enabled=enabled;this.programs=new WeakSet();this.records=new Set();this.pass=0;this.active=false;this.running=false;this.stats={uploads:0,skipped:0};this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);}
 compatible(scene,camera){let safe=!scene.overrideMaterial&&!camera.isArrayCamera&&!this.renderer.xr?.enabled&&scene.onBeforeRender===ob.onBeforeRender&&scene.onAfterRender===ob.onAfterRender;scene.traverseVisible(object=>{if(object.onAfterRender!==ob.onAfterRender||object.onBeforeRender!==ob.onBeforeRender&&!isLocalRendererHook(object.onBeforeRender))safe=false;for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[]){if(material.onBeforeRender!==mb.onBeforeRender)safe=false;for(const key of textureFields)if(material[key]?.onUpdate)safe=false;}});return safe;}
 install(program){if(this.programs.has(program))return;this.programs.add(program);const uniforms=program.getUniforms().map;for(const name of fields){const group=uniforms[name];if(!group||records.has(group))continue;const record={group,before:group.setValue,owner:this,pass:-1,value:null};records.set(group,record);this.records.add(record);group.setValue=numericSet;}}
 render(scene,camera,draw=()=>this.renderer.render(scene,camera)){
  this.stats={uploads:0,skipped:0};if(!this.enabled||this.running||!this.compatible(scene,camera)){this.stats.fallback=this.enabled;return draw();}
  const renderer=this.renderer,before=renderer.renderBufferDirect,use=renderer.state.useProgram,owner=this;let current=null;this.pass++;this.running=true;
  renderer.renderBufferDirect=(c,s,g,m,o,group)=>{const previous=current;current=c===camera&&s===scene&&m.isMeshLambertMaterial?m:null;try{return before.call(renderer,c,s,g,m,o,group);}finally{current=previous;}};
  renderer.state.useProgram=function(program){const changed=use.call(this,program);owner.active=false;if(current){const compiled=renderer.properties.get(current).currentProgram;if(compiled?.program===program){owner.install(compiled);owner.active=true;}}return changed;};
  try{return draw();}finally{this.active=false;this.running=false;renderer.renderBufferDirect=before;renderer.state.useProgram=use;}
 }
 reset(){this.active=false;for(const record of this.records){if(record.group.setValue===numericSet)record.group.setValue=record.before;records.delete(record.group);record.value=null;}this.records.clear();this.programs=new WeakSet();this.stats={uploads:0,skipped:0};}
 snapshot(){return{...this.stats,enabled:this.enabled,groups:this.records.size};}
 dispose(){this.reset();this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);}
}
