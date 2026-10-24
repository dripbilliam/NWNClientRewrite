import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';

// Client1407b0de0; server writers1404dd920/4e08a0/4d4ed0.
// Store identity stays server-side: OpenStoreInventory does not carry its ID.
export function readNetworkStore(r,minor){
 if(minor===6)return{kind:'store-close'};
 if(minor===3)return{kind:'store-transaction',itemId:r.readObjectIdClient(),gold:r.readInt()}; // No success BOOL on the wire.
 if(minor!==4)throw new Error('Unsupported native store message');
 const v={kind:'store-open',panel:r.readByte(),sellRate:r.readShort(),buyRate:r.readByte(),blackMarketRate:r.readByte(),identifyPrice:r.readInt(),maxBuyPrice:r.readInt(),gold:r.readInt(),blackMarket:r.readBool(),restricted:r.readBool(),baseItems:[]},n=r.readInt();
 if(n>Math.floor((r.byteSize40-r.byteCursor44)/4))throw new Error('Invalid native store restriction count');
 for(let i=0;i<n;i++)v.baseItems.push(r.readInt());return v;
}
const uint=(v,max,name)=>{if(!Number.isInteger(v)||v<0||v>max)throw new Error(`Invalid native store ${name}`);return v;};
// Client confirmation1409aaba0 assemblyaac68..aaca0 and sell label97bc20:
// unsigned replicated cost, DOUBLE rate/100, truncate, minimum1 for nonzero
// cost. This is display arithmetic; vanilla server owns actual charged price.
export function networkStorePrice(store,item,buy){
 const cost=item.cost>>>0,rate=buy?store.sellRate:item.field458?store.blackMarketRate:store.buyRate;
 let value=cost===0?0:Math.max(1,Math.trunc((rate/100)*cost)>>>0);
 if(!buy&&store.maxBuyPrice!==-1&&(store.maxBuyPrice|0)<=(value|0))value=store.maxBuyPrice>>>0;return value;
}
// Original request writers1407c3a50/a70/af0/b80/c10/d00.
export function storeRequest({operation,itemId,x=255,y=255,destinationId=OBJECT_INVALID,panel,page}){
 if(operation==='close')return Uint8Array.of(112,7,6);
 const minor={buy:1,sell:2,panel:4,page:5,identify:7}[operation];if(minor===undefined)throw new Error('Invalid native store operation');
 const w=new NativeMessageWriter(1);w.create(16,0xffffffff,1);
 if(operation==='panel'||operation==='page')w.writeByte(uint(operation==='panel'?panel:page,255,operation));
 else{w.writeObjectIdClient(uint(itemId,0xffffffff,'item'));if(operation==='buy'){w.writeByte(uint(x,255,'x'));w.writeByte(uint(y,255,'y'));w.writeObjectIdClient(uint(destinationId,0xffffffff,'destination'));}}
 w.setPrefix(Uint8Array.of(112,7,minor));return Uint8Array.from(w.getWriteMessage().data);
}
