// Terminal records are independent of the ordinary first128 diagnostic cap.
// Keep bounded detached projections, never packets, credentials or Error stacks.
const CODES=new Set(['network.object-import-failed','network.game-session-failed','network.peer-failed','network.message-decompression-failed','network.server-disconnected','network.connect-failed','network.session-connect-failed']);
const CONNECT=new Set(['network.connect-failed','network.session-connect-failed']);
const text=value=>typeof value==='string'?value.replace(/\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b/gi,'[protected key]').replace(/[\x00-\x1f\x7f]/g,' ').slice(0,384):'';
function failure(value){if(!value||typeof value!=='object')return undefined;const out={};for(const key of ['stage','name','code','reason'])if(typeof value[key]==='string')out[key]=text(value[key]);return out;}
function createSessionFailureJournal({report,append,now=Date.now,limit=64}){
 if(!report||typeof append!=='function'||!Number.isInteger(limit)||limit<1||limit>256)throw Error('Invalid native terminal journal owner');
 const recent=new Map();let writes=Promise.resolve();
 return{
  record(d,connection){
   if(!CODES.has(d?.code))return false;
   const row={at:now(),connection,code:d.code,reason:text(d.reason)};
   if(d.failure)row.failure=failure(d.failure);
   if(d.clientFailure){const source=d.clientFailure;row.clientFailure={code:text(source.code),reason:text(source.reason),cause:{code:text(source.cause?.code),reason:text(source.cause?.reason)}};}
   if(d.code==='network.server-disconnected'){if(Number.isSafeInteger(d.strRef))row.strRef=d.strRef;if(typeof d.text==='string')row.text=text(d.text);}
   const key=JSON.stringify([connection,row.code,row.reason,row.failure??null,row.clientFailure??null,row.strRef??null,row.text??null]);
   if(recent.has(key))return false;recent.set(key,true);if(recent.size>limit)recent.delete(recent.keys().next().value);
   report.sessionFailures??=[];if(report.sessionFailures.length>=limit)report.sessionFailures.shift();report.sessionFailures.push(row);
   if(CONNECT.has(d.code)){report.connectionFailures??=[];if(report.connectionFailures.length<32)report.connectionFailures.push(row);}
   writes=writes.then(()=>append(JSON.stringify(row)+'\n')).catch(()=>{report.sessionFailureJournalErrors=Math.min(65535,(report.sessionFailureJournalErrors??0)+1);});
   return true;
  },
  settled(){return writes;}
 };
}
module.exports={createSessionFailureJournal};
