const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native blocked movement ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native blocked movement provider ${n} is unavailable`);return p[n];};

// Creature event10/script WORD31 ->14038f571..14038f61e, RunScript12.
// Capture actual client before writing +528; familiar suppression is separate
// from the actual-client default-name suppression. Blocker is the caller ID.
export async function receiveBlockedMovementEvent(actor,callerId,p){
  const client=await required(p,'client')(actor.id);
  actor.nativeBlockingObject528=integer(callerId,'caller ID')>>>0;
  if(integer(await required(p,'possessed')(actor),'possessed familiar')!==0&&
    integer(await required(p,'rulesetInt')('ALL_ASSOCIATES_RUN_SCRIPTS',0),'associate scripts')===0)return;
  const name=await required(p,'scriptName')(actor,12);
  if(typeof name!=='string')throw new Error('Native blocked movement script name is unavailable');
  if(client&&name==='default')return;
  await required(p,'runScript')(actor,12);
}
