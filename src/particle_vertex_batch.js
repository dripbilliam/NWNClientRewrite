import {buildParticleVertices,particleDrawCount,advanceParticleAtlas} from './particle_vertices.js';
const stride=18,headerStride=64,f=Math.fround;
const required=(p,name,...args)=>{if(typeof p[name]!=='function')throw Error(`Native particle draw provider ${name} is unavailable`);return p[name](...args);};
const instance=value=>value?{fade:value.fade,height50:value.height50,opacity70:value.opacity70}:null;
const fields=['renderMode1a8','lifeExp','flags','ageMode1cc','xGrid','yGrid','elevationThreshold','alphaStart','alphaEnd','sizeStart','sizeEnd','sizeStartY','sizeEndY','fps','frameStart','frameEnd','blendMode68','twoSided'];

// No callbacks, Three objects, actor IDs, source resources or cyclic particle
// owners leave the renderer. Clock mutation stays in native emitter order here.
export function sampleParticleVertices(e,p,{capture=true}={}){
 if(!particleDrawCount(e))return null;
 if(p.sineFloat||p.cosineFloat)throw Error('Custom particle math cannot run in a resource worker');
 const factor=e.source50?f(required(p,'sourceFactor',e.source50)):1,camera=required(p,'cameraQuaternion').map(f),tint=e.flags&8?required(p,'lightColor',e.position1e0.slice()).map(f):[1,1,1];
 advanceParticleAtlas(e);
 if(!capture)return true;
 const head=Object.fromEntries(fields.map(name=>[name,e[name]]));head.source50=e.source50?{opacity108:e.source50.opacity108,instance:instance(e.source50.instance)}:null;head.instance100=instance(e.instance100);
 for(const name of ['quaternion1d0','position1e0','colorStart','colorEnd'])head[name]=e[name].slice();
 return{head,factor,camera,tint,records:e.active188.records};
}

export function packParticleVertexBatch(items){
 const length=items.reduce((n,item)=>n+item.input.records.length,0),headerBytes=items.length*headerStride*8,buffer=new ArrayBuffer(headerBytes+length*stride*4),headers=new Float64Array(buffer,0,headerBytes/8),values=new Float32Array(buffer,headerBytes),integers=new Int32Array(buffer,headerBytes),frames=[];let offset=0;
 for(const [header,{key,input}]of items.entries()){
  const {records,head,factor,camera,tint}=input,at=header*headerStride;frames.push({key,offset,count:records.length,header});
  for(let i=0;i<fields.length;i++)headers[at+i]=head[fields[i]];
  headers[at+18]=factor;for(let i=0;i<4;i++)headers[at+19+i]=camera[i];for(let i=0;i<3;i++)headers[at+23+i]=tint[i];
  headers[at+26]=Number(Boolean(head.source50));headers[at+27]=head.source50?.opacity108;headers[at+28]=Number(Boolean(head.source50?.instance));headers[at+29]=head.source50?.instance?.fade;headers[at+30]=head.source50?.instance?.height50;headers[at+31]=head.source50?.instance?.opacity70;
  headers[at+32]=Number(Boolean(head.instance100));headers[at+33]=head.instance100?.fade;headers[at+34]=head.instance100?.height50;headers[at+35]=head.instance100?.opacity70;
  for(let i=0;i<4;i++)headers[at+36+i]=head.quaternion1d0[i];for(let i=0;i<3;i++){headers[at+40+i]=head.position1e0[i];headers[at+43+i]=head.colorStart[i];headers[at+46+i]=head.colorEnd[i];}
  const mode=head.renderMode1a8,ordinary=mode===0||mode===1||mode===2||mode===4,atlas=(head.xGrid|0)>1||(head.yGrid|0)>1;
  for(let i=0;i<records.length;i++){
   const p=records[i],at=(offset+i)*stride;
   values[at]=p.position10[0];values[at+1]=p.position10[1];values[at+2]=p.position10[2];
   if(mode===6)for(let c=0;c<3;c++)values[at+3+c]=p.trail64[c];
   if(mode===5||ordinary&&p.stopped70)for(let c=0;c<4;c++)values[at+6+c]=p.quaternion34[c];
   if(ordinary){values[at+13]=p.rotation1c;if(p.stopped70||head.flags&512)for(let c=0;c<3;c++)values[at+10+c]=p.direction4c[c];}
   values[at+14]=p.age;if(atlas)integers[at+16]=p.frame44|0;values[at+17]=p.stopped70;
  }
  offset+=records.length;
 }
 return{buffer,frames,headerBytes};
}

export function buildParticleVertexBatch({buffer,frames,headerBytes=0}){
 if(!(buffer instanceof ArrayBuffer)||!Number.isInteger(headerBytes)||headerBytes<0||headerBytes>buffer.byteLength||headerBytes%(headerStride*8)||(buffer.byteLength-headerBytes)%(stride*4))throw Error('Invalid particle snapshot buffer');
 const headers=new Float64Array(buffer,0,headerBytes/8),values=new Float32Array(buffer,headerBytes),integers=new Int32Array(buffer,headerBytes),limit=values.length/stride;
 return frames.map(({key,offset,count,header})=>{
  try{
   if(!Number.isInteger(offset)||!Number.isInteger(count)||offset<0||count<0||offset+count>limit||!Number.isInteger(header)||header<0||header>=headerBytes/(headerStride*8))throw Error('Particle snapshot is out of bounds');
   const at=header*headerStride,head=Object.fromEntries(fields.map((name,i)=>[name,headers[at+i]])),factor=headers[at+18],camera=Array.from(headers.subarray(at+19,at+23)),tint=Array.from(headers.subarray(at+23,at+26));
   head.source50=headers[at+26]?{opacity108:headers[at+27],instance:headers[at+28]?{fade:headers[at+29],height50:headers[at+30],opacity70:headers[at+31]}:null}:null;head.instance100=headers[at+32]?{fade:headers[at+33],height50:headers[at+34],opacity70:headers[at+35]}:null;
   head.quaternion1d0=Array.from(headers.subarray(at+36,at+40));head.position1e0=Array.from(headers.subarray(at+40,at+43));head.colorStart=Array.from(headers.subarray(at+43,at+46));head.colorEnd=Array.from(headers.subarray(at+46,at+49));
   const records=Array.from({length:count},(_,i)=>{const at=(offset+i)*stride;return{position10:[values[at],values[at+1],values[at+2]],trail64:[values[at+3],values[at+4],values[at+5]],quaternion34:[values[at+6],values[at+7],values[at+8],values[at+9]],direction4c:[values[at+10],values[at+11],values[at+12]],rotation1c:values[at+13],age:values[at+14],field48:values[at+15],frame44:integers[at+16],stopped70:values[at+17]};});
   const out=buildParticleVertices({...head,active188:{records}},{sourceFactor:()=>factor,cameraQuaternion:()=>camera,lightColor:()=>tint},{atlasPrepared:true});
   return{key,out};
  }catch(error){return{key,error:error.message};}
 });
}
