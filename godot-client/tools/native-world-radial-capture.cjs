// First owned local snapshot only. No credentials, game transport or rendering.
const fs=require('node:fs/promises');
const crypto=require('node:crypto');
const digest=value=>crypto.createHash('sha256').update(value).digest('hex');
const MAX_BYTES=8*1024*1024;
function validateCapture(value){
 if(value?.version!==1||typeof value.setupFrame!=='string'||!Array.isArray(value.rawFrames)||value.rawFrames.length<2||value.rawFrames.length>1026)throw Error('Invalid first native snapshot capture');
 if(Buffer.byteLength(value.setupFrame)>65536||value.rawFrames.some(row=>typeof row!=='string'||Buffer.byteLength(row)>1024*1024+4096))throw Error('Native snapshot frame exceeds bound');
 if(Buffer.byteLength(JSON.stringify(value))>MAX_BYTES)throw Error('First native snapshot exceeds bound');
 const setup=JSON.parse(value.setupFrame),frames=value.rawFrames.map(row=>JSON.parse(row));
 if(setup.kind!=='setup'||frames[0].kind!=='raw-world-begin'||frames.at(-1).kind!=='raw-world-end'||frames.slice(1,-1).some(row=>row.kind!=='raw-world-chunk'))throw Error('Invalid native snapshot frame order');
 const first=frames[0];if(!Number.isSafeInteger(setup.connection)||setup.connection<0||!Number.isSafeInteger(first.serial)||first.serial<1||!Number.isSafeInteger(first.generation)||first.generation<0||first.data?.bridgeMode!=='full'||!Number.isInteger(first.count)||first.count<0||first.count>65536)throw Error('Invalid first snapshot header');
 if(frames.some(row=>row.serial!==first.serial||row.generation!==first.generation||row.connection!==setup.connection)||frames.slice(1,-1).some(row=>!Array.isArray(row.objects)||row.objects.length>64)||frames.slice(1,-1).reduce((sum,row)=>sum+row.objects.length,0)!==first.count)throw Error('Incomplete native snapshot capture');
 if(value.setupSha256!==digest(value.setupFrame)||value.framesSha256!==digest(value.rawFrames.join('')))throw Error('Native snapshot capture checksum differs');
 return{setup,frames,serial:first.serial,generation:first.generation,connection:setup.connection,objects:first.count};
}
class NativeWorldRadialCapture{
 constructor(file,{writeFile=fs.writeFile}={}){this.file=file;this.writeFile=writeFile;this.setupFrame=null;this.work=null;this.result=null;}
 observeSetup(text){if(this.work)return;if(typeof text!=='string'||Buffer.byteLength(text)>65536||JSON.parse(text).kind!=='setup')throw Error('Invalid captured native setup');this.setupFrame=text;}
 captureFrames(frames){
  if(this.work)return this.work;
  const value={version:1,setupFrame:this.setupFrame,rawFrames:[...frames],setupSha256:digest(this.setupFrame??''),framesSha256:digest(frames.join(''))};
  const identity=validateCapture(value),text=JSON.stringify(value)+'\n';
  this.work=Promise.resolve().then(()=>this.writeFile(this.file,text,{flag:'wx'})).then(()=>{this.result={success:true,file:this.file,sha256:digest(text),bytes:Buffer.byteLength(text),serial:identity.serial,generation:identity.generation,connection:identity.connection,objects:identity.objects,scope:'Exact first owned local setup/raw native frames; not a complete area recording or gameplay outcome.'};this.setupFrame=null;return this.result;});
  return this.work;
 }
 async settle(){return this.work?this.work.catch(()=>({success:false,file:this.file,reason:'Owned snapshot capture could not be persisted'})):{success:false,file:this.file,reason:'No first native snapshot was observed'};}
}
async function readCapture(file){const bytes=await fs.readFile(file);if(bytes.length>MAX_BYTES)throw Error('First snapshot capture file exceeds bound');const value=JSON.parse(bytes);return{value,identity:validateCapture(value),sha256:digest(bytes)};}
module.exports={NativeWorldRadialCapture,readCapture,validateCapture,MAX_BYTES};
