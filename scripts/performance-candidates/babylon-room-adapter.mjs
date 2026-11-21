// Private offline engine adapter. No network, installed-resource discovery or
// gameplay entry-point changes. Source objects/assets remain owned by NWN.
import * as T from 'three';
import {WebGPUEngine} from '@babylonjs/core/Engines/webgpuEngine.js';
import {Scene} from '@babylonjs/core/scene.js';
import {Mesh} from '@babylonjs/core/Meshes/mesh.js';
import {Geometry} from '@babylonjs/core/Meshes/geometry.js';
import {VertexData} from '@babylonjs/core/Meshes/mesh.vertexData.js';
import {SubMesh} from '@babylonjs/core/Meshes/subMesh.js';
import {FreeCamera} from '@babylonjs/core/Cameras/freeCamera.js';
import {Matrix,Vector3,Vector4} from '@babylonjs/core/Maths/math.vector.js';
import {Color4} from '@babylonjs/core/Maths/math.color.js';
import {ShaderMaterial} from '@babylonjs/core/Materials/shaderMaterial.js';
import {UniformBuffer} from '@babylonjs/core/Materials/uniformBuffer.js';
import {RawTexture} from '@babylonjs/core/Materials/Textures/rawTexture.js';
import {Texture} from '@babylonjs/core/Materials/Textures/texture.js';
import {Constants} from '@babylonjs/core/Engines/constants.js';
import {ShaderLanguage} from '@babylonjs/core/Materials/shaderLanguage.js';
import {decodeS3tc,isS3tcFormat} from '../../src/s3tc_decode.js';

const requireValue=(value,message)=>{if(!value)throw Error(message);};
const identityUv=[1,0,0,0,1,0,0,0,1];
const sameMatrix=(a,b)=>{if(!a)return false;for(let i=0;i<16;i++)if(a[i]!==b[i])return false;return true;};
export function roomTexturePixels(map){
 if(!map)return{data:Uint8Array.of(255,255,255,255),width:1,height:1};
 if(map.isCompressedTexture&&isS3tcFormat(map.format)){
  const mip=map.mipmaps[0];return{data:decodeS3tc(mip.data,mip.width,mip.height,map.format),width:mip.width,height:mip.height};
 }
 const image=map.image;
 requireValue(map.isDataTexture&&map.format===T.RGBAFormat&&map.type===T.UnsignedByteType&&image?.data instanceof Uint8Array,'unsupported-texture');
 requireValue(image.width>0&&image.height>0&&image.data.length===image.width*image.height*4,'invalid-texture-storage');
 return{data:image.data.slice(),width:image.width,height:image.height};
}

export function roomDrawRange(geometry,group){
 const range=geometry.drawRange,limit=geometry.index?.count??geometry.attributes.position.count;
 const begin=Math.max(0,range.start,group?.start??0),end=Math.min(limit,range.start+range.count,group?group.start+group.count:Infinity);
 requireValue(Number.isSafeInteger(begin)&&Number.isSafeInteger(end)&&begin>=0&&end>=0,'invalid-draw-range');
 return{begin,count:Math.max(0,end-begin)};
}

const frameDeclaration=lightLimit=>`struct NwnFrame {sourceView:mat4x4f,sourceProjection:mat4x4f,ambient:vec4f,lightData:array<vec4f,${Math.max(2,lightLimit*2)}>};var<uniform> nwnFrame:NwnFrame;\n`;
const vertexSource=lightLimit=>frameDeclaration(lightLimit)+`
attribute position: vec3f;
attribute normal: vec3f;
attribute uv: vec2f;
attribute particleColor: vec4f;
uniform world: mat4x4f;
uniform sourceNormal: mat4x4f;
uniform uvRow0: vec4f;
uniform uvRow1: vec4f;
uniform params: vec4f;
varying mapUv: vec2f;
varying viewPosition: vec3f;
varying viewNormal: vec3f;
varying particleTint: vec4f;
@vertex fn main(input: VertexInputs)->FragmentInputs {
 let worldPosition=select(uniforms.world*vec4f(input.position,1.),vec4f(input.position,1.),uniforms.params.z>0.5);
 let viewPosition=nwnFrame.sourceView*worldPosition;
 var clip=nwnFrame.sourceProjection*viewPosition;
 clip.z=(clip.z+clip.w)*0.5;
 vertexOutputs.position=clip;
 vertexOutputs.viewPosition=viewPosition.xyz;
 vertexOutputs.viewNormal=normalize((uniforms.sourceNormal*vec4f(input.normal,0.)).xyz);
 vertexOutputs.mapUv=vec2f(dot(vec3f(input.uv,1.),uniforms.uvRow0.xyz),dot(vec3f(input.uv,1.),uniforms.uvRow1.xyz));
 vertexOutputs.particleTint=input.particleColor;
}`;

