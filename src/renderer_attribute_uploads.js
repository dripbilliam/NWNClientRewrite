import {DynamicDrawUsage,StreamDrawUsage,StaticDrawUsage} from 'three';

// Private experiment: rename storage, retaining the original buffer/VAO owner.
// Partial updates qualify only for an explicitly owned, nonindexed draw prefix.
export class RendererAttributeUploads {
 constructor(renderer){this.renderer=renderer;this.enabled=false;this.includeStatic=false;this.prefixes=new WeakMap();this.stats={uploads:0,bytes:0,fallback:0};this.attach();}
 attach(){const api=this.renderer.nwnDrawAPI?.attributes;if(api===this.api)return;if(this.api&&this.api.update===this.hook)this.api.update=this.original;this.api=api;if(!api)return;this.gl=this.renderer.getContext();this.original=api.update;const owner=this,original=this.original;this.hook=function(attribute,target){return owner.update(this,original,attribute,target);};api.update=this.hook;}
 begin(){this.attach();this.stats={uploads:0,bytes:0,fallback:0};}
 prefix(geometry){if(geometry.index||geometry.drawRange.start!==0||!Number.isFinite(geometry.drawRange.count))return;for(const a of Object.values(geometry.attributes))if(this.prefixes.get(a)?.geometry!==geometry)this.prefixes.set(a,{geometry});}
 update(receiver,original,attribute,target){
  const a=attribute.isInterleavedBufferAttribute?attribute.data:attribute,record=this.api.get(a),array=a.array;
  if(!this.enabled||a.isGLBufferAttribute||!record||!(record.version<a.version))return original.call(receiver,attribute,target);
  const ranges=a.updateRanges,registration=this.prefixes.get(a),geometry=registration?.geometry;
  const full=!ranges?.length||ranges.length===1&&ranges[0].start===0&&ranges[0].count===array?.length;
  const prefix=geometry&&!geometry.index&&geometry.drawRange.start===0&&Number.isFinite(geometry.drawRange.count)&&geometry.drawRange.count>=0&&geometry.drawRange.count<=a.count&&ranges?.length===1&&ranges[0].start===0&&ranges[0].count>=geometry.drawRange.count*a.itemSize;
  if(!ArrayBuffer.isView(array)||array instanceof DataView||record.size!==array.byteLength||record.bytesPerElement!==array.BYTES_PER_ELEMENT||(!full&&!prefix)||!(a.usage===DynamicDrawUsage||a.usage===StreamDrawUsage||this.includeStatic&&a.usage===StaticDrawUsage)){this.stats.fallback++;return original.call(receiver,attribute,target);}
  const gl=this.gl;gl.bindBuffer(target,record.buffer);gl.bufferData(target,array,a.usage);if(ranges.length)a.clearUpdateRanges();a.onUploadCallback();record.version=a.version;this.stats.uploads++;this.stats.bytes+=array.byteLength;
 }
 snapshot(){return{enabled:this.enabled,includeStatic:this.includeStatic,...this.stats};}
 dispose(){if(this.api&&this.api.update===this.hook)this.api.update=this.original;this.api=null;this.prefixes=new WeakMap();}
}
