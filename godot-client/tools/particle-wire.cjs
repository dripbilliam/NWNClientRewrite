const MAGIC=Buffer.from([0x89,0x50,0x41,0x52]),MAX_BINARY=8*1024*1024,MAX_METADATA=65536;
function particlePackets(scope,result){
 for(const key of ['connection','areaId','generation','transferId'])if(!Number.isSafeInteger(scope[key])||scope[key]<0)throw Error('Invalid particle stream scope');
 const ids=new Set();
 const packets=[];let rows=[],streams=[],bytes=0;
 const flush=()=>{if(!rows.length)return;const metadata=Buffer.from(JSON.stringify({...scope,kind:'particle-stream',epoch:result.epoch,sequence:result.sequence,emitters:rows}));if(metadata.length>MAX_METADATA)throw Error('Particle stream metadata exceeds limit');
  const header=Buffer.alloc(12);MAGIC.copy(header);header.writeUInt32LE(4+metadata.length+bytes,4);header.writeUInt32LE(metadata.length,8);packets.push(Buffer.concat([header,metadata,...streams]));rows=[];streams=[];bytes=0;};
 if(!Number.isSafeInteger(result.epoch)||result.epoch<0||!Number.isSafeInteger(result.sequence)||result.sequence<0||!Array.isArray(result.emitters)||result.emitters.length>4096)throw Error('Invalid particle result');
 for(const row of result.emitters){
  if(ids.has(row.id))throw Error('Duplicate particle stream ID');ids.add(row.id);
  if(!Number.isSafeInteger(row.id)||row.id<0||!Number.isInteger(row.capacity)||row.capacity<0||row.capacity>196608||!Number.isInteger(row.count)||row.count<0||row.count>row.capacity||row.count%6||row.capacity%6||!(row.positions instanceof ArrayBuffer)||!(row.attributes instanceof ArrayBuffer)||row.positions.byteLength!==row.capacity*12||row.attributes.byteLength!==row.capacity*12)throw Error('Invalid packed particle stream');
  const size=row.positions.byteLength+row.attributes.byteLength;if(size+MAX_METADATA+4>MAX_BINARY)throw Error('Particle stream exceeds packet limit');
  if(rows.length>=128||bytes+size+MAX_METADATA+4>MAX_BINARY)flush();
  rows.push({id:row.id,count:row.count,capacity:row.capacity,bounds:row.bounds,positionBytes:row.positions.byteLength,attributeBytes:row.attributes.byteLength});
  streams.push(Buffer.from(row.positions),Buffer.from(row.attributes));bytes+=size;
 }
 flush();if(packets.reduce((sum,p)=>sum+p.length,0)>64*1024*1024)throw Error('Particle frame exceeds native transport budget');return packets;
}
module.exports={MAGIC,MAX_BINARY,MAX_METADATA,particlePackets};