const fragmentSource=lightLimit=>frameDeclaration(lightLimit)+`
uniform tint: vec4f;
uniform emissive: vec4f;
uniform params: vec4f;
uniform outputOptions: vec4f;
varying mapUv: vec2f;
varying viewPosition: vec3f;
varying viewNormal: vec3f;
varying particleTint: vec4f;
var baseMapSampler: sampler;
var baseMap: texture_2d<f32>;
fn encodeSRGB(linear:vec3f)->vec3f {
 return select(1.055*pow(max(linear,vec3f(0.)),vec3f(0.41666))-vec3f(0.055),linear*12.92,linear<vec3f(0.0031308));
}
@fragment fn main(input: FragmentInputs)->FragmentOutputs {
 var color=textureSample(baseMap,baseMapSampler,input.mapUv)*uniforms.tint;
 if(uniforms.params.z>0.5){color*=input.particleTint;}
 if(color.a<uniforms.params.x){discard;}
 if(uniforms.params.y>0.5){
  var normal=normalize(input.viewNormal);
  if(uniforms.params.w<0.){normal=-normal;}
  if(uniforms.params.w>1.5&&!input.frontFacing){normal=-normal;}
  var direct=vec3f(0.);
  for(var i=0u;i<u32(nwnFrame.ambient.w);i++){
   let posDecay=nwnFrame.lightData[i*2u];let rgbDistance=nwnFrame.lightData[i*2u+1u];
   if(all(rgbDistance.rgb==vec3f(0.))){continue;}
   let offset=posDecay.xyz-input.viewPosition;let distance=length(offset);
   var attenuation=1./max(pow(distance,posDecay.w),0.01);
   if(posDecay.w<0.){attenuation=1./(1.-posDecay.w*distance*distance);}
   else if(rgbDistance.w>0.){let factor=clamp(1.-pow(distance/rgbDistance.w,4.),0.,1.);attenuation*=factor*factor;}
   var cosine=clamp(dot(normal,normalize(offset)),0.,1.);
   if(posDecay.w<0.&&rgbDistance.w<0.){cosine=clamp(dot(normal,normal),0.,1.);}
   let irradiance=cosine*(rgbDistance.rgb*attenuation);
   direct+=irradiance*(color.rgb*0.3183098861837907);
  }
  color=vec4f(direct+nwnFrame.ambient.rgb*(color.rgb*0.3183098861837907)+uniforms.emissive.rgb,color.a);
 }
 if(uniforms.outputOptions.y>0.5){color.a=1.;}
 if(uniforms.outputOptions.x>0.5){color=vec4f(encodeSRGB(color.rgb),color.a);}
 fragmentOutputs.color=color;
}`;

