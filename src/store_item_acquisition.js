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
