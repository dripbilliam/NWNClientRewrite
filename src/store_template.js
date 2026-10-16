import {nativeItemTag} from './item_stack_compare.js';
const INVALID=0x7f000000,empty=()=>({strRef:0xffffffff,entries:[]});

// Complete CNWSStore::LoadFromGff1404fbbf0..1404fc749. GFF/string/tag,
// array append, item construction/loading/pricing/acquisition, UUID and module
// tag owners are explicit providers. Temporary lists are released on return.
export async function loadStoreData(object,loading,newTag,p){
 const R=async(kind,name,fallback)=>(await p.read(kind,name,fallback)).value;
 let tag=newTag;
 if(tag===null||nativeItemTag(tag).length===0)tag=await p.asTag(await R('string','Tag',''));
 await p.setTag(object,tag);await p.localized(object,0x360,await R('localized','LocName',empty()));
 for(const[kind,name,offset,fallback]of[
  ['bool','BlackMarket',0x378,0],['int','BM_MarkDown',0x37c,0],['int','MarkDown',0x380,0],['int','MarkUp',0x384,0],
  ['int','StoreGold',0x38c,-1],['int','IdentifyPrice',0x390,100],['int','MaxBuyPrice',0x394,-1],
 ])await p.field(object,offset,await R(kind,name,fallback));
 for(const[name,offset]of[['WillNotBuy',0x398],['WillOnlyBuy',0x3a8]]){
  const list=await p.list(name);
  if((list.status|0)!==0)for(let i=0,count=(await p.count(list))|0;i<count;i++){
   const row=await p.element(list,i);if((row.status|0)===0)continue;
   const type=await p.readRow(row,'int','BaseItem',-1);
   if((type.status|0)!==0&&(type.value|0)>=0&&(offset===0x398||(await p.arrayCount(object,0x398))===0))await p.appendType(object,offset,type.value|0);
  }
 }
 for(const[name,offset]of[['OnOpenStore',0x308],['OnStoreClosed',0x318],['ResRef',0x30]])await p.string(object,offset,(await R('resref',name,'')).split('\0')[0]);
 const lists=Array.from({length:5},()=>[]),stores=await p.list('StoreList');
 // The original ignores this outer GetList status and both inventory element
 // statuses. The GFF provider owns their output-handle retention semantics.
 let lastNewItem=null;
 for(let i=0,count=(await p.count(stores))>>>0;i<count;i++){
  const store=await p.element(stores,i),items=await p.rowList(store,'ItemList');
  if((items.status|0)===0)continue;
  for(let j=0,length=(await p.count(items))>>>0;j<length;j++){
   lastNewItem=null;const row=await p.element(items,j),id=loading!==0?(await p.readRow(row,'dword','ObjectId',INVALID)).value:INVALID;
   if(await p.existing(id))continue;
   const item=await p.newItem(id);lastNewItem=item;if(!item)continue;
   if((await p.loadItem(item,row,loading,0))!==1){await p.destroyItem(item,1);continue;}
   await p.itemField(item,0x444,(await p.readRow(row,'bool','Infinite',0)).value);
   await p.identified(item,1);
   const priority=(await p.baseInfo(item)).storePanelSort&255,price=(await p.price(item,0,1,0,0))>>>0;
   let panel=(await p.baseInfo(item)).storePanel&255;
   if(panel>=5){await p.warning('Base item on unknown store panel');panel=4;}
   const list=lists[panel];let insertion=list.length;
   for(let k=0;k<list.length;k++){
    const previous=list[k],sort=(await p.baseInfo(previous)).storePanelSort&255;
    if(sort<priority||(sort===priority&&((await p.price(previous,0,1,0,0))>>>0)<price)){insertion=k;break;}
   }
   list.splice(insertion,0,item);
  }
 }
 for(let panel=0;panel<5;panel++)for(let i=lists[panel].length-1;i>=0;i--){
  const ref={item:lists[panel][i]};
  const result=await p.acquire(object,ref,panel,255,255);lists[panel][i]=ref.item;
  // R15 retains the final allocation (even after destruction), rather than
  // the current acquisition ref. Preserve the actual native condition.
  if((result|0)!==0&&lastNewItem)await p.setPossessor(lists[panel][i],object.id,1,1,0);
 }
 await p.addTag(object);await p.loadUUID(object);return 1;
}