// This uses Babylon's scene, mesh, geometry, material, texture, uniform and
// render-bundle owners, rather than calling WebGPU draws behind the engine.
// NWN-specific Lambert attenuation is intentionally a custom WGSL material.
export class BabylonRoomAdapter{
 static async create({canvas,...options}){
  requireValue(navigator.gpu,'WebGPU unavailable');
  const engine=new WebGPUEngine(canvas,{antialias:false,adaptToDeviceRatio:false,powerPreference:'high-performance',enableAllFeatures:false,swapChainFormat:'rgba8unorm'});
  try{await engine.initAsync();engine.compatibilityMode=false;return new BabylonRoomAdapter({...options,engine,ownsEngine:true});}
  catch(error){engine.dispose();throw error;}
 }
 constructor({engine,items,lightState={point:[],ambient:[0,0,0]},lit=true,particles=true,srgb=false,ownsEngine=false}){
  this.engine=engine;this.ownsEngine=ownsEngine;this.disposed=false;this.rows=[];this.excluded={};this.textures=new Map();this.geometries=new Map();this.revision=0;this.errors=[];
  this.onGPUError=event=>this.errors.push(event.error?.message??'Unknown WebGPU error');engine._device?.addEventListener('uncapturederror',this.onGPUError);
  this.lightState=lightState;this.lit=lit;this.particles=particles;this.srgb=srgb;
  this.lightLimit=Math.max(1,lightState.point.length);requireValue(this.lightLimit<=256,'Room light capacity exceeded');
  this.lightData=new Array(this.lightLimit*8).fill(0);this.ambient=new Vector4();
  if(engine.supportsUniformBuffers){this.frameBuffer=new UniformBuffer(engine,undefined,true,'NwnFrame',false,false);this.frameBuffer.addUniform('sourceView',16);this.frameBuffer.addUniform('sourceProjection',16);this.frameBuffer.addUniform('ambient',4);this.frameBuffer.addUniform('lightData',4,this.lightLimit*2);this.frameBuffer.create();}
  this.scene=new Scene(engine);this.scene.useRightHandedSystem=true;this.scene.clearColor=new Color4(0,0,0,1);this.scene.autoClear=true;this.scene.skipPointerMovePicking=true;
  this.camera=new FreeCamera('offline-source-camera',Vector3.Zero(),this.scene);this.scene.activeCamera=this.camera;
  this.view=Matrix.Identity();this.projection=Matrix.Identity();this.camera._getViewMatrix=()=>this.view;
  this.viewSource=null;this.poseStats={worldUpdates:0,normalUpdates:0,worldReused:0,normalReused:0};this.frameMaps=new Set();
  this.normal=new T.Matrix3();this.modelView=new T.Matrix4();this.normal4=Matrix.Identity();
  const order=(a,b)=>a.getMesh().metadata.order-b.getMesh().metadata.order;
  this.scene.setRenderingOrder(0,order,order,order);
  try{for(const item of items)this.add(item);}catch(error){this.dispose();throw error;}
 }
 omit(reason){this.excluded[reason]=(this.excluded[reason]??0)+1;}
 texture(map){
  if(this.textures.has(map))return this.textures.get(map);
  const pixels=roomTexturePixels(map),{width,height}=pixels;
  requireValue(width<=this.engine.getCaps().maxTextureSize&&height<=this.engine.getCaps().maxTextureSize,'texture-capacity');
  const data=new Uint8Array(pixels.data.length);
  for(let y=0;y<height;y++)data.set(pixels.data.subarray(y*width*4,(y+1)*width*4),(map?.flipY?height-1-y:y)*width*4);
  const texture=new RawTexture(data,width,height,Constants.TEXTUREFORMAT_RGBA,this.scene,false,false,Texture.BILINEAR_SAMPLINGMODE,Constants.TEXTURETYPE_UNSIGNED_BYTE,0,map?.colorSpace===T.SRGBColorSpace);
  const wrap=value=>value===T.RepeatWrapping?Texture.WRAP_ADDRESSMODE:value===T.MirroredRepeatWrapping?Texture.MIRROR_ADDRESSMODE:Texture.CLAMP_ADDRESSMODE;
  texture.wrapU=wrap(map?.wrapS);texture.wrapV=wrap(map?.wrapT);texture.hasAlpha=true;texture.anisotropicFilteringLevel=1;
  const row={texture,pixels};this.textures.set(map,row);return row;
 }
 add(item){
  const {object,geometry:g,material:m}=item,particle=!!object.userData?.mdlEmitter&&!!m.uniforms?.particleMap;
  if(!object.isMesh||object.isSkinnedMesh||object.isInstancedMesh||object.isBatchedMesh||g.isInstancedBufferGeometry||!g.attributes.position){this.omit('unsupported-object');return;}
  if(particle&&!this.particles){this.omit('particles-disabled');return;}
  if(!(m.isMeshBasicMaterial||m.isMeshLambertMaterial||particle)||m.wireframe||m.clippingPlanes?.length||m.alphaMap||m.lightMap||m.emissiveMap||m.vertexColors||m.flatShading){this.omit('unsupported-material');return;}
  if(m.stencilWrite||m.premultipliedAlpha||m.depthFunc!==T.LessEqualDepth||m.transparent&&m.side===T.DoubleSide&&!m.forceSinglePass){this.omit('unsupported-render-state');return;}
  if(m.blending!==T.NormalBlending&&m.blending!==T.NoBlending&&!(particle&&m.blending===T.CustomBlending&&m.blendSrc===T.SrcAlphaFactor&&[T.OneFactor,T.OneMinusSrcAlphaFactor].includes(m.blendDst)&&m.blendEquation===T.AddEquation)){this.omit('unsupported-blend');return;}
  const map=particle?m.uniforms.particleMap.value:m.map;let texture;try{texture=this.texture(map);}catch(error){this.omit(error.message);return;}
  const range=roomDrawRange(g,item.group);if(!range.count)return;
  const key=g.uuid+':'+(map?.channel??0),uvName=map?.channel?'uv'+map.channel:'uv';
  let cached=this.geometries.get(key);
  if(!cached){
   const data=new VertexData(),count=g.attributes.position.count;
   data.positions=this.attribute(g.attributes.position,3,count);data.normals=this.attribute(g.attributes.normal,3,count,[0,1,0]);data.uvs=this.attribute(g.attributes[uvName],2,count);data.indices=g.index?g.index.array.slice():Uint32Array.from({length:count},(_,i)=>i);
   cached={geometry:new Geometry('nwn-'+key,this.scene,data,true),source:g,uvName,versions:[],attributes:[],index:g.index,indexVersion:g.index?.version};this.geometries.set(key,cached);
   const colors=this.attribute(g.attributes.particleColor,4,count,[1,1,1,1]);cached.geometry.setVerticesData('particleColor',colors,true,4);
  }
  const mesh=new Mesh(object.name||'nwn-object',this.scene);cached.geometry.applyToMesh(mesh);mesh.releaseSubMeshes();new SubMesh(0,0,g.attributes.position.count,range.begin,range.count,mesh);
  mesh.alwaysSelectAsActiveMesh=true;mesh.metadata={order:this.rows.length};mesh.isPickable=false;
  const material=new ShaderMaterial('nwn-material-'+this.rows.length,this.scene,{vertexSource:vertexSource(this.lightLimit),fragmentSource:fragmentSource(this.lightLimit)},{shaderLanguage:ShaderLanguage.WGSL,attributes:['position','normal','uv','particleColor'],uniforms:['world','sourceNormal','uvRow0','uvRow1','params','tint','emissive','outputOptions'],uniformBuffers:['nwnFrame'],samplers:['baseMap'],needAlphaBlending:m.transparent,needAlphaTesting:m.alphaTest>0},true);
  if(this.frameBuffer)material.setUniformBuffer('nwnFrame',this.frameBuffer);
  material.backFaceCulling=m.side!==T.DoubleSide;material.cullBackFaces=m.side!==T.BackSide;material.disableDepthWrite=!m.depthWrite;material.depthFunction=m.depthTest?Constants.LEQUAL:Constants.ALWAYS;
  material.forceDepthWrite=!!m.depthWrite&&!!m.depthTest;
  material.zOffset=m.polygonOffset?m.polygonOffsetFactor:0;material.zOffsetUnits=m.polygonOffset?m.polygonOffsetUnits:0;
  material.alphaMode=particle&&m.blendDst===T.OneFactor?Constants.ALPHA_ADD:Constants.ALPHA_LAYER_ACCUMULATE;material.setTexture('baseMap',texture.texture);mesh.material=material;
  if(particle&&m.blending===T.CustomBlending){
   // The engine's stock ADD/COMBINE modes use different alpha-channel factors
   // than NWN's custom blend. Keep this pinned engine-cache adapter local to
   // the research material; do not bypass Babylon's draw/pipeline ownership.
   mesh.onBeforeDrawObservable.add(()=>{const dst=m.blendDst===T.OneFactor?1:771;this.engine._alphaState.setAlphaBlendFunctionParameters(770,dst,770,dst);this.engine._cacheRenderPipeline.setAlphaBlendFactors(this.engine._alphaState._blendFunctionParameters,this.engine._alphaState._blendEquationParameters);});
  }
  const row={item,mesh,material,texture,map,particle,cached,range,world:Matrix.Identity(),normal:Matrix.Identity(),tint:new Vector4(),emissive:new Vector4(),params:new Vector4(),uv0:new Vector4(),uv1:new Vector4(),output:new Vector4()};
  this.rows.push(row);this.syncRow(row);
 }
 attribute(attribute,size,count,fallback=new Array(size).fill(0)){
  if(attribute)requireValue(attribute.count===count&&attribute.itemSize===size,'attribute-shape');
  const values=new Float32Array(count*size),get=['getX','getY','getZ','getW'];
  for(let i=0;i<count;i++)for(let c=0;c<size;c++)values[i*size+c]=attribute?attribute[get[c]](i):fallback[c];return values;
 }
 syncRow(row){
  const {item,mesh,material,particle,map}=row,m=item.material;
  row.worldChanged=!sameMatrix(row.worldSource,item.object.matrixWorld.elements);
  if(row.worldChanged){if(!row.worldSource)row.worldSource=new Float64Array(16);row.worldSource.set(item.object.matrixWorld.elements);Matrix.FromArrayToRef(item.object.matrixWorld.elements,0,row.world);mesh.freezeWorldMatrix(row.world);mesh._worldMatrixDeterminantIsDirty=true;const negative=item.object.matrixWorld.determinant()<0;if(row.negative!==negative){this.invalidateDraw(row);row.negative=negative;}this.poseStats.worldUpdates++;}else this.poseStats.worldReused++;
  if(map?.matrixAutoUpdate&&!this.frameMaps.has(map)){map.updateMatrix();this.frameMaps.add(map);}const uv=particle?identityUv:map?.matrix?.elements??identityUv;
  row.uv0.set(uv[0],uv[3],uv[6],0);row.uv1.set(uv[1],uv[4],uv[7],0);
  row.tint.set(m.color?.r??1,m.color?.g??1,m.color?.b??1,particle?1:m.opacity??1);
  row.emissive.set((m.emissive?.r??0)*(m.emissiveIntensity??1),(m.emissive?.g??0)*(m.emissiveIntensity??1),(m.emissive?.b??0)*(m.emissiveIntensity??1),0);
  row.params.set(m.alphaTest??0,this.lit&&m.isMeshLambertMaterial?1:0,particle?1:0,m.side===T.DoubleSide?2:m.side===T.BackSide?-1:1);
  row.output.set(this.srgb?1:0,m.transparent?0:1,0,0);
  // Babylon's mesh draw owner already reverses winding for negative world
  // determinants. Applying that reversal here as well would cull the mesh.
  material.sideOrientation=Constants.MATERIAL_CounterClockWiseSideOrientation;
 }
 invalidateDraw(row){for(const subMesh of row.mesh.subMeshes){const context=subMesh._drawWrapper?.drawContext;if(context){context.fastBundle=undefined;context._currentInstanceCount=-1;}}}
 update(camera,lightState=this.lightState){
  requireValue(!this.disposed,'Adapter disposed');requireValue(lightState.point.length<=this.lightLimit,'Room light topology changed');
  this.lightState=lightState;this.frameMaps.clear();this.poseStats={worldUpdates:0,normalUpdates:0,worldReused:0,normalReused:0};const viewChanged=!sameMatrix(this.viewSource,camera.matrixWorldInverse.elements);if(viewChanged){if(!this.viewSource)this.viewSource=new Float64Array(16);this.viewSource.set(camera.matrixWorldInverse.elements);Matrix.FromArrayToRef(camera.matrixWorldInverse.elements,0,this.view);}Matrix.FromArrayToRef(camera.projectionMatrix.elements,0,this.projection);this.camera.freezeProjectionMatrix(this.projection);this.camera.getViewMatrix(true);
  this.ambient.set(...lightState.ambient,lightState.point.length);this.lightData.fill(0);
  for(let i=0;i<lightState.point.length;i++){const p=lightState.point[i],at=i*8;this.lightData[at]=p.position.x;this.lightData[at+1]=p.position.y;this.lightData[at+2]=p.position.z;this.lightData[at+3]=p.decay;this.lightData[at+4]=p.color.r;this.lightData[at+5]=p.color.g;this.lightData[at+6]=p.color.b;this.lightData[at+7]=p.distance;}
  if(this.frameBuffer){this.frameBuffer.updateMatrix('sourceView',this.view);this.frameBuffer.updateMatrix('sourceProjection',this.projection);this.frameBuffer.updateFloat4('ambient',this.ambient.x,this.ambient.y,this.ambient.z,this.ambient.w);this.frameBuffer.updateArray('lightData',this.lightData);this.frameBuffer.update();}
  for(const cached of this.geometries.values()){
   const attrs=[['position','position',3],['normal','normal',3],[cached.uvName,'uv',2],['particleColor','particleColor',4]],g=cached.source;
   requireValue(g.attributes.position.count===cached.geometry.getTotalVertices(),'Room geometry topology changed');
   requireValue(g.index===cached.index&&g.index?.version===cached.indexVersion,'Room index topology changed');
   for(let i=0;i<attrs.length;i++){const[from,to,size]=attrs[i],a=g.attributes[from];if(a&&(cached.attributes[i]!==a||cached.versions[i]!==a.version)){cached.geometry.updateVerticesData(to,this.attribute(a,size,a.count));cached.versions[i]=a.version;cached.attributes[i]=a;}}
  }
  for(const row of this.rows){this.syncRow(row);if(viewChanged||row.worldChanged||!row.normalReady){if(row.particle)this.modelView.copy(camera.matrixWorldInverse);else this.modelView.multiplyMatrices(camera.matrixWorldInverse,row.item.object.matrixWorld);this.normal.getNormalMatrix(this.modelView);const n=this.normal.elements;Matrix.FromValuesToRef(n[0],n[1],n[2],0,n[3],n[4],n[5],0,n[6],n[7],n[8],0,0,0,0,1,row.normal);row.normalReady=true;this.poseStats.normalUpdates++;}else this.poseStats.normalReused++;const range=roomDrawRange(row.item.geometry,row.item.group);if(row.range.begin!==range.begin||row.range.count!==range.count){this.invalidateDraw(row);row.range=range;}row.mesh.subMeshes[0].indexStart=range.begin;row.mesh.subMeshes[0].indexCount=range.count;this.bind(row);}
  this.revision++;
 }
 bind(row){const m=row.material;m.setMatrix('sourceNormal',row.normal);m.setVector4('uvRow0',row.uv0);m.setVector4('uvRow1',row.uv1);m.setVector4('params',row.params);m.setVector4('tint',row.tint);m.setVector4('emissive',row.emissive);m.setVector4('outputOptions',row.output);}
 async ready(){requireValue(!this.disposed,'Adapter disposed');for(const row of this.rows)this.bind(row);await Promise.all(this.rows.map(row=>row.material.forceCompilationAsync(row.mesh)));}
 render(){requireValue(!this.disposed,'Adapter disposed');if(!this.profileStages){this.engine.beginFrame();this.scene.render(false,true);this.engine.endFrame();return;}const begin=performance.now();this.engine.beginFrame();const sceneStart=performance.now();this.scene.render(false,true);const submit=performance.now();this.engine.endFrame();const end=performance.now();this.lastStages={beginFrameMs:sceneStart-begin,sceneRenderMs:submit-sceneStart,endFrameMs:end-submit};}
 snapshot(){return{engine:'Babylon.js',version:'9.32.0',backend:this.engine.isWebGPU?'WebGPU':'CPU test engine',draws:this.rows.length,geometries:this.geometries.size,textures:this.textures.size,particles:this.rows.filter(r=>r.particle).length,lambert:this.rows.filter(r=>r.params.y===1).length,pointSlots:this.lightLimit,activePoints:this.lightState.point.filter(p=>p.color.r||p.color.g||p.color.b).length,poseStats:{...this.poseStats},sharedFrameBytes:144+this.lightLimit*32,perDrawNumericBytes:224,excluded:{...this.excluded},errors:this.errors.slice(),revision:this.revision,fullGameParity:false,scope:'NWN opaque/transparent basic, Lambert and CPU particle geometry; base texture mip, native point/ambient attenuation. Shadows, fog, special materials and gameplay not ported.'};}
 dispose(){if(this.disposed)return;this.disposed=true;this.engine._device?.removeEventListener('uncapturederror',this.onGPUError);this.scene?.dispose();this.frameBuffer?.dispose();if(this.ownsEngine)this.engine.dispose();this.rows.length=0;this.geometries.clear();this.textures.clear();}
}
