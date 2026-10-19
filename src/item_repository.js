import {nativeObjectTag} from './object_tag.js';
import {nativeItemTag} from './item_stack_compare.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native repository ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native repository provider ${name} is unavailable`);return p[name];};
const byte=(v,name)=>integer(v,name)&255;
const invalid=0x7f000000;

// Complete FindItemWithTag1404680a0..1404681cd. Search each node before
// recursively visiting its repository, preserving physical head-to-tail order.
export function repositoryFindTag(repo,tag,p){
 const query=nativeItemTag(nativeObjectTag(tag)),seen=new Set();
 const visit=repository=>{
  if(seen.has(repository))throw new Error('Native repository tag recursion contains a cycle');seen.add(repository);
  for(const id of repository.ids()){
   const lookup=p.lookup(id);if(lookup.status!==0||!lookup.object)continue;
   const item=p.asItem(lookup.object);if(!item)throw new Error('Native repository tag search dereferences a non-item');
   const current=p.tag(item);let match=current.length===query.length;
   if(match&&current.present){for(let i=0;;i++){const a=current.bytes[i]??0,b=query.bytes[i]??0;if(a!==b){match=false;break;}if(b===0)break;}}
   if(match){seen.delete(repository);return item.id>>>0;}
   const child=p.repository(item);if(child){const result=visit(child);if(result!==invalid){seen.delete(repository);return result;}}
  }
  seen.delete(repository);return invalid;
 };return visit(repo);
}

// CalculatePage1404656a0..1404656b6. BYTE coordinates/width, unsigned
// boundary division; callers decide whether to truncate the quotient to BYTE.
export function repositoryPage(repo,x,y){
  const boundary=integer(repo.boundary,'page boundary')>>>0;
  if(boundary===0)throw new Error('Native repository page would divide by zero');
  return Math.trunc((byte(repo.width,'page width')*byte(y,'page y')+byte(x,'page x'))/boundary)>>>0;
}

// CItemRepository140462d40. Nodes contain canonical uint32 object IDs;
// equipment slots are owned separately by CNWSInventory. No alternate IDs.
export class ItemRepository {
  constructor(ownerId,width,height,boundary,expand,warning){
    this.ownerId=integer(ownerId,'owner ID')>>>0;this.width=byte(width,'width');this.height=byte(height,'height');
    this.expand=integer(expand,'expansion field');boundary=integer(boundary,'boundary')>>>0;
    if(this.width===0||boundary===0)throw new Error('Native repository constructor would divide by zero');
    if(boundary%this.width!==0||this.height%(Math.trunc(boundary/this.width))!==0){
      if(typeof warning!=='function')throw new Error('Native repository boundary warning provider is unavailable');
      warning('Repository boundary not valid for given width and height');boundary=this.width*this.height;
    }
    this.boundary=boundary;this.head=null;this.tail=null;this.length=0;
  }
  // LinkedList::AddHead140168fb0 used by AddItem140464a9b. This primitive
  // alone does not perform acquisition, stacking, fit, possession or events.
  insertHead(id){
    const node={id:integer(id,'item ID')>>>0,next:this.head,previous:null};
    if(this.head)this.head.previous=node;else this.tail=node;
    this.head=node;this.length++;return node;
  }
  *ids(){for(let node=this.head;node;node=node.next)yield node.id;}
  removeNode(node){
    if(node.previous)node.previous.next=node.next;else this.head=node.next;
    if(node.next)node.next.previous=node.previous;else this.tail=node.previous;
    this.length--;node.previous=null;node.next=null;
  }
}

