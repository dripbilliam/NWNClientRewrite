// QA-only application-delivery latency, after reliable transport/decompression.
// Login/UDP acknowledgement timing, packet bytes and ordering are not changed.
const {createHash}=require('node:crypto');
module.exports=(peer,{delayMs,durationMs,now=()=>performance.now(),setTimer=setTimeout,clearTimer=clearTimeout})=>{
 if(!Number.isInteger(delayMs)||delayMs<1||delayMs>500||!Number.isInteger(durationMs)||durationMs<1000||durationMs>60000)throw Error('Invalid bounded message delay');
 const original=peer.emit,start=now(),until=start+durationMs,queue=[],rows=[];let timer=null,closed=false,ordinal=0,maxPending=0,discarded=0,finishedAt=null;
 const restore=()=>{if(peer.emit===intercept)peer.emit=original;closed=true;finishedAt=now();};
 const schedule=()=>{if(timer!==null)clearTimer(timer);timer=setTimer(drain,Math.max(0,(queue[0]?.due??until)-now()));};
 // Delivery transfers byte ownership to the session's asynchronous importer.
 // Only discarded entries may be cleared here, never a delivered buffer.
 const drain=()=>{timer=null;while(queue.length&&queue[0].due<=now()){const entry=queue.shift();entry.row.deliveredAt=now();original.call(peer,'message',entry.bytes);}if(!queue.length&&now()>=until)restore();else schedule();};
 function intercept(event,...args){
  if(event!=='message')return original.call(this,event,...args);
  const at=now();if(at>=until&&!queue.length){restore();return original.call(this,event,...args);}
  if(queue.length>=2048)throw Error('Bounded message-delay queue overflow');
  const bytes=Buffer.from(args[0]),due=Math.max(queue.at(-1)?.due??-Infinity,at+(at<until?delayMs:0)),row={ordinal:++ordinal,receivedAt:at,due,bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};rows.push(row);queue.push({row,bytes,due});maxPending=Math.max(maxPending,queue.length);schedule();return peer.listenerCount('message')>0;
 }
 peer.emit=intercept;schedule();
 return{snapshot:()=>({scope:'QA-only delay after reliable transport/decompression, before session application import; not measured RTT, packet loss, UDP delay or a native-client comparison',delayMs,durationMs,start,finishedAt,active:!closed,pending:queue.length,maxPending,discarded,rows:rows.map(r=>({...r}))}),stop({flush=true}={}){if(closed)return;if(timer!==null)clearTimer(timer);timer=null;while(queue.length){const entry=queue.shift();if(flush){entry.row.deliveredAt=now();entry.row.flushed=true;original.call(peer,'message',entry.bytes);}else{discarded++;entry.bytes.fill(0);}}restore();}};
};
