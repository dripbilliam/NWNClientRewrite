import * as T from 'three';
import {FrameWorkBudget} from '../src/frame_work_budget.js';
import {RendererTexturePreparation} from '../src/renderer_texture_preparation.js';
const check=(value,message)=>{if(!value)throw Error(message);};
const hash=async bytes=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(value=>value.toString(16).padStart(2,'0')).join('');
function pixels(width,height,seed){return Uint8Array.from({length:width*height*4},(_,i)=>i%4===3?(i%12===3?255:170):(i*31+seed*53)%256);}
window.runFrameWorkBudgetFixture=async()=>{
 const results=[];let screenshot;
 for(const enabled of [false,true]){
  const renderer=new T.WebGLRenderer({antialias:false,preserveDrawingBuffer:true});renderer.setSize(768,512,false);renderer.setPixelRatio(1);const scene=new T.Scene(),camera=new T.PerspectiveCamera(44,1.5,.1,100);camera.position.set(10,12,17);camera.lookAt(0,0,0);
  // Real GPU operations, task-injected frame boundaries. Real rAF integration
  // is a separate native-client check, not inferred from this offscreen test.
  const work=new FrameWorkBudget({budgetMs:.5,schedule:callback=>setTimeout(callback,0),cancel:clearTimeout}),preparation=new RendererTexturePreparation(renderer,work),textures=[],materials=[],geometry=new T.BoxGeometry(.9,1.5,.9),rows=[];
  for(let i=0;i<6;i++){const texture=new T.DataTexture(pixels(i===0?209:128,i===0?273:128,i),i===0?209:128,i===0?273:128);texture.colorSpace=T.SRGBColorSpace;texture.wrapS=texture.wrapT=T.RepeatWrapping;texture.magFilter=T.LinearFilter;texture.minFilter=T.LinearMipmapLinearFilter;texture.generateMipmaps=true;texture.flipY=i%2===0;texture.repeat.set(1+i*.13,1+i*.07);texture.needsUpdate=true;textures.push(texture);}
  const manual=new T.DataTexture(pixels(8,8,10),8,8);manual.mipmaps=[8,4,2,1].map((size,i)=>({data:pixels(size,size,10+i),width:size,height:size}));manual.generateMipmaps=false;manual.minFilter=T.LinearMipmapLinearFilter;manual.colorSpace=T.SRGBColorSpace;manual.needsUpdate=true;textures.push(manual);
  let callbackCount=0;const callback=new T.DataTexture(pixels(4,4,12),4,4);callback.onUpdate=()=>callbackCount++;callback.needsUpdate=true;textures.push(callback);
  const compressed=renderer.extensions.has('WEBGL_compressed_texture_s3tc');if(compressed){const levels=[8,4,2,1].map(size=>({data:Uint8Array.from({length:Math.max(1,Math.ceil(size/4))**2*8},(_,i)=>i%8===0?31:i%8===1?248:0),width:size,height:size})),texture=new T.CompressedTexture(levels,8,8,T.RGB_S3TC_DXT1_Format);texture.minFilter=T.LinearMipmapLinearFilter;texture.needsUpdate=true;textures.push(texture);}
  const array=new T.DataArrayTexture(pixels(4,8,22),4,4,2);array.needsUpdate=true;textures.push(array);
  const source=textures.map(texture=>({image:texture.image,data:texture.image.data,version:texture.version,sourceVersion:texture.source.version,properties:JSON.stringify([texture.wrapS,texture.wrapT,texture.minFilter,texture.magFilter,texture.generateMipmaps,texture.flipY,texture.colorSpace,texture.repeat.toArray()])}));
  try{
   if(enabled){await preparation.prepare([...textures,textures[0]],{priority:0});await preparation.prepare(textures,{priority:0});check(callbackCount===0,'Preparation fired a first-draw callback');}
   for(const [i,texture]of textures.entries())check(texture.image===source[i].image&&texture.image.data===source[i].data&&texture.version===source[i].version&&texture.source.version===source[i].sourceVersion&&source[i].properties===JSON.stringify([texture.wrapS,texture.wrapT,texture.minFilter,texture.magFilter,texture.generateMipmaps,texture.flipY,texture.colorSpace,texture.repeat.toArray()]),'Preparation changed source texture state');
   const jobs=[];for(let i=0;i<96;i++){
    const build=()=>{const texture=textures[i%textures.length],material=texture===array?new T.ShaderMaterial({glslVersion:T.GLSL3,uniforms:{map:{value:array},layer:{value:i%2}},vertexShader:'out vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}',fragmentShader:'uniform highp sampler2DArray map;uniform int layer;in vec2 vUv;out vec4 color;void main(){color=texture(map,vec3(vUv,float(layer)));}'}):new T.MeshBasicMaterial({map:texture,alphaTest:.05});materials.push(material);const mesh=new T.Mesh(geometry,material);mesh.position.set(i%12*1.25-7,.75,Math.floor(i/12)*1.25-4.5);scene.add(mesh);};
    if(enabled)jobs.push(work.run(build,{priority:i===0?0:1,kind:'model'}));else build();
   }await Promise.all(jobs);
   for(let frame=0;frame<8;frame++){camera.position.set(12+frame*.3,12+frame*.2,17-frame*.3);camera.lookAt(0,0,0);renderer.render(scene,camera);const gl=renderer.getContext(),output=new Uint8Array(768*512*4);gl.readPixels(0,0,768,512,gl.RGBA,gl.UNSIGNED_BYTE,output);check(gl.getError()===0,'GPU texture upload/render error');rows.push({pixels:await hash(output),draw:{...renderer.info.render}});}
   check(callbackCount===1,'First-draw texture callback count differs');screenshot=renderer.domElement.toDataURL('image/png');work.dispose();check(work.snapshot().queued===0&&!work.snapshot().scheduled,'Work survived disposal');results.push({enabled,compressed,textureTypes:textures.map(texture=>texture.type),rows,callbackCount,texturePreparation:preparation.snapshot(),frameWork:work.snapshot()});
  }finally{work.dispose();scene.clear();geometry.dispose();for(const material of materials)material.dispose();for(const texture of textures)texture.dispose();check(renderer.info.memory.geometries===0&&renderer.info.memory.textures===0,'GPU area resources survived teardown');renderer.dispose();renderer.forceContextLoss();}
 }
 const comparisons=results[0].rows.map((row,i)=>({frame:i,pixels:row.pixels===results[1].rows[i].pixels,calls:row.draw.calls===results[1].rows[i].draw.calls,triangles:row.draw.triangles===results[1].rows[i].draw.triangles}));return{success:comparisons.every(row=>row.pixels&&row.calls&&row.triangles),comparisons,results,screenshot,scope:'Authored NPOT/sRGB/filter/wrap/flip/manual-mip/compressed-if-supported/array textures through actual Three initTexture and GPU drawing, 96 budgeted model tasks, injected task-based frame boundaries; not real-rAF/native multiplayer or performance acceptance'};
};
