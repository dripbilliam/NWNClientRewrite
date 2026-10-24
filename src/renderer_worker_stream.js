// Private experiment. Mirror an owned GL context to a worker without serializing
// commands or resource bytes to disk. The source renderer remains authoritative.
// Unsupported producers fail this experiment; they never change source drawing.
const creates=['Buffer','Framebuffer','Program','Renderbuffer','Sampler','Shader','Texture','VertexArray'];
const writers=['activeTexture','attachShader','bindAttribLocation','bindBuffer','bindBufferBase','bindBufferRange','bindFramebuffer','bindRenderbuffer','bindSampler','bindTexture','bindVertexArray','blendColor','blendEquation','blendEquationSeparate','blendFunc','blendFuncSeparate','blitFramebuffer','bufferData','bufferSubData','clear','clearBufferfv','clearBufferiv','clearBufferuiv','clearBufferfi','clearColor','clearDepth','clearStencil','colorMask','compileShader','compressedTexImage2D','compressedTexImage3D','compressedTexSubImage2D','compressedTexSubImage3D','copyBufferSubData','copyTexImage2D','copyTexSubImage2D','copyTexSubImage3D','cullFace','depthFunc','depthMask','depthRange','detachShader','disable','disableVertexAttribArray','drawArrays','drawElements','drawArraysInstanced','drawElementsInstanced','drawBuffers','enable','enableVertexAttribArray','framebufferRenderbuffer','framebufferTexture2D','framebufferTextureLayer','finish','flush','frontFace','generateMipmap','hint','lineWidth','linkProgram','pixelStorei','polygonOffset','readBuffer','renderbufferStorage','renderbufferStorageMultisample','sampleCoverage','scissor','shaderSource','stencilFunc','stencilFuncSeparate','stencilMask','stencilMaskSeparate','stencilOp','stencilOpSeparate','texImage2D','texImage3D','texParameterf','texParameteri','texStorage2D','texStorage3D','texSubImage2D','texSubImage3D','uniformBlockBinding','invalidateFramebuffer','invalidateSubFramebuffer','useProgram','validateProgram','vertexAttrib1f','vertexAttrib2f','vertexAttrib3f','vertexAttrib4f','vertexAttrib1fv','vertexAttrib2fv','vertexAttrib3fv','vertexAttrib4fv','vertexAttribI4i','vertexAttribI4ui','vertexAttribI4iv','vertexAttribI4uiv','vertexAttribPointer','vertexAttribIPointer','vertexAttribDivisor','viewport'];
for(const n of [1,2,3,4])for(const t of ['f','i','ui'])writers.push('uniform'+n+t,'uniform'+n+t+'v');
for(const n of ['2','3','4','2x3','2x4','3x2','3x4','4x2','4x3'])writers.push('uniformMatrix'+n+'fv');
const extensionWriters=['multiDrawArraysWEBGL','multiDrawElementsWEBGL','multiDrawArraysInstancedWEBGL','multiDrawElementsInstancedWEBGL'];
const unsupported=['makeXRCompatible','beginQuery','endQuery','fenceSync','waitSync','clientWaitSync','beginTransformFeedback','endTransformFeedback','pauseTransformFeedback','resumeTransformFeedback','bindTransformFeedback','createTransformFeedback'];

export const WORKER_STREAM_OPERATIONS=Object.freeze([...writers,...creates.flatMap(k=>['create'+k,'delete'+k]),...unsupported,'getExtension','getUniformLocation']);

