import {Vector3,Vector4,Material} from 'three';
import {batchRendererHook,rendererBatchHook,localRendererHook,isLocalRendererHook} from './renderer_local_hooks.js';
import {observeRendererHierarchy} from './renderer_hierarchy.js';
import {targetPreviewColor} from './target_preview.js';
const prefix='nwnTarget_';
// Use the installed/active original shader; keep proprietary shader sources
// outside the repository. Namespace symbols and normalize desktop GLSL syntax.
export async function loadTargetPreviewShader(resolver){
 const sources=new Map();async function expand(name,stack=[]){if(stack.includes(name)||stack.length>16)throw Error('Native target shader include cycle');let s=sources.get(name);if(s===undefined){s=new TextDecoder().decode(await resolver.getResource(name,2069));if(s.length>1024*1024)throw Error('Native target shader exceeds limits');sources.set(name,s);}let at=0,out='';for(const m of s.matchAll(/^\s*#include\s+"([\w]+)"\s*$/gm)){out+=s.slice(at,m.index)+await expand(m[1],[...stack,name]);at=m.index+m[0].length;}return out+s.slice(at);}
 const source='#define POSITION_WORLD 1\n#define PI 3.14159265358979323846\n#define COLOR_WHITE vec4(1.0)\nvarying vec3 vPosWorld;\n'+await expand('inc_target'),symbols=new Set();
 for(const m of source.matchAll(/^\s*#define\s+([A-Za-z_]\w*)/gm))symbols.add(m[1]);
 for(const m of source.matchAll(/\b(?:uniform|varying|attribute|const)\s+(?:(?:lowp|mediump|highp)\s+)?(?:float|int|bool|[ib]?vec[234]|mat[234]|sampler\w+)\s+(?:(?:lowp|mediump|highp)\s+)?([A-Za-z_]\w*)/g))symbols.add(m[1]);
 for(const m of source.matchAll(/\b(?:void|float|int|bool|[ib]?vec[234]|mat[234])\s+([A-Za-z_]\w*)\s*\(/g))symbols.add(m[1]);
 if(!symbols.has('ApplyTargetGroundHighlighting')||!symbols.has('targetShape'))throw Error('Native target shader declarations are unavailable');
 const fragment=source.replace(/\b([ib]?vec[234]|float|int)\s+(highp|mediump|lowp)\b/g,'$2 $1').replace(/\b(\d+\.\d+)f\b/g,'$1').replace(/\b[A-Za-z_]\w*\b/g,name=>symbols.has(name)?prefix+name:name);let hash=2166136261;for(const c of source)hash=Math.imul(hash^c.charCodeAt(0),16777619);
 return{fragment,resources:[...sources.keys()],cacheKey:(hash>>>0).toString(16)};
}
export class TargetPreviewShader{
 constructor(){this.materials=new Map();this.uniforms={};for(const name of ['targetShape','targetShapeHarmsEnemies','targetShapeHarmsAllies','targetShapeHelpsAllies','targetShapeIgnoresSelf','targetShapeOriginOnSelf','targetShapeSizeX','targetShapeSizeY','targetShapeSpellId','targetShapeFeatId','targetShapeSpellRange','targetObjectType','worldtimerTimeOfDay'])this.uniforms[name]={value:0};this.uniforms.targetShapeColour={value:new Vector4()};this.uniforms.targetWorldCoords={value:new Vector3()};this.uniforms.playerPosition={value:new Vector3()};}
 async load(resolver){this.shader=await loadTargetPreviewShader(resolver);return this;}
 bind(root){
  if(this.root!==root){this.hierarchy?.release();this.hierarchy=observeRendererHierarchy(root);this.root=root;this.revision=-1;}if(this.revision===this.hierarchy.revision)return;this.revision=this.hierarchy.revision;
  const used=new Set();for(const mesh of this.hierarchy.nodes){if(!mesh.isMesh||!mesh.userData.nativeModelMesh)continue;for(const material of Array.isArray(mesh.material)?mesh.material:[mesh.material]){
   used.add(material);if(this.materials.has(material))continue;
   let inherited=false;const seen=new Set();for(let hook=material.onBeforeCompile;!seen.has(hook);){seen.add(hook);const d=rendererBatchHook(hook);if(!d)break;if(d.kind==='target-preview'&&d.token===this&&d.cacheKey===this.shader.cacheKey){inherited=true;break;}hook=d.before;}
   if(inherited){this.materials.set(material,{inherited:true});continue;}
   const before=material.onBeforeCompile,key=material.customProgramCacheKey;
   const compile=(shader,renderer)=>{before.call(material,shader,renderer);for(const[name,value]of Object.entries(this.uniforms))shader.uniforms[prefix+name]=value;
    // Keyhole materials can inherit this hook when cloning an already bound
    // source. Rebinding that clone must update the uniform owner without
    // inserting a second copy of the namespaced shader declarations.
    const vertexBound=shader.vertexShader.includes('varying vec3 '+prefix+'vPosWorld;'),fragmentBound=shader.fragmentShader.includes(prefix+'ApplyTargetGroundHighlighting');
    if(vertexBound||fragmentBound){if(!vertexBound||!fragmentBound)throw Error('Incomplete inherited target-preview shader');return;}
    if(!shader.vertexShader.includes('#include <project_vertex>')||!shader.fragmentShader.includes('#include <opaque_fragment>'))throw Error('Unsupported target-preview material stage');
    shader.vertexShader='varying vec3 '+prefix+'vPosWorld;\n'+shader.vertexShader.replace('#include <project_vertex>','#include <project_vertex>\nvec4 nwnTarget_world = modelMatrix * vec4(transformed, 1.0);\n'+prefix+'vPosWorld = vec3(nwnTarget_world.x, -nwnTarget_world.z, nwnTarget_world.y);');
    shader.fragmentShader=this.shader.fragment+'\n'+shader.fragmentShader.replace('#include <opaque_fragment>','#include <opaque_fragment>\n'+prefix+'ApplyTargetGroundHighlighting(gl_FragColor);');
   };
   const cache=()=>{const inherited=key.call(material),tag='|native-target-v1|'+this.shader.cacheKey;return inherited.includes(tag)?inherited:inherited+tag;};material.onBeforeCompile=compile;material.customProgramCacheKey=cache;material.needsUpdate=true;this.materials.set(material,{before,key,compile,cache});
   if(before===Material.prototype.onBeforeCompile||isLocalRendererHook(before))batchRendererHook(compile,{kind:'target-preview',token:this,before,compile,cacheKey:this.shader.cacheKey});
   if(key===Material.prototype.customProgramCacheKey||isLocalRendererHook(key))localRendererHook(cache);
  }}for(const[material,s]of this.materials)if(!used.has(material)){if(material.onBeforeCompile===s.compile)material.onBeforeCompile=s.before;if(material.customProgramCacheKey===s.cache)material.customProgramCacheKey=s.key;this.materials.delete(material);}
 }
 update({preview=null,player,point,type=0,time=performance.now()}={}){
  const u=this.uniforms,enabled=Boolean(preview&&player&&point&&type);u.targetObjectType.value=enabled?type:0;if(!enabled)return;
  const flags=preview.flags|0;u.targetShape.value=flags&32&&type!==2?0:preview.shape|0;u.targetShapeSizeX.value=Number(preview.sizeX)||0;u.targetShapeSizeY.value=Number(preview.sizeY)||0;u.targetShapeSpellRange.value=Number(preview.range)||0;u.targetShapeSpellId.value=preview.spellId??-1;u.targetShapeFeatId.value=preview.featId??-1;
  for(const[name,bit]of [['HarmsEnemies',1],['HarmsAllies',2],['HelpsAllies',4],['IgnoresSelf',8],['OriginOnSelf',16]])u['targetShape'+name].value=Number(Boolean(flags&bit));
  u.targetShapeColour.value.fromArray(targetPreviewColor(flags));u.targetWorldCoords.value.fromArray(point);u.playerPosition.value.fromArray(player);u.worldtimerTimeOfDay.value=Math.trunc(time)%86400000;
 }
 snapshot(){const u=this.uniforms;return{loaded:Boolean(this.shader),enabled:Boolean(u.targetObjectType.value),shape:u.targetShape.value,range:u.targetShapeSpellRange.value,point:u.targetWorldCoords.value.toArray(),materials:this.materials.size};}
 dispose(){this.update();for(const[material,s]of this.materials){if(material.onBeforeCompile===s.compile)material.onBeforeCompile=s.before;if(material.customProgramCacheKey===s.cache)material.customProgramCacheKey=s.key;if(!s.inherited)material.needsUpdate=true;}this.materials.clear();this.hierarchy?.release();this.hierarchy=null;this.root=null;}
}
