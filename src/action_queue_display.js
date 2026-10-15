import {actionByGroupId} from './object_actions.js';
import {OBJECT_INVALID} from './game_object_array.js';
const ordinary=new Map([[1,0],[7,1],[9,2],[12,3],[15,4],[20,5],[21,6],[24,7],[25,8],[26,9],[27,10],[28,11],[29,12],[30,36],[38,13],[39,14],[40,15],[41,16],[42,17],[43,18],[45,43],[46,19],[50,31],[54,34],[55,35],[56,33],[57,37],[59,38]]);
const special=new Map([[9,20],[16,21],[17,23],[23,22],[30,24],[31,25],[39,26],[204,27],[296,28],[301,32],[425,39],[472,40],[866,27],[882,41],[899,27],[947,42],[65000,29],[65001,30]]);
const targetActions=new Set([7,20,21,24,25,26,27,28,38,39,40,41,43,50,54,55,56,57,59]);
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native action queue ${name} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native action queue provider ${n} is unavailable`);return p[n];};
// GetAQActionIDByID1404ab820..1404ab9dd. This compiled engine enum map
// is independent of feat labels/availability from the active 2DA rules.
export function actionQueueId(code,isSpecial=0){return (integer(isSpecial,'mapping flag')===0?ordinary:special).get(integer(code,'action')&65535)??65535;}
export function actionGroupPosition(state,index){
  index=integer(index,'group index');let previous=-1,group=-1;
  for(let link=state.list.head;link;link=link.next){const value=link.action.groupId&65535;if(value!==previous){group++;previous=value;}if(group===index)return link;}return null;
}
const rawWord=(node,index)=>integer(node.parameterData[index],`parameter${index}`)>>>0;
const clearRecord=(view,n)=>{const o=n*28;view.setUint32(o,0xffffffff,true);view.setUint16(o+4,65535,true);view.setUint32(o+8,0xffffffff,true);
  view.setBigUint64(o+12,0n,true);view.setUint32(o+20,0,true);view.setUint32(o+24,OBJECT_INVALID,true);};

// UpdateActionQueue1403a6270..1403a698c. Ten physical28-byte records;
// +6 padding is untouched. Preserve skipped groups, raw coordinate words,
// item SpellIndex, and native special-attack overwrite/cursor behaviour.
// This local scalar storage is not a native pointer or network packet.
export async function updateActionQueueDisplay(actor,p={}){
  const state=actor.objectActionState;if(!state?.list)throw new Error('Native action queue linked list is unavailable');
  actor.nativeActionQueue59c??=new DataView(new ArrayBuffer(280));const view=actor.nativeActionQueue59c;
  if(!(view instanceof DataView)||view.byteLength!==280)throw new Error('Native action queue record storage is unavailable');
  for(let n=0;n<10;n++)clearRecord(view,n);
  let skipped=0,groups=0,index=0;
  const position=n=>(p.groupPosition??actionGroupPosition)(state,n),summary=group=>(p.groupAction??actionByGroupId)(state,group);
  const copy=(node,offset,first)=>{for(let n=0;n<3;n++)view.setUint32(offset+12+n*4,rawWord(node,first+n),true);};
  for(;;){
    let link=position(skipped+groups),node=null;
    while(link){node=summary(link.action.groupId);if(node)break;skipped++;link=position(skipped+groups);}
    if(!node){for(let n=groups;n<10;n++)clearRecord(view,n);return view;}
    const action=integer(node.actionId,'action ID')&65535;
    if(action===12){
      const round=actor.combatRound;if(!round||!Array.isArray(round.specialAttacks)||!Array.isArray(round.specialAttackParameters))throw new Error('Native queue combat special lists are unavailable');
      const count=p.specialCount?integer(await p.specialCount(round),'special count'):round.specialAttacks.length;let packed=0;
      for(let n=0;n<Math.min(count,9);n++){
        const id=p.specialId?await p.specialId(round,n):integer(round.specialAttackParameters[n],'special sequence')&65535;
        const type=p.specialType?await p.specialType(round,n):integer(round.specialAttacks[n],'special type')&65535;
        if(((type+534)&65535)>1&&type!==6&&type!==0){view.setUint16(packed*28+4,actionQueueId(type,1),true);view.setUint16(packed*28,id,true);packed++;}
      }
      if(packed>0){index=packed;groups=packed;}
    }
    const offset=index*28;
    if(action===1){if((rawWord(node,5)>>>6&3)===0){copy(node,offset,0);view.setUint32(offset+24,rawWord(node,3),true);}}
    else if(targetActions.has(action)||action===12)view.setUint32(offset+24,rawWord(node,0),true);
    else if(action===9)copy(node,offset,1);
    else if(action===15){view.setUint32(offset+8,rawWord(node,0),true);view.setUint32(offset+24,rawWord(node,5),true);copy(node,offset,6);}
    else if(action===29){view.setUint32(offset+24,rawWord(node,1),true);copy(node,offset,2);}
    else if(action===46){
      const item=await required(p,'item')(rawWord(node,0)),property=item?await required(p,'activeProperty')(item,rawWord(node,1)):null;
      if(!property){groups++;index++;if(index>9)return view;continue;}
      const spell=await required(p,'spellIndex')(integer(property.subtype,'active property subtype')&65535);
      view.setUint32(offset+24,rawWord(node,3),true);copy(node,offset,4);view.setInt32(offset+8,integer(spell,'item spell index'),true);
    }
    view.setUint16(offset,node.groupId&65535,true);view.setUint16(offset+2,actionQueueId(action,0),true);
    groups++;index++;if(index>9)return view;
  }
}
export function actionQueueRecords(actor){
  const view=actor.nativeActionQueue59c;if(!view)return[];
  return Array.from({length:10},(_,n)=>{const o=n*28;return{group:view.getUint16(o,true),action:view.getUint16(o+2,true),special:view.getUint16(o+4,true),spell:view.getInt32(o+8,true),
    position:[view.getFloat32(o+12,true),view.getFloat32(o+16,true),view.getFloat32(o+20,true)],targetId:view.getUint32(o+24,true)};});
}
