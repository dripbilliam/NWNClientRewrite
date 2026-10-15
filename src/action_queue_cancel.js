import {disposeObjectAction} from './object_actions.js';
const ids=new Map([[0,1],[1,7],[2,9],[3,12],[4,15],[5,20],[6,21],[7,24],[8,25],[9,26],[10,27],[11,28],[12,29],[13,38],[14,39],[15,40],[16,41],[17,42],[18,43],[19,46],[20,9],[21,16],[22,23],[23,17],[24,30],[25,31],[26,39],[27,204],[28,296],[29,65000],[30,65001],[31,50],[32,301],[33,56],[35,55],[36,30],[37,57],[39,425],[40,472],[41,882],[42,947]]);
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native action cancellation ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native action cancellation provider ${n} is unavailable`);return p[n];};
// GetIDByAQActionID1404abb10..1404abc19. Not a simple inversion:
// shared icons select a particular native feat, and some AQ rows returnFFFF.
export function idByQueueActionId(code){return ids.get(integer(code,'AQ ID')&65535)??65535;}

// CancelAction140386700..1403868ad. First matching type/sequence special
// attack wins. Otherwise cancel ALL matching group nodes, even separated
// groups, respecting ClearAction exactly1 and re-reading current head identity.
export async function cancelQueueAction(actor,code,group,p){
  code=integer(code,'AQ ID')&65535;group=integer(group,'group ID')&65535;
  const round=actor.combatRound,list=actor.objectActionState?.list;
  if(!round||!list||!Array.isArray(round.specialAttacks)||!Array.isArray(round.specialAttackParameters))throw new Error('Native cancellation action/special storage is unavailable');
  const count=()=>p.specialCount?integer(p.specialCount(round),'special count'):round.specialAttacks.length;
  const type=n=>p.specialType?integer(p.specialType(round,n),'special type')&65535:integer(round.specialAttacks[n],'special type')&65535;
  const sequence=n=>p.specialId?integer(p.specialId(round,n),'special sequence')&65535:integer(round.specialAttackParameters[n],'special sequence')&65535;
  let n=0,total=count();
  while(n<total){
    if(type(n)!==0){const mapped=(p.inverse??idByQueueActionId)(code);if(type(n)===mapped&&sequence(n)===group){
      if(p.removeSpecial)p.removeSpecial(round,n);else{round.specialAttacks.splice(n,1);round.specialAttackParameters.splice(n,1);}return 1;
    }}
    n++;total=count();
  }
  let changed=0;
  for(let link=list.head;link;){const next=link.next,node=link.action;
    if((node.groupId&65535)===group&&await required(p,'clearAction')(actor,node,node===list.head?.action)===1){
      list.remove(link);await (p.dispose??(node=>disposeObjectAction(node,p.deleteSituation)))(node);changed=1;
    }
    link=next;
  }
  return changed;
}
