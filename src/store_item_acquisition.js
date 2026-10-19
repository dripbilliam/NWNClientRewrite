// Complete CNWSStore::AcquireItem1404f9ea0..1404fa049. The input pointer
// is by value. Infinite-stock duplication destroys it without updating its
// caller's pointer; script wrappers can consequently return the now-stale ID.
export async function acquireStoreItem(store,item,_flag,_x,_y,p){
 if(!item)return 0;
 if(typeof item.plot!=='boolean'&&!Number.isInteger(item.plot))throw new Error('Native store item plot field is unavailable');
 if(Number(item.plot)!==0)return 0;
 await p.identified(item,1);const previous=p.object(item.possessorId>>>0);let creature=null;
 if(previous){
  if(p.asCreature(previous))creature=p.asCreature(previous);
  else if(p.asItem(previous))creature=p.creature(p.asItem(previous).possessorId>>>0);
 }
 if(creature)await p.removeCreatureItem(creature,item,0,1,0,1);
 const panel=await p.panel(store,item.baseItem>>>0);if(panel>4)return 0;
 const existing=p.item(await p.findTag(p.repository(store,panel),item.tag));
 if(existing&&existing.nativeInfinite444!==0&&await p.compare(existing,item)!==0){await p.destroy(item,1);return 1;}
 await p.setPossessor(item,store.id,1,1,0);return p.add(store,{item},panel,255,255);
}

// Complete GetAppropriateListId1404fb590..1404fb5fd.
export async function appropriateStorePanel(store,base,p){
 const info=p.baseInfo({baseItem:base});if(!info)throw new Error('Native store panel dereferences unavailable base storage');
 const panel=info.storePanel&255;if(panel<=4)return panel;await p.warning('Base item on unknown store panel');return 4;
}

// CNWSStore::AddItemToInventory1404fa1b0..1404fa53f. The incoming X/Y
// arguments are ignored by the original: every repository addition uses255,
//255,0,0. Existing records are scanned tail-to-head through GetPrev.
export async function addStoreItem(store,ref,panel,_x,_y,p){
 const item=ref.item;if(!item)throw new Error('Native store acquisition dereferences a null item');
 const priority=(await p.baseInfo(item)).storePanelSort&255,price=(await p.price(item,0,1,0,0))>>>0,repository=await p.repository(store,panel&255);
 const head=await p.head(repository),first=head?await p.item(repository,head):null;
 if(first){
  const sort=(await p.baseInfo(first)).storePanelSort&255;
  if(sort>=priority&&(sort!==priority||((await p.price(first,0,1,0,0))>>>0)>price)){
   let node=await p.tail(repository);
   while(node){
    const previous=await p.item(repository,node);
    if(!previous)await p.warning('Invalid item in store inventory!');
    else{
     if((previous.id>>>0)===(ref.item.id>>>0)){
      await p.warning('This item is already in the store!?');
      if((previous.id>>>0)===(ref.item.id>>>0))return 0;
     }
     const previousSort=(await p.baseInfo(previous)).storePanelSort&255;
     if(previousSort>priority||(previousSort===priority&&((await p.price(previous,0,1,0,0))>>>0)>price))break;
    }
    node=await p.previous(repository,node);
   }
   const retained=[];
   while(node){
    const previous=await p.item(repository,node);if(previous)retained.push(previous);
    const removed=node;node=await p.previous(repository,node);await p.removeNode(repository,removed);
   }
   await p.add(repository,ref,255,255,0,0);
   for(const previous of retained)await p.add(repository,{item:previous},255,255,0,0);
   return 1;
  }
 }
 await p.add(repository,ref,255,255,0,0);return 1;
}
