import {OBJECT_INVALID} from './game_object_array.js';
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native item removal provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item removal ${n} is unavailable`);return v|0;};

// RemoveItemFromRepository14039eac0. Bag removal's return value is ignored
// when the bag's direct possessor is the creature; no recursive parent chain.
export async function removeCreatureRepositoryItem(actor,item,includeBag,p){
  if(!item)return 0;includeBag=integer(includeBag,'bag flag');
  if(item.possessorId===actor.id){
    const repo=required(p,'repository')(actor);if(!repo)throw new Error('Native creature item repository is unavailable');
    if([...repo.ids()].includes(item.id)){await required(p,'removeRepositoryItem')(repo,item);return 1;}
  }else if(includeBag===1){
    const owner=required(p,'objectById')(item.possessorId);
    if(owner?.objectType===6&&owner.possessorId===actor.id){await required(p,'removeRepositoryItem')(p.repository(owner),item);return 1;}
  }
  return 0;
}

// RemoveItem1403d7490. Unequip, removal, encumbrance, optional owner clearing,
// then quickbar removal. Failed repo removal still updates encumbrance.
export async function removeCreatureItem(actor,item,unequipFlag,feedback,skipRepository,clearPossessor,p){
  if(!item)return 0;
  unequipFlag=integer(unequipFlag,'unequip flag');feedback=integer(feedback,'feedback');skipRepository=integer(skipRepository,'skip repository');clearPossessor=integer(clearPossessor,'clear possessor');
  if(required(p,'inEquipment')(actor,item)===1)await required(p,'runUnequip')(actor,item.id,OBJECT_INVALID,255,255,unequipFlag,OBJECT_INVALID);
  if(skipRepository===0&&await removeCreatureRepositoryItem(actor,item,1,p)===0){await required(p,'encumbrance')(actor,1);return 0;}
  await required(p,'encumbrance')(actor,1);
  if(clearPossessor!==0)await required(p,'setPossessor')(item,OBJECT_INVALID,1,feedback,0);
  if(required(p,'quickbar')(actor)!==null)await required(p,'removeQuickbarItem')(actor,item.id);
  return 1;
}
