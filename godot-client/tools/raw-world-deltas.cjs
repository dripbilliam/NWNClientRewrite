// Private bridge transport state only. Server fields remain opaque/unchanged.
const stringify=value=>JSON.stringify(value,(_key,v)=>typeof v==='bigint'?{native64:String(v)}:v);
class RawWorldDeltas{
 constructor(){this.reset();}
 reset(){this.base=null;this.pending=null;}
 plan({connection,generation,serial,data}){
  if(this.pending)throw Error('Raw world update is awaiting acknowledgement');
  if(!Number.isSafeInteger(connection)||connection<0||!Number.isSafeInteger(generation)||generation<0||!Number.isSafeInteger(serial)||serial<1||!Array.isArray(data?.objects)||data.objects.length>65536)throw Error('Invalid raw delta scope');
  const {objects,...header}=data,records=new Map(),upserts=[];
  const full=!this.base||this.base.connection!==connection||this.base.generation!==generation;
  for(const object of objects){
   const id=object?.id;if(!Number.isSafeInteger(id)||id<0||records.has(id))throw Error('Invalid or duplicate raw object identity');
   const encoded=stringify(object);records.set(id,encoded);
   if(full||this.base.records.get(id)!==encoded)upserts.push(object);
  }
  const removed=full?[]:[...this.base.records.keys()].filter(id=>!records.has(id)),encodedHeader=stringify(header);
  if(!full&&!upserts.length&&!removed.length&&encodedHeader===this.base.header)return null;
  this.pending={connection,generation,serial,records,header:encodedHeader};
  return {...header,objects:upserts,bridgeMode:full?'full':'delta',bridgeBaseSerial:full?-1:this.base.serial,removedObjectIds:removed};
 }
 acknowledge({connection,generation,serial}){
  if(!this.pending||this.pending.connection!==connection||this.pending.generation!==generation||this.pending.serial!==serial)return false;
  this.base=this.pending;this.pending=null;return true;
 }
}
module.exports={RawWorldDeltas};
