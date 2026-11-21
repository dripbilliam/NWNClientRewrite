'use strict';
// Test-only, bounded decoder/acceptance witness. No protocol sends or live data.
function associateRecordProof(input,Reader){
 const wire=(input.wire??[]).map(source=>{
  const row={at:source.at,major:source.major,minor:source.minor,controlledId:source.controlledId,valid:false};
  try{
   if(!Array.isArray(source.bytes)||source.bytes.length>512||source.bytes.some(n=>!Number.isInteger(n)||n<0||n>255))return row;
   const bytes=Uint8Array.from(source.bytes);if(bytes[0]!==112||bytes[1]!==source.major||bytes[2]!==source.minor||source.minor!==1||![21,53].includes(source.major))return row;
   const r=new Reader(1);if(r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1)!==1)return row;
   if(row.major===21){row.page=r.readChar();row.targetId=r.readObjectIdClient();}
   else{row.event=r.readWord();row.selection=r.readWord();row.targetId=r.readObjectIdClient();row.position=[r.readFloat(),r.readFloat(),r.readFloat()];}
   row.valid=r.messageReadOverflow()===0&&r.messageReadUnderflow()===0;
  }catch{row.valid=false;}
  return row;
 });
 const target=input.target,validTarget=Number.isInteger(target)&&target>=0&&target<=0xffffffff&&target!==0x7f000000;
 const pages=wire.filter(row=>row.major===21&&row.targetId===target),details=wire.filter(row=>row.major===53&&[3,4].includes(row.event));
 const success=validTarget&&wire.length<=96&&wire.every(row=>row.valid)&&[0,1,2,-1].every(page=>pages.some(row=>row.page===page))&&details.length===6&&details.every(row=>row.valid&&row.targetId===target&&row.controlledId!==target&&row.position.every(n=>n===0))&&[[3,1,2],[3,3,1],[4,3,2],[4,4,1]].every(([event,selection,count])=>details.filter(row=>row.event===event&&row.selection===selection).length===count)&&input.actions===true&&input.lifecycle===true;
 return {success,wire,targetId:target,scope:'Physical owned world/portrait Record, installed native sheet tabs/rows/X; exact21/1 and53/1 GUI3/4 targets/WORD/zeroXYZ plus original-server selective chat/TLK/custom-token barriers. No invented page ACK, injected received stats, GPU or pixel claim.'};
}
module.exports={associateRecordProof};
