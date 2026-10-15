import {OBJECT_INVALID} from './game_object_array.js';
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native inventory enumeration provider ${n} is unavailable`);return p[n];};
const word=v=>{if(!Number.isInteger(v))throw new Error('Native inventory enumeration WORD is unavailable');return v&65535;};
const nthNode=(repo,n)=>{let node=repo?.head??null;for(let i=0;i<n&&node;i++)node=node.next;return node;};
// ExecuteCommandGetItemInInventory1405283f0: per-owner WORD cursors over
// carried repositories, then one bag level; equipment is excluded. A stale
// item node returns INVALID without skipping it. First resets the owner.
export function inventoryItem(first,o,p){
  if(!o||![5,6,9,14].includes(o.objectType))return OBJECT_INVALID;
  if(o.objectType===14)return storeInventoryItem(first,o,p);
  const root=required(p,'repository')(o);
  if(o.objectType===6){
    const n=first?0:word(o.nativeItemEnumeration460);o.nativeItemEnumeration460=(n+1)&65535;
    const node=nthNode(root,n),item=node?required(p,'item')(node.id):null;return item?item.id>>>0:OBJECT_INVALID;
  }
  let state=o.nativeInventoryEnumeration;
  if(first)o.nativeInventoryEnumeration=state={outer:1,inner:0,bagId:OBJECT_INVALID};
  if(!state||!Number.isInteger(state.bagId))throw new Error('Native inventory enumeration state is unavailable');
  let repo=root,index;
  if(first)index=0;
  else{
    const bag=required(p,'item')(state.bagId);
    if(!bag||bag.possessorId!==o.id){index=word(state.outer);state.bagId=OBJECT_INVALID;state.inner=0;state.outer=(index+1)&65535;}
    else{index=word(state.inner);repo=p.repository(bag);state.inner=(index+1)&65535;}
  }
  if(!repo)return OBJECT_INVALID;
  let node=nthNode(repo,index);
  if(!node&&root&&repo!==root){
    index=word(state.outer);state.outer=(index+1)&65535;state.bagId=OBJECT_INVALID;state.inner=0;
    repo=root;node=nthNode(root,index);
  }
  const item=node?required(p,'item')(node.id):null;if(!item)return OBJECT_INVALID;
  const base=required(p,'baseInfo')(item);
  if(base&&base.container!==0){state.bagId=item.id>>>0;state.inner=0;}
  return item.id>>>0;
}
// Store inventories enumerate physical category repositories and reset both
// cursors when all categories are exhausted. A stale selected item makes the
// original loop unable to advance; replacement diagnoses that native state.
function storeInventoryItem(first,o,p){
  let index=first?0:word(o.nativeStoreEnumeration388),category=first?0:o.nativeStoreEnumeration38a;
  const repos=required(p,'storeRepositories')(o);if(!Array.isArray(repos)||repos.length!==5||!Number.isInteger(category))throw new Error('Native store enumeration storage is unavailable');
  category&=255;let result=OBJECT_INVALID;
  for(;category<repos.length;category=(category+1)&255,index=0){
    const repo=repos[category];if(!repo)throw new Error('Native store category repository is unavailable');
    if(index>=repo.length)continue;
    const node=nthNode(repo,index),item=node?required(p,'item')(node.id):null;
    if(!item)throw new Error('Native store enumeration cannot advance past a stale item node');
    result=item.id>>>0;break;
  }
  if(category>=repos.length){o.nativeStoreEnumeration388=0;o.nativeStoreEnumeration38a=0;}
  else{o.nativeStoreEnumeration388=(index+1)&65535;o.nativeStoreEnumeration38a=category;}
  return result;
}
