// Normal inventory flags follow the native18-slot inventory. The final four
// are creature-only equipment and are an optional presentation preference.
export const INVENTORY_CELL=40;
export const INVENTORY_EQUIPMENT=[
 {slot:16,x:0,y:0,w:80,h:240,empty:'inv_slot_right'},
 {slot:2,x:80,y:0,w:100,h:160,empty:'inv_slot_armor'},
 {slot:32,x:180,y:0,w:80,h:160,empty:'inv_slot_left'},
 {slot:1,x:260,y:0,w:80,h:80,empty:'inv_slot_helm'},
 {slot:512,x:260,y:80,w:80,h:80,empty:'inv_slot_amulet'},
 {slot:64,x:340,y:0,w:80,h:160,empty:'inv_slot_cloak'},
 {slot:8,x:180,y:160,w:80,h:80,empty:'inv_slot_gloves'},
 {slot:128,x:260,y:160,w:40,h:40,empty:'inv_slot_ring'},
 {slot:256,x:260,y:200,w:40,h:40,empty:'inv_slot_ring'},
 {slot:1024,x:300,y:160,w:40,h:80,empty:'inv_slot_belt'},
 {slot:4,x:340,y:160,w:80,h:80,empty:'inv_slot_boots'},
 {slot:2048,x:80,y:160,w:100/3,h:80,empty:'inv_slot_arrow'},
 {slot:4096,x:80+100/3,y:160,w:100/3,h:80,empty:'inv_slot_sling'},
 {slot:8192,x:80+200/3,y:160,w:100/3,h:80,empty:'inv_slot_bolts'}
];
export function inventoryEquipmentLayout(showCreatureSlots=false){return [...INVENTORY_EQUIPMENT,...(showCreatureSlots?Array.from({length:4},(_,i)=>({slot:1<<(14+i),x:i*105,y:240,w:105,h:80})):[])];}

// Client player reader7b4f70 maps player-state898/978 to client1b8/28c.
// Inventory refresh856fa0 prints gold, rounded decipounds and the active
// encumbrance table's Normal capacity for the replicated Strength BYTE.
export function inventorySummary(actor,tables){
 const combat=actor?.playerState?.combat??{},s=actor?.inventoryStats??{},weight=s.field28c??combat.field978,strength=s.field70??s.fields70?.[0]??actor?.playerState?.abilities?.current?.[0],raw=tables?.encumbrance?.rows.get(strength)?.Normal;
 return{gold:Number.isInteger(combat.field898)?combat.field898:null,weight:Number.isInteger(weight)?Math.floor(Math.fround(Math.fround(weight)/10)+.5):null,capacity:raw!==undefined&&raw!=='****'?Math.trunc(Math.fround(Number(raw)/10)+.5):null};
}
