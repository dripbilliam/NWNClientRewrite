import {decodeImaWav} from './ima_adpcm.js';
import {nativeAudioResRef} from './native_audio.js';
// Installed BMU V1.0 wraps an encoded audio stream with an eight-byte tag.
// This adapter keeps encoded music in a Blob and lets the browser stream its
// decoder; it never allocates a full-track AudioBuffer on the gameplay thread.
export function streamingAudioPayload(input,type){
 const bytes=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength);
 if(type===8){if(bytes.length<=8||String.fromCharCode(...bytes.subarray(0,8))!=='BMU V1.0')throw new Error('Invalid native BMU header');return{bytes:bytes.slice(8),mime:'audio/mpeg'};}
 if(type!==4)throw new Error('Unsupported native streaming audio type');
 const ima=decodeImaWav(bytes);if(!ima)return{bytes:bytes.slice(),mime:'audio/wav'};
 const size=ima.frames*ima.channels*2,out=new Uint8Array(44+size),view=new DataView(out.buffer),tag=(at,text)=>{for(let i=0;i<text.length;i++)out[at+i]=text.charCodeAt(i);};
 tag(0,'RIFF');view.setUint32(4,36+size,true);tag(8,'WAVEfmt ');view.setUint32(16,16,true);view.setUint16(20,1,true);view.setUint16(22,ima.channels,true);view.setUint32(24,ima.sampleRate,true);view.setUint32(28,ima.sampleRate*ima.channels*2,true);view.setUint16(32,ima.channels*2,true);view.setUint16(34,16,true);tag(36,'data');view.setUint32(40,size,true);
 for(let i=0;i<ima.frames;i++)for(let c=0;c<ima.channels;c++)view.setInt16(44+(i*ima.channels+c)*2,Math.max(-32768,Math.min(32767,Math.round(ima.samples[c][i]*32768))),true);
 return{bytes:out,mime:'audio/wav'};
}
export class StreamingAudio{
 constructor(output,{getResource,loop=false,onFailure=()=>{},createMedia=()=>new Audio(),createUrl=blob=>URL.createObjectURL(blob),revokeUrl=url=>URL.revokeObjectURL(url)}){
  Object.assign(this,{output,getResource,loop,onFailure,createMedia,createUrl,revokeUrl});this.volume=127;this.generation=0;this.disposed=false;this.status='idle';this.currentFile='';this.loaded=0;this.started=0;output.streams.add(this);
 }
 file(){return this.currentFile;}
 isPlaying(){return ['loading','queued','playing','fading'].includes(this.status);}
 play(resRef,type){
  if(this.disposed||!resRef)return 0;resRef=nativeAudioResRef(resRef);if(!resRef)return 0;this.stop();const generation=this.generation;this.currentFile=resRef.toLowerCase();this.status='loading';
  void this.load(resRef,type,generation);return 1;
 }
 async load(resRef,type,generation){
  try{
   const resource=await this.getResource(resRef,type);if(this.disposed||generation!==this.generation)return;
   const payload=streamingAudioPayload(resource.bytes,resource.type),context=this.output.ensureContext();
   this.media=this.createMedia();this.media.loop=this.loop;this.media.preload='auto';this.media.src=this.url=this.createUrl(new Blob([payload.bytes],{type:payload.mime}));
   this.gain=context.createGain();this.gain.gain.value=Math.fround(this.volume/127);this.node=context.createMediaElementSource(this.media);this.node.connect(this.gain);this.gain.connect(context.destination);this.loaded++;this.status='queued';
   this.media.addEventListener('ended',()=>{if(generation===this.generation)this.status='idle';});
   this.media.addEventListener('error',()=>{if(generation===this.generation)this.fail(new Error('Native audio stream decode failed'),generation);});
   this.flush();
  }catch(error){this.fail(error,generation);}
 }
 fail(error,generation){if(this.disposed||generation!==this.generation)return;this.stop();this.status='failed';this.onFailure(error,{resRef:this.currentFile});}
 flush(unlock=false){
  if(unlock)this.autoplayBlocked=false;
  if(this.disposed||this.status!=='queued'||this.output.context?.state!=='running'||this.playPending||this.autoplayBlocked)return;
  const generation=this.generation;this.playPending=true;
  void this.media.play().then(()=>{if(!this.disposed&&generation===this.generation){this.playPending=false;this.status=this.fade?'fading':'playing';this.started++;}},error=>{if(this.disposed||generation!==this.generation)return;this.playPending=false;if(error.name==='NotAllowedError')this.autoplayBlocked=true;else this.fail(error,generation);});
 }
 setVolume(value){this.volume=value&255;if(this.gain&&!this.fade)this.gain.gain.value=Math.fround(this.volume/127);}
 fadeAndStop(duration){
  if(!this.isPlaying())return;if(!duration||!this.media){this.stop();return;}if(this.fade)return;
  const context=this.output.context,start=context.currentTime;this.fade={end:start+duration/1000};this.status='fading';this.gain.gain.cancelScheduledValues(start);this.gain.gain.setValueAtTime(Math.fround(this.volume/127),start);this.gain.gain.linearRampToValueAtTime(0,this.fade.end);
 }
 update(){if(this.fade&&this.output.context.currentTime>=this.fade.end)this.stop();this.flush();}
 stop(){this.generation++;this.playPending=false;this.autoplayBlocked=false;this.fade=null;if(this.media){this.media.pause();this.media.removeAttribute('src');this.media.load();}this.node?.disconnect();this.gain?.disconnect();if(this.url)this.revokeUrl(this.url);this.media=this.node=this.gain=null;this.url=null;this.status='idle';}
 snapshot(){return{file:this.currentFile,status:this.status,loop:this.loop,volume:this.volume,loaded:this.loaded,started:this.started};}
 dispose(){if(this.disposed)return;this.stop();this.disposed=true;this.output.streams.delete(this);}
}
