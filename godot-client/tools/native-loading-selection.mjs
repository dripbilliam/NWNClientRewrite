import {movementEventKinds} from './native-movement-recording.mjs';
// Select one captured area as a fresh process/cache load. Preserve resource,
// protocol and persistent server UI state, without replaying earlier worlds.
export function selectGeneration(records,generation){
 if(!Number.isSafeInteger(generation)||generation<1)throw Error('Invalid captured area generation');
 const start=records.findIndex(row=>row.kind==='frame'&&row.value.kind==='raw-world-begin'&&row.value.generation===generation&&row.value.data?.bridgeMode!=='delta');
 if(start<0)throw Error('Recording has no full entry for that area generation');
 const connection=records[start].value.connection;
 const before=records.slice(0,start);const setup=before.findLast(row=>row.kind==='frame'&&row.value.kind==='setup'&&row.value.connection===connection);
 if(!setup)throw Error('Area entry has no recorded resource setup');
 const seed=[{kind:'frame',at:0,value:{kind:'session-reset',connection}},{...setup,at:0},{kind:'acknowledgement',at:0,value:{kind:'catalog-ready',connection}}];
 for(const row of before)if(row.kind==='frame'&&row.value.connection===connection&&row.value.kind==='ui-protocol'&&(/^(?:nui-|custom-token$|tlk-overrides$)/.test(row.value.message?.kind??'')))seed.push({...row,at:0});
 const view=before.findLast(row=>row.kind==='view'&&row.value.connection===connection);if(view)seed.push({...view,at:0});
 const selected=[];const origin=records[start].at;
 for(const row of records.slice(start)){
  if(row.kind==='frame'&&((row.value.kind==='raw-world-begin'&&row.value.generation!==generation)||(row.value.kind==='session-reset'&&row.value.connection!==connection)))break;
  if(row.kind==='frame'&&(row.value.connection!==connection||row.value.generation!==generation))continue;
  if(row.kind==='acknowledgement'&&(row.value.connection!==connection||row.value.generation!==generation))continue;
  if(row.kind==='baseline'&&row.value.generation!==generation)continue;
  if(row.kind==='view'&&row.value.connection!==connection)continue;
  if(movementEventKinds.has(row.kind)&&(row.value.connection!==connection||row.value.generation!==generation))continue;
  selected.push({...row,at:Math.max(0,row.at-origin)});
 }
 return [...seed,...selected].map((row,index)=>({...row,sequence:index+1}));
}
