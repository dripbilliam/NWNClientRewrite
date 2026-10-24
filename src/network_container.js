import {NativeMessageWriter} from './native_message.js';
// Client7bdeb0 sends25/1;7bde70/90 send empty25/2,3. Server451810
// owns closure, access and page limits. Opening is ordinary use6/11(false,false).
export function containerRequest({operation,targetId=0}){
 if(operation==='next'||operation==='previous')return Uint8Array.of(112,25,operation==='next'?2:3);
 if(operation!=='close'||!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff)throw new Error('Invalid native container request');
 const w=new NativeMessageWriter(1);w.create(4,0xffffffff,1);w.writeObjectIdClient(targetId);w.setPrefix(Uint8Array.of(112,25,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Original server4d9c30 -> client79ceb0. BOOL nonzero chooses the primary GUI;
// it is not success/open. OBJECT_INVALID closes that GUI's container.
export function readContainerStatus(r){return{kind:'container-status',targetId:r.readObjectIdClient(),primary:r.readBool()};}
// Original GUI855d00/855be0 read the low BYTE of the current page/count.
export function selectContainerPage(current,count,direction){
 if(!Number.isInteger(current)||!Number.isInteger(count)||![1,-1].includes(direction))throw new Error('Invalid native container page');
 current&=255;count&=255;return direction===1?(count-1<=current?0:current+1):(current===0?count-1:current-1);
}