// GetItemInRepository140468bd0. Canonical identity, repository order,
// optional recursive containers; base-rule Container must be nonzero.
export function repositoryContains(repo,item,nested,p,ancestors=new Set()){
  if(!repo)throw new Error('Native repository membership storage is unavailable');
  if(ancestors.has(repo))throw new Error('Native repository membership encountered a container cycle');
  const path=new Set(ancestors);path.add(repo);
  for(const id of repo.ids()){
    const object=required(p,'object')(id);if(!object||object.objectType<=4)continue;
    if(item&&object===item)return 1;
    if(integer(nested,'recursive membership')===0||object.objectType!==6)continue;
    const base=required(p,'baseInfo')(object);if(!base||integer(base.container,'container rule')===0)continue;
    const child=required(p,'repository')(object);
    if(child&&repositoryContains(child,item,nested,p,path)!==0)return 1;
  }
  return 0;
}

// RemoveItem14046b250. Removes the first matching ID and only refreshes
// encumbrance for an owned container==1 with property32. Does not clear owner.
export async function repositoryRemove(repo,item,p){
  if(!item)return 0;if(!repo)throw new Error('Native repository removal storage is unavailable');
  const id=integer(item.id,'item ID')>>>0;let node=repo.head;while(node&&node.id!==id)node=node.next;
  if(!node)return 0;repo.removeNode(node);
  const owner=required(p,'objectById')(repo.ownerId);if(owner?.objectType!==6)return 1;
  const base=required(p,'baseInfo')(owner);if(!base)throw new Error('Native repository removal dereferences unavailable base storage');
  if(base.container!==1||owner.possessorId===invalid)return 1;
  const creature=p.objectById(owner.possessorId);if(creature?.objectType===5&&required(p,'hasProperty')(owner,32))await required(p,'updateEncumbrance')(creature,1);
  return 1;
}

// CheckFit140465c10 uses BYTE endpoints and BYTE page index/height. Preserve
// the three native overlap alternatives, including wrapped rectangles.
export function repositoryFit(repo,item,x,y,p){
  x=byte(x,'x');y=byte(y,'y');const info=required(p,'baseInfo')(item);if(!info)return 0;
  const xe=(byte(info.width,'item width')-1+x)&255,ye=(byte(info.height,'item height')-1+y)&255;
  if(x>=repo.width||y>=repo.height||xe>=repo.width)return 0;
  if(repo.boundary===0||repo.width===0)throw new Error('Native repository fit would divide by zero');
  const page=Math.trunc((y*repo.width+x)/repo.boundary)&255,pageHeight=Math.trunc(repo.boundary/repo.width)&255;
  if(ye>=(page+1)*pageHeight)return 0;
  const overlap=(lo,hi,otherLo,otherHi)=>otherLo>=lo&&otherLo<=hi||otherHi>=lo&&otherHi<=hi||otherLo<lo&&otherHi>hi;
  for(const id of repo.ids()){
    const other=required(p,'itemById')(id);if(!other||other.objectType!==6||id===(integer(item.id,'item ID')>>>0))continue;
    const otherInfo=required(p,'baseInfo')(other);
    if(!otherInfo)throw new Error('Native repository fit dereferences unavailable existing base-item storage');
    const ox=byte(other.repositoryX,'existing item x'),oy=byte(other.repositoryY,'existing item y');
    const oxe=(byte(otherInfo.width,'existing item width')-1+ox)&255,oye=(byte(otherInfo.height,'existing item height')-1+oy)&255;
    if(overlap(x,xe,ox,oxe)&&overlap(y,ye,oy,oye))return 0;
  }
  return 1;
}

// MoveItem14046ac90: canonical array lookup per physical node, identity match,
// then CheckFit. Repositioning does not remove/reinsert or change possession.
export function repositoryMove(repo,item,x,y,p){
  x=byte(x,'x');y=byte(y,'y');if(!repo)throw new Error('Native repository move storage is unavailable');
  for(const id of repo.ids()){
    const found=required(p,'lookup')(id);
    if(found.status!==0||!found.object||found.object!==item)continue;
    if(required(p,'fit')(repo,item,x,y)===0)return 0;
    item.repositoryX=x;item.repositoryY=y;return 1;
  }
  return 0;
}

