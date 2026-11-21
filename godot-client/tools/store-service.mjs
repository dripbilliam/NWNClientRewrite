import {networkStorePrice} from '../../src/network_store.js';

// Uses the existing store protocol. A transaction reply carries an item and
// store gold, not a success flag; canonical world updates own all outcomes.
export class StoreService{
 constructor(inventory){this.inventory=inventory;this.pending=new Map();}
 reset(){this.pending.clear();this.generation=null;this.navigation=null;}
 get world(){return this.inventory.session.world;}
 get open(){return Boolean(this.world.store?.open);}
 snapshot(){return[this.world.store,this.world.inventories.get('M'),[...this.pending],this.navigation];}
 expire(now){for(const[id,request]of this.pending)if(now-request.at>6000){this.pending.delete(id);this.inventory.emit({kind:'inventory-notice',text:'The server has not confirmed that store transaction.'});}if(this.navigation&&now-this.navigation.at>6000){this.navigation=null;this.inventory.emit({kind:'inventory-notice',text:'The server has not confirmed that merchant page.'});}}
 async metadata(scope){
  const s=scope.world.store;if(!s?.open)return{open:false};
  const labels=await Promise.all(Array.from({length:5},(_,panel)=>this.inventory.actions.text.resolve({strRef:0xf85c+panel},scope.actorId)));
  return{open:true,generation:s.generation,panel:s.panel,page:s.page??0,pageCount:scope.world.inventories.get('M')?.pageCount??1,gold:s.gold,identifyPrice:s.identifyPrice,labels,restricted:s.restricted,baseItems:s.baseItems??[],blackMarket:s.blackMarket,navigationPending:Boolean(this.navigation)};
 }
 receive(message){
  if(message.kind==='store-open'){if(this.generation!==this.world.store?.generation){this.reset();this.generation=this.world.store?.generation;}this.inventory.automatic=true;this.inventory.signature=null;if(!this.inventory.opened)void this.inventory.open().catch(error=>this.inventory.emit({kind:'inventory-notice',text:error.message}));}
  else if(message.kind==='store-close'){this.reset();this.inventory.signature=null;}
  else if(message.kind==='store-transaction'){
   if(this.pending.delete(message.itemId))this.inventory.emit({kind:'inventory-notice',text:'Server transaction reply received.'});
   this.inventory.signature=null;
  }else if(message.kind==='examine'&&message.type==='item'&&!message.close&&this.pending.get(message.targetId)?.operation==='identify'){
   this.pending.delete(message.targetId);this.inventory.signature=null;
   this.inventory.emit({kind:'inventory-notice',text:message.identified?'The item is identified.':'The item remains unidentified.'});
  }else if(message.kind==='object-updates'&&this.navigation){
   const n=this.navigation;
   if(message.records?.some(row=>row.action==='inventory'&&row.channel==='M'&&(n.operation==='panel'?row.operation==='P'&&row.panel===n.panel:['A','U','P'].includes(row.operation)))){this.navigation=null;this.inventory.signature=null;}
  }
 }
 async command(request){
  const iv=this.inventory,view=iv.current(request.viewId),scope=view.scope,s=scope.world.store;
  if(!s?.open)throw Error('No store is open');
  if(this.navigation&&request.operation!=='close'&&request.operation!=='examine')throw Error('Waiting for the server merchant page');
  const operation=request.operation,fields={};let row=null;
  if(['buy','sell','identify'].includes(operation)){
   row=iv.selected(request.viewId,request.entryId).row;
   const location=row.object.inventoryLocation,buy=location?.channel==='M',owned=location?.ownerId===scope.actorId&&['I','R'].includes(location.channel);
   if(operation==='buy'?!buy:!owned)throw Error('That item is unavailable for this store operation');
   if(operation==='identify'&&row.object.item.identified)throw Error('That item is already identified');
   if(this.pending.has(row.object.id))throw Error('That item is waiting for the server');
   fields.itemId=row.object.id;
  }else if(operation==='panel'){
   if(!Number.isInteger(request.panel)||request.panel<0||request.panel>=5)throw Error('Invalid store category');fields.panel=request.panel;
  }else if(operation==='page'){
   const count=scope.world.inventories.get('M')?.pageCount??1;
   if(!Number.isInteger(request.page)||request.page<0||request.page>=count)throw Error('Invalid store page');fields.page=request.page;
  }else if(operation!=='close')throw Error('Unsupported store operation');
  // The server need not resend a category/page that is already selected.
  // Do not let the generic sender clear its canonical grid in that case.
  if(operation==='panel'&&fields.panel===s.panel||operation==='page'&&fields.page===(s.page??0)){await iv.refresh(true);return;}
  const pending=row?{operation,at:iv.now()}:null;
  const navigation=['panel','page'].includes(operation)?{operation,...fields,at:iv.now()}:null;
  if(navigation)this.navigation=navigation;
  if(row)this.pending.set(row.object.id,pending);
  iv.signature=null;
  try{await iv.session.storeInput({...iv.base(scope),storeGeneration:s.generation,operation,...fields});iv.onRequest({store:true,operation,...fields});
   // Native identification does not send the buy/sell transaction message.
   // Ask for the actual description on the ordered protocol; its identified
   // flag updates the canonical item through NetworkWorld, never a prediction.
   if(operation==='identify'&&iv.owned(scope)&&scope.world.store===s&&this.pending.get(row.object.id)===pending)await iv.session.examine({...iv.base(scope),targetId:row.object.id});
  }
  catch(error){if(row&&this.pending.get(row.object.id)===pending)this.pending.delete(row.object.id);if(navigation&&this.navigation===navigation)this.navigation=null;throw error;}
  finally{if(iv.owned(scope)&&scope.world.store===s)await iv.refresh(true);}
 }
 decorate(object,channel){const s=this.world.store;return s?.open&&['I','R','M'].includes(channel)?{price:networkStorePrice(s,object.item,channel==='M'),canIdentify:channel!=='M'&&!object.item.identified,pending:this.pending.has(object.id)||this.inventory.pending.has(object.id)}:{};}
}
