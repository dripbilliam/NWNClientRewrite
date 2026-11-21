const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));

// Character-sheet page 1 requests the real replicated skill records. Keep
// cached metadata, never invent ranks, and restore the currently open record
// subscription even if another menu was opened while the reply was pending.
export async function ensureShortcutStats(actions,scope,record,{now=()=>performance.now(),wait=pause,timeout=5000}={}){
 if(Array.isArray(scope.actor.inventoryStats?.skills))return false;
 if(!actions.owned(scope))throw Error('Shortcut actor is stale');
 const base={areaId:scope.areaId,areaGeneration:scope.areaGeneration,actorId:scope.actorId,panel:'character'};
 await actions.session.hudPanel({...base,open:true,page:1});
 try{
  const deadline=now()+timeout;
  while(actions.owned(scope)&&!Array.isArray(scope.actor.inventoryStats?.skills)&&now()<deadline)await wait(20);
  if(!actions.owned(scope))return false;
  if(!Array.isArray(scope.actor.inventoryStats?.skills))throw Error('The server has not supplied shortcut skill data. Reopen the menu to retry.');
  return true;
 }finally{
  if(actions.owned(scope)){const current=record();await actions.session.hudPanel({...base,open:Boolean(current?.opened),page:current?.opened?current.page:-1});}
 }
}