// Initial FindPosition14046826d..1404682c6 scan. Autoexpansion/drop and failure
// feedback are separate required owners, not implied by a failed grid scan.
export function repositoryScan(repo,item,p){
  if(!item)return null;const info=required(p,'baseInfo')(item);if(!info)return null;
  const w=byte(info.width,'item width'),h=byte(info.height,'item height');
  for(let y=0;y<repo.height-h+1;y++)for(let x=0;x<repo.width-w+1;x++)if(repositoryFit(repo,item,x,y,p))return {x,y};
  return null;
}

// FindPosition1404681d0. The allow-drop branch has a separate RemoveItem/
// area placement owner. Do not turn it into a false "inventory full" result.
export async function repositoryFindPosition(repo,item,allowDrop,p){
  const found=repositoryScan(repo,item,p);if(found||!item||!required(p,'baseInfo')(item))return found;
  const owner=required(p,'objectById')(repo.ownerId);
  if(integer(allowDrop,'allow drop')!==0){
    if(owner?.objectType!==5)return null;
    return await required(p,'makeRoom')(repo,item,owner);
  }
  if(owner?.objectType===5)await required(p,'feedback')(owner,12);
  return null;
}

// AddPanel140464b10..140464b4c. The panel count is a BYTE and the height
// addition wraps. A zero panel count is a native division fault, not a reset.
export function repositoryAddPanel(repo){
  if(repo.expand===0)return 0;
  if(repo.boundary===0)throw new Error('Native AddPanel would divide by zero');
  const count=Math.trunc(repo.width*repo.height/repo.boundary)&255;if(count>=25)return 0;
  if(count===0)throw new Error('Native AddPanel would divide by zero');
  repo.height=(repo.height+Math.trunc(repo.height/count))&255;return 1;
}

// CheckItemOverlaps140465e60. Its containment comparison includes an equal
// upper endpoint, unlike CheckFit's strict containment alternative.
export function repositoryItemsOverlap(first,second,x,y,p){
  x=byte(x,'x');y=byte(y,'y');const b=required(p,'baseInfo')(second);if(!b)throw new Error('Native overlap dereferences unavailable base-item storage');
  const xe=(byte(b.width,'width')-1+x)&255,ye=(byte(b.height,'height')-1+y)&255;
  if(first===second)return 0;
  const a=required(p,'baseInfo')(first);if(!a)throw new Error('Native overlap dereferences unavailable existing base-item storage');
  const ax=byte(first.repositoryX,'existing x'),ay=byte(first.repositoryY,'existing y'),axe=(byte(a.width,'existing width')-1+ax)&255,aye=(byte(a.height,'existing height')-1+ay)&255;
  const overlap=(lo,hi,otherLo,otherHi)=>otherLo>=lo&&otherLo<=hi||otherHi>=lo&&otherHi<=hi||otherLo<lo&&hi<=otherHi;
  return Number(overlap(x,xe,ax,axe)&&overlap(y,ye,ay,aye));
}