export class RendererWorkerStream {
 constructor(gl,{maxBytes=256*1024*1024,maxCommands=250000}={}){
  this.gl=gl;this.maxBytes=maxBytes;this.maxCommands=maxCommands;this.resources=new WeakMap();this.nextResource=1;this.restores=[];this.commands=[];this.transfers=[];this.bytes=0;this.failure=null;this.extensions=new Map();this.skipSourceDraws=false;this.closed=false;
  for(const kind of creates)this.wrap(gl,'create'+kind,{result:true});
  this.wrap(gl,'getUniformLocation',{result:true});
  for(const name of writers)this.wrap(gl,name);
  for(const kind of creates)this.wrap(gl,'delete'+kind);
  for(const name of unsupported)this.wrap(gl,name,{unsupported:true});
  const before=gl.getExtension,descriptor=Object.getOwnPropertyDescriptor(gl,'getExtension'),owner=this;
  if(before){const hook=function(name){const result=before.call(this,name);if(result&&!owner.extensions.has(name)){owner.extensions.set(name,result);owner.push({name:'getExtension',args:[name]});for(const method of extensionWriters)owner.wrap(result,method,{extension:name});}return result;};gl.getExtension=hook;this.restores.push(()=>{if(gl.getExtension===hook){if(descriptor)Object.defineProperty(gl,'getExtension',descriptor);else delete gl.getExtension;}});}
 }
 resource(value){let id=this.resources.get(value);if(!id){id=this.nextResource++;this.resources.set(value,id);}return id;}
 encode(value){
  if(typeof value==='string'){this.bytes+=value.length*2;if(this.bytes>this.maxBytes)throw Error('Worker stream byte capacity');return value;}if(value===null||typeof value!=='object')return value;
  const id=this.resources.get(value);if(id)return{resource:id};
  if(ArrayBuffer.isView(value)){const bytes=value.buffer.slice(value.byteOffset,value.byteOffset+value.byteLength),copy=value instanceof DataView?new DataView(bytes):new value.constructor(bytes);this.bytes+=bytes.byteLength;if(this.bytes>this.maxBytes)throw Error('Worker stream byte capacity');this.transfers.push(bytes);return copy;}
  if(value instanceof ArrayBuffer){const copy=value.slice(0);this.bytes+=copy.byteLength;if(this.bytes>this.maxBytes)throw Error('Worker stream byte capacity');this.transfers.push(copy);return copy;}
  if(Array.isArray(value))return value.map(v=>this.encode(v));
  throw Error('Unsupported worker GL argument '+(value.constructor?.name??'object'));
 }
 push(command){if(this.failure||this.closed)return;if(this.commands.length>=this.maxCommands){this.failure='Worker stream command capacity';return;}this.commands.push(command);}
 wrap(receiver,name,options={}){
  const before=receiver[name],descriptor=Object.getOwnPropertyDescriptor(receiver,name);if(typeof before!=='function')return;const owner=this;
  const hook=function(...args){const result=owner.skipSourceDraws&&!owner.failure&&!owner.closed&&/^(?:draw(?:Arrays|Elements)|multiDraw)/.test(name)?undefined:before.apply(this,args);if(owner.closed||owner.failure)return result;
   try{if(options.unsupported)throw Error('Unsupported worker GL operation '+name);const encoded=args.map(v=>owner.encode(v)),id=options.result&&result!==null?owner.resource(result):null;owner.push({name,args:encoded,...(options.result?{result:id}:{}),...(options.extension?{extension:options.extension}:{})});}catch(error){owner.failure=error.message;}return result;
  };receiver[name]=hook;this.restores.push(()=>{if(receiver[name]===hook){if(descriptor)Object.defineProperty(receiver,name,descriptor);else delete receiver[name];}});
 }
 take(){if(this.closed)throw Error('Worker stream is closed');if(this.failure)throw Error(this.failure);const batch={commands:this.commands,transfers:this.transfers,bytes:this.bytes};this.commands=[];this.transfers=[];this.bytes=0;return batch;}
 dispose(){if(this.closed)return;this.closed=true;for(const restore of this.restores.reverse())restore();this.restores=[];this.commands=[];this.transfers=[];this.resources=new WeakMap();this.extensions.clear();}
}

export class RendererWorkerExecutor {
 constructor(gl,{maxResources=131072}={}){if(!Number.isInteger(maxResources)||maxResources<1)throw Error('Invalid worker resource capacity');this.maxResources=maxResources;this.gl=gl;this.resources=new Map();this.extensions=new Map();this.closed=false;}
 decode(value){if(value&&typeof value==='object'&&!Array.isArray(value)&&!ArrayBuffer.isView(value)&&!(value instanceof ArrayBuffer)&&Object.hasOwn(value,'resource')){if(!this.resources.has(value.resource))throw Error('Missing mirrored GL resource');return this.resources.get(value.resource);}return Array.isArray(value)?value.map(v=>this.decode(v)):value;}
 execute(commands){if(this.closed)throw Error('Worker executor is closed');let draws=0;for(const command of commands){const receiver=command.extension?this.extensions.get(command.extension):this.gl;if(!receiver||typeof receiver[command.name]!=='function')throw Error('Missing worker GL operation '+command.name);const args=command.args.map(v=>this.decode(v)),result=receiver[command.name](...args);if(command.name==='getExtension'){if(!result)throw Error('Worker extension unavailable');this.extensions.set(args[0],result);}if(command.result!==undefined&&command.result!==null){if(result===null)throw Error('Worker GPU allocation/location unavailable');if(!this.resources.has(command.result)&&this.resources.size>=this.maxResources)throw Error('Worker resource capacity');this.resources.set(command.result,result);}if(/^(?:draw(?:Arrays|Elements)|multiDraw)/.test(command.name))draws++;}return{commands:commands.length,draws,resources:this.resources.size};}
 dispose(){this.closed=true;this.resources.clear();this.extensions.clear();}
}
