import {RendererWorkerStream} from './renderer_worker_stream.js';

// Private offline diagnostic. This first stage still prepares/draws the source
// context and mirrors its commands; it makes no main-thread/FPS saving claim.
export class RendererWorkerClient {
 constructor(canvas){
  this.canvas=canvas;this.waiting=new Map();this.nextId=0;this.submitted=0;this.completed=0;this.bytes=0;this.pendingFrames=0;this.paused=false;this.failure=null;this.last=null;
  const before=canvas.getContext,descriptor=Object.getOwnPropertyDescriptor(canvas,'getContext'),owner=this;
  this.restoreContextHook=()=>{if(canvas.getContext===this.contextHook){if(descriptor)Object.defineProperty(canvas,'getContext',descriptor);else delete canvas.getContext;}};
  this.contextLost=()=>this.fail(Error('Source context lost; worker requires fresh resource bootstrap'));canvas.addEventListener('webglcontextlost',this.contextLost);
  this.contextHook=function(type,attributes){const gl=before.call(this,type,attributes);if(type==='webgl2'&&gl&&!owner.stream){owner.stream=new RendererWorkerStream(gl);owner.restoreContextHook();owner.start(gl);}return gl;};canvas.getContext=this.contextHook;
 }
 start(gl){
  this.worker=new Worker(new URL('../scripts/performance-candidates/renderer-stream-worker.mjs',import.meta.url),{type:'module'});
  this.worker.onmessage=event=>{const reply=event.data,entry=this.waiting.get(reply.id);if(!entry)return;clearTimeout(entry.timer);this.waiting.delete(reply.id);reply.error?entry.reject(Error(reply.error)):entry.resolve(reply);};
  this.worker.onerror=event=>this.fail(Error(event.message));
  const canvas=new OffscreenCanvas(this.canvas.width,this.canvas.height);this.ready=this.request({type:'init',canvas,attributes:gl.getContextAttributes()},[canvas]).then(()=>{this.initialized=true;}).catch(error=>this.fail(error));
 }
 request(message,transfers=[]){return new Promise((resolve,reject)=>{const id=++this.nextId,timer=setTimeout(()=>{this.waiting.delete(id);reject(Error('Worker stream response deadline'));},30000);this.waiting.set(id,{resolve,reject,timer});try{this.worker.postMessage({...message,id},transfers);}catch(error){clearTimeout(timer);this.waiting.delete(id);reject(error);}});}
 fail(error){if(this.failure)return;this.failure=error.message;this.restoreContextHook();this.stream?.dispose();for(const entry of this.waiting.values()){clearTimeout(entry.timer);entry.reject(error);}this.waiting.clear();this.worker?.terminate();}
 async submit(batch,readback=false,shadows=[]){this.pendingFrames++;this.submitted++;this.bytes+=batch.bytes;try{const reply=await this.request({type:'frame',commands:batch.commands,width:this.canvas.width,height:this.canvas.height,readback,shadows},batch.transfers);this.completed++;this.last={commands:reply.commands,draws:reply.draws,resources:reply.resources,submitMs:reply.submitMs};return reply;}finally{this.pendingFrames--;}}
 frame(){if(!this.stream||!this.initialized||this.failure||this.paused||this.pendingFrames>=2)return;try{void this.submit(this.stream.take()).catch(error=>this.fail(error));}catch(error){this.fail(error);}}
 async audit(drawAndRead,restore){
  if(!this.stream)throw Error('Worker stream unavailable');this.paused=true;
  try{await this.ready;if(this.failure)throw Error(this.failure);while(this.pendingFrames)await new Promise(resolve=>setTimeout(resolve,1));const reference=drawAndRead(),batch=this.stream.take();restore();const reply=await this.submit(batch,true,reference.shadows.map(({id,width,height,framebuffer})=>({id,width,height,framebuffer}))),pixels=reply.pixels;if(pixels.length!==reference.pixels.length)throw Error('Worker readback dimensions changed');let channels=0,max=0;for(let i=0;i<reference.pixels.length;i++){const d=Math.abs(reference.pixels[i]-pixels[i]);if(d){channels++;max=Math.max(max,d);}}const shadows=reference.shadows.map((shadow,index)=>{const other=reply.shadows[index];if(!other||other.id!==shadow.id||other.data.length!==shadow.pixels.length)throw Error('Worker shadow identity/dimensions changed');let channels=0,max=0;for(let i=0;i<shadow.pixels.length;i++){const d=Math.abs(shadow.pixels[i]-other.data[i]);if(d){channels++;max=Math.max(max,d);}}return{id:shadow.id,channels,max};});return{scope:'Independent no-MSAA captured-room source/worker color and active shadow comparison; source still draws, no FPS claim',channels,max,shadows,exact:channels===0&&shadows.every(s=>s.channels===0),worker:this.snapshot()};}
  finally{restore();this.paused=false;}
 }
 snapshot(){return{enabled:true,initialized:!!this.initialized,submitted:this.submitted,completed:this.completed,pending:this.pendingFrames,bytes:this.bytes,failure:this.failure,last:this.last};}
 dispose(){this.restoreContextHook();this.canvas.removeEventListener('webglcontextlost',this.contextLost);this.stream?.dispose();for(const entry of this.waiting.values()){clearTimeout(entry.timer);entry.reject(Error('Worker client disposed'));}this.waiting.clear();this.worker?.terminate();}
}
