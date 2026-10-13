const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native creature bump ${name} is unavailable`);return value|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native creature bump provider ${name} is unavailable`);return p[name];};
// GetIsCreatureBumpable140391100..140391304. Preserve repeated possession
// lookups, >=90 reputation, queued-head ownership, and the PAUSED round flag
// at+2f1c (distinct from round-started+2f04).
export async function creatureBumpable(actor,target,p){
  if(!target.nativePathInfo||target.nativePathInfo.field4<=0)return 0;
  const associates=await required(p,'associates')(actor);
  let friendly=associates?associates.includes(target.id>>>0):false;
  if(!friendly)friendly=integer(await required(p,'reputation')(actor,target.id>>>0,0),'reputation')>=90;
  const animation=integer(target.animationState,'animation');
  if(((animation-6)>>>0&0xfffffffd)===0||!friendly)return 0;
  const pc=async o=>integer(await required(p,'pc')(o),'PC flag');
  const familiar=async o=>integer(await required(p,'possessedFamiliar')(o),'familiar possession');
  const head=()=>{if(!target.objectActionState?.list)throw new Error('Native creature bump target action list is unavailable');return target.objectActionState.list.head?.action??null;};
  let skipPair=false;
  if(await pc(actor)===0){
    if(await familiar(actor)===0){if(await pc(target)!==0||await familiar(target)!==0)return 0;}
    if(await pc(actor)===0&&await familiar(actor)===0)skipPair=true;
  }
  if(!skipPair&&(await pc(target)!==0||await familiar(target)!==0))return Number(head()===null);
  if((await pc(actor)===0&&await familiar(actor)===0)||await pc(target)!==0||await familiar(target)!==0){
    if(await pc(actor)===0&&await familiar(actor)===0&&await pc(target)===0&&await familiar(target)===0&&
       head()===null&&integer(target.nativeField700,'combat state')===0){
      if(!target.combatRound)throw new Error('Native creature bump combat round is unavailable');return Number(Number(target.combatRound.paused)===0);
    }
    return 0;
  }
  const node=head();
  if(node){const action=integer(node.actionId,'queued action ID')>>>0;if(action<=46&&(0x400000009000n>>BigInt(action)&1n)!==0n)return 0;}
  return 1;
}