// AddItem140464200. Item references can change identity during gold handling
// or a complete stack merge; callers must observe ref.item afterwards.
// The fourth native argument is unused; the fifth is exactly merge==1.
export async function repositoryAdd(repo,ref,x,y,_unused,merge,p){
  x=byte(x,'x');y=byte(y,'y');merge=integer(merge,'merge');
  const module=required(p,'module')();if(!module)throw new Error('Native repository AddItem dereferences an unavailable module');
  const original=ref.item,oldPossessor=original?integer(original.possessorId,'possessor ID')>>>0:invalid;
  const quantity=original?integer(original.stackSize,'stack size'):0;
  const owner=required(p,'objectById')(repo.ownerId);let gold=false;
  if(owner?.objectType===5){
    if(!ref.item)throw new Error('Native creature repository AddItem would dereference a null item');
    if(required(p,'baseItem')(ref.item)===76){await required(p,'addGold')(owner,ref.item.stackSize,1);await required(p,'destroyItem')(ref.item);ref.item=null;gold=true;}
  }else if(owner?.objectType===6){
    const base=required(p,'baseInfo')(owner);if(!base)throw new Error('Native container repository dereferences unavailable base-item storage');
    if(integer(base.container,'container field')===1&&owner.possessorId!==invalid){
      const creature=required(p,'objectById')(owner.possessorId);
      if(creature?.objectType===5){
        if(!ref.item)throw new Error('Native container repository AddItem would dereference a null item');
        if(required(p,'baseItem')(ref.item)===76){await required(p,'addGold')(creature,ref.item.stackSize,1);await required(p,'destroyItem')(ref.item);ref.item=null;gold=true;}
        if(!gold&&required(p,'hasProperty')(owner,32))await required(p,'updateEncumbrance')(creature,1);
      }
    }
  }
  const transferred=async resultId=>{
    if(repo.ownerId===oldPossessor)return 1;
    const old=required(p,'objectById')(oldPossessor);
    if(oldPossessor!==invalid){
      if(!old)throw new Error('Native repository transfer dereferences an unavailable previous possessor');
      if(old.objectType===5)await required(p,'event')(old.id,module.id,20,[resultId],[]);
      else if(old.objectType===9&&integer(old.nativeField504,'placeable inventory veto')===0)await required(p,'event')(repo.ownerId,old.id,27,[resultId],[1]);
    }
    if(repo.ownerId===invalid)return 1;
    if(!owner)throw new Error('Native repository transfer dereferences an unavailable destination owner');
    if(owner.objectType===5)await required(p,'event')(resultId,module.id,19,[resultId,oldPossessor,repo.ownerId],[quantity]);
    else if(owner.objectType===9&&integer(owner.nativeField504,'placeable inventory veto')===0)await required(p,'event')(oldPossessor,repo.ownerId,27,[resultId],[0]);
    return 1;
  };
  if(gold)return transferred(invalid);
  if(merge===1){
    for(const id of repo.ids()){
      const item=required(p,'itemById')(id);
      if(!item||required(p,'baseItem')(item)!==required(p,'baseItem')(ref.item)||!await required(p,'compareItems')(item,ref.item))continue;
      const base=required(p,'baseInfo')(item);if(!base)throw new Error('Native stack merge dereferences unavailable base-item storage');
      const old=integer(item.stackSize,'existing stack size'),maximum=integer(base.stacking,'maximum stack size')&65535,total=(integer(ref.item.stackSize,'new stack size')+old)|0;
      if(total<=maximum){
        item.stackSize=total;
        // Native client overlap/destroy/feedback owners precede destruction.
        await required(p,'mergeFeedback')(repo,item,ref.item,x,y);
        await required(p,'destroyItem')(ref.item);ref.item=item;return transferred(item.id);
      }
      item.stackSize=maximum;ref.item.stackSize=((ref.item.stackSize-maximum)+old)|0;
    }
  }
  if(!(x===255&&y===255)&&repositoryFit(repo,ref.item,x,y,p)===1){}else{
    const find=async()=>{const found=repositoryScan(repo,ref.item,p);if(!found&&ref.item&&required(p,'baseInfo')(ref.item)){const actor=required(p,'objectById')(repo.ownerId);if(actor?.objectType===5)await required(p,'feedback')(actor,12);}return found;};
    let found=await find();
    if(!found){if(!repositoryAddPanel(repo))return 0;found=await find();if(!found)return 0;}
    ({x,y}=found);
  }
  const id=integer(ref.item?.id,'item ID')>>>0;
  for(const existing of repo.ids())if(existing===id){required(p,'warning')('Trying to add the item to the repository twice');return 0;}
  ref.item.repositoryX=x;ref.item.repositoryY=y;repo.insertHead(id);return 1;
}
