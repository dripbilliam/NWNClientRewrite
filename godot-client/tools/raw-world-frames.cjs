const stringify=value=>JSON.stringify(value,(_key,v)=>typeof v==='bigint'?{native64:String(v)}:v);
const rawWorldObjectJson=Symbol('raw world object JSON');
// Transport framing only: raw server objects remain opaque. Keep every frame
// below Godot's wire bound without producing geometry, images or animation.
function* rawWorldFrames({serial,generation,data,connection},maximum=1024*1024){
 if(!Number.isSafeInteger(serial)||serial<1||!Number.isSafeInteger(generation)||generation<0||!Array.isArray(data?.objects)||data.objects.length>65536)throw Error('Invalid raw world envelope');
 const {objects,...header}=data;
 if(connection!==undefined&&(!Number.isSafeInteger(connection)||connection<0))throw Error('Invalid raw world connection');
 const encode=frame=>{const text=stringify(connection===undefined?frame:{...frame,connection});if(Buffer.byteLength(text)>maximum)throw Error('Raw protocol record exceeds frame bound');return text+'\n';};
 yield encode({kind:'raw-world-begin',serial,generation,count:objects.length,data:header});
 const cached=data[rawWorldObjectJson];
 let chunk=batch=>encode({kind:'raw-world-chunk',serial,generation,objects:batch});
 // The session host builds plain records and frames its plan synchronously,
 // so framing can reuse the exact strings from change detection.
 if(cached){
  const prefix=stringify({kind:'raw-world-chunk',serial,generation}).slice(0,-1)+',"objects":[';
  const suffix=connection===undefined?']}':'],"connection":'+connection+'}';
  const envelopeBytes=Buffer.byteLength(prefix)+Buffer.byteLength(suffix);
  chunk=(batch,size)=>{
   if(envelopeBytes+size-1>maximum)throw Error('Raw protocol record exceeds frame bound');
   return prefix+batch.join(',')+suffix+'\n';
  };
 }
 let batch=[],size=0,total=0,index=0;
 for(const object of objects){
  const objectJson=cached?cached[index++]:stringify(object);
  const bytes=Buffer.byteLength(objectJson);
  total+=bytes;
  if(total>64*1024*1024)throw Error('Raw world snapshot exceeds bound');
  if(batch.length&&(batch.length>=64||size+bytes+1024>maximum)){yield chunk(batch,size);batch=[];size=0;}
  batch.push(cached?objectJson:object);
  size+=bytes+1;
 }
 if(batch.length)yield chunk(batch,size);
 yield encode({kind:'raw-world-end',serial,generation});
}
module.exports={rawWorldFrames,rawWorldObjectJson,stringify};
