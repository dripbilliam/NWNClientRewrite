import {Box3,Matrix4,Vector2,Vector3,Object3D,Material} from 'three';
import {localRendererHook,isLocalRendererHook,batchRendererHook} from './renderer_local_hooks.js';
import {canKeyholeDissolve,keyholeCameraPlane} from './camera_keyhole.js';
import {RESOURCE_TYPE} from './resource_archive.js';
import {observeRendererHierarchy} from './renderer_hierarchy.js';
const resourceType=RESOURCE_TYPE.SHD,prefix='nwnKeyhole_';
const stageDefines=stage=>`#define SHADER_TYPE ${stage}\n#define KEYHOLING 1\n#define KEYHOLING_ENABLED 1\n#define NO_DISCARD 0\n#define LIGHTING 0\n#define FOG 0\n#define MAX_NUM_LIGHTS 0\n#define MAX_NUM_BONES 0\n#define FRAGMENT_LIGHTING 0\n#define GAMMA_CORRECTION 0\n#define SHADER_DEBUG_MODE 0\n#define SHADER_QUALITY_MODE 1\n#define POSTPROCESSING_TYPES_ENABLED 0\n`;
// Keep the installed shader in the active resolver, not in the repository.
// Only namespace its declarations/macros to coexist with Three's GLSL.
export async function loadKeyholeShader(resolver){
 const sources=new Map();
 async function expand(name,stack=[]){
  if(stack.includes(name)||stack.length>16)throw new Error('Native keyhole shader include cycle');
  let source=sources.get(name);if(source===undefined){source=new TextDecoder().decode(await resolver.getResource(name,resourceType));if(source.length>1024*1024)throw new Error('Native keyhole shader is too large');sources.set(name,source);}
  const matches=[...source.matchAll(/^\s*#include\s+"([\w]+)"\s*$/gm)];let at=0,out='';
  for(const match of matches){out+=source.slice(at,match.index)+await expand(match[1],[...stack,name]);at=match.index+match[0].length;}return out+source.slice(at);
 }
 const source=await expand('inc_keyhole'),symbols=new Set();
 for(const match of (stageDefines(1)+source).matchAll(/^\s*#define\s+([A-Za-z_]\w*)/gm))symbols.add(match[1]);
 for(const match of source.matchAll(/\b(?:uniform|varying|attribute|const)\s+(?:(?:lowp|mediump|highp)\s+)?(?:float|int|bool|[ib]?vec[234]|mat[234]|sampler\w+)\s+(?:(?:lowp|mediump|highp)\s+)?([A-Za-z_]\w*)/g))symbols.add(match[1]);
 for(const match of source.matchAll(/\b(?:void|float|int|bool|[ib]?vec[234]|mat[234])\s+([A-Za-z_]\w*)\s*\(/g))symbols.add(match[1]);
 for(const name of ['ApplyKeyhole','SetupKeyholeFactors','vPosView','fFragCamOffset','m_view_inv','screenParams','pixelParams','keyholeCanDissolve','cameraPitch','playerCameraDist','playerPosition','keyholeDiameterMin','keyholeDiameterMax','keyholeMinZOffset'])if(!symbols.has(name))throw new Error(`Native keyhole shader declaration ${name} is unavailable`);
 // The desktop source can macro-disable the GLSL discard keyword and places
 // precision after two bbox types. Preserve keyword semantics; normalize that
 // declaration syntax for WebGL ES without changing executable shader math.
 symbols.delete('discard');
 const rename=text=>text.replace(/\b([ib]?vec[234]|float|int)\s+(highp|mediump|lowp)\b/g,'$2 $1').replace(/\b[A-Za-z_]\w*\b/g,name=>symbols.has(name)?prefix+name:name);
 let hash=2166136261;for(let i=0;i<source.length;i++)hash=Math.imul(hash^source.charCodeAt(i),16777619);
 return{vertex:rename(stageDefines(1)+source),fragment:rename(stageDefines(2)+source),resources:[...sources.keys()],symbols:[...symbols],cacheKey:(hash>>>0).toString(16)};
}
const nativeBasis=new Matrix4().set(1,0,0,0,0,0,-1,0,0,1,0,0,0,0,0,1);
export class CameraKeyholePresentation{
 constructor({renderer,camera,report=()=>{}}){
  Object.assign(this,{renderer,camera,report});this.bindings=new Map();this.closed=false;this.enabled=false;this.specializeInactive=false;this.plane=[0,0,1,0];this.height=0;this.count=0;
  this.uniforms={screenParams:{value:new Vector2()},pixelParams:{value:new Vector3()},m_view_inv:{value:new Matrix4()},cameraPitch:{value:50},playerCameraDist:{value:20},playerPosition:{value:new Vector3()},keyholeDiameterMin:{value:Math.fround(.4)},keyholeDiameterMax:{value:Math.fround(.9)},keyholeMinZOffset:{value:1}};
 }
 async load(resolver){this.shader=await loadKeyholeShader(resolver);return this;}
 bind(root){
  if(this.hierarchyRoot!==root){this.hierarchy?.release();this.hierarchy=observeRendererHierarchy(root);this.hierarchyRoot=root;this.boundRevision=-1;}
  if(this.boundRevision===this.hierarchy.revision&&!this.pendingGeometry)return;
  this.boundRevision=this.hierarchy.revision;this.pendingGeometry=false;const eligible=new Set();
  root.traverse(tile=>{if(!tile.userData.nativeStaticTile)return;tile.traverse(mesh=>{
   if(!mesh.isMesh||!mesh.userData.nativeModelMesh)return;
   if(!mesh.geometry?.attributes.position){this.pendingGeometry=true;return;}
   eligible.add(mesh);if(this.bindings.has(mesh))return;
   // Tile instances share template materials. Each draw needs its own native
   // can-dissolve flag; do not modify a material used by another tile/object.
   const can={value:0},originalMaterial=mesh.material,originals=Array.isArray(originalMaterial)?originalMaterial:[originalMaterial],oldRender=mesh.onBeforeRender,states=[];
   for(const original of originals){const material=original.clone(),before=original.onBeforeCompile,key=original.customProgramCacheKey;
    material.onBeforeCompile=(shader,renderer)=>{before.call(material,shader,renderer);if(this.specializeInactive&&can.value===0)return;for(const [name,value]of Object.entries(this.uniforms))shader.uniforms[prefix+name]=value;shader.uniforms[prefix+'keyholeCanDissolve']=can;
     if(!shader.vertexShader.includes('#include <project_vertex>')||!shader.fragmentShader.includes('#include <opaque_fragment>'))throw new Error('Native keyhole shader adapter has no supported material stage');
     shader.vertexShader=this.shader.vertex+'\n'+shader.vertexShader.replace('#include <project_vertex>','#include <project_vertex>\n'+prefix+'vPosView = mvPosition.xyz;\n'+prefix+'SetupKeyholeFactors();');
     shader.fragmentShader=this.shader.fragment+'\n'+shader.fragmentShader.replace('#include <opaque_fragment>','#include <opaque_fragment>\n'+prefix+'ApplyKeyhole(gl_FragColor);');
    };
    material.customProgramCacheKey=()=>key.call(original)+'|native-keyhole-v1|'+this.shader.cacheKey+(this.specializeInactive?'|can='+can.value:'');material.needsUpdate=true;states.push({material,programCan:0});
    if((before===Material.prototype.onBeforeCompile||isLocalRendererHook(before))&&(key===Material.prototype.customProgramCacheKey||isLocalRendererHook(key))){batchRendererHook(material.onBeforeCompile,{kind:'keyhole',token:this,before,can});localRendererHook(material.customProgramCacheKey);}
   }
   mesh.material=Array.isArray(originalMaterial)?states.map(s=>s.material):states[0].material;
   const bounds=new Box3();
   mesh.onBeforeRender=(...args)=>{oldRender.apply(mesh,args);let value=0;if(this.enabled){
    // The renderer already updated this leaf's world matrix. setFromObject
    // walks its ancestors again for every visible tile mesh on every draw.
    // Preserve the general subtree/skinned path when its bounds differ.
    if(!mesh.children.length&&!mesh.isSkinnedMesh&&mesh.boundingBox===undefined&&oldRender===Object3D.prototype.onBeforeRender){if(mesh.geometry.boundingBox===null)mesh.geometry.computeBoundingBox();bounds.copy(mesh.geometry.boundingBox).applyMatrix4(mesh.matrixWorld);}else bounds.setFromObject(mesh);
    const min=[bounds.min.x,-bounds.max.z,bounds.min.y],max=[bounds.max.x,-bounds.min.z,bounds.max.y];value=Number(canKeyholeDissolve({enabled:true,min,max,plane:this.plane,height:this.height}));}can.value=value;if(this.specializeInactive)for(const state of states)if(state.programCan!==value){state.programCan=value;state.material.needsUpdate=true;}};
   if(oldRender===Object3D.prototype.onBeforeRender||isLocalRendererHook(oldRender))localRendererHook(mesh.onBeforeRender);
   if(oldRender===Object3D.prototype.onBeforeRender)batchRendererHook(mesh.onBeforeRender,{kind:'keyhole-state',token:this,can});
   this.bindings.set(mesh,{oldRender,states,can,originalMaterial});
  });});
  for(const [mesh,b]of this.bindings)if(!eligible.has(mesh)){mesh.onBeforeRender=b.oldRender;mesh.material=b.originalMaterial;for(const s of b.states)s.material.dispose();this.bindings.delete(mesh);}
 }
 update(root,player,controller,enabled=true){
  if(this.closed||!this.shader)return;this.bind(root);this.enabled=Boolean(enabled&&player&&controller);if(!this.enabled)return;
  const p=[player.x,-player.z,player.y],camera=this.camera,c=[camera.position.x,-camera.position.z,camera.position.y],direction=camera.getWorldDirection(new Vector3()),forward=[direction.x,-direction.z,direction.y];
  this.plane=keyholeCameraPlane(c,forward,p);this.height=Math.fround(p[2]+this.uniforms.keyholeMinZOffset.value);camera.updateMatrixWorld();
  const size=this.renderer.getDrawingBufferSize(new Vector2());this.uniforms.screenParams.value.copy(size);this.uniforms.pixelParams.value.set(1/size.x,1/size.y,size.x/size.y);
  this.uniforms.m_view_inv.value.multiplyMatrices(nativeBasis,camera.matrixWorld);this.uniforms.playerPosition.value.fromArray(p);this.uniforms.cameraPitch.value=controller.pitch;this.uniforms.playerCameraDist.value=controller.distance;
 }
 setInactivePrograms(enabled){enabled=Boolean(enabled);if(enabled===this.specializeInactive)return;this.specializeInactive=enabled;for(const b of this.bindings.values())for(const state of b.states){state.programCan=undefined;state.material.needsUpdate=true;}}
 snapshot(){return{loaded:Boolean(this.shader),enabled:this.enabled,specializeInactive:this.specializeInactive,meshes:this.bindings.size,eligible:[...this.bindings.values()].filter(v=>v.can.value===1).length,resources:this.shader?.resources??[],plane:this.plane,height:this.height};}
 dispose({retire=dispose=>dispose()}={}){this.closed=true;for(const [mesh,b]of this.bindings){mesh.onBeforeRender=b.oldRender;mesh.material=b.originalMaterial;for(const s of b.states)retire(()=>s.material.dispose());}this.bindings.clear();this.hierarchy?.release();this.hierarchy=null;this.hierarchyRoot=null;}
}
