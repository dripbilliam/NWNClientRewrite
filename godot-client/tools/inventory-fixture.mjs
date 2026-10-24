import fs from 'node:fs/promises';
import {inventoryEquipmentLayout} from '../../src/inventory_layout.js';
import {EQUIPMENT_SLOTS} from '../../src/character.js';

export function inventoryUiFixture(){return{
 kind:'inventory-view',viewId:1,title:'Authored',page:0,
 items:[{entryId:0,itemId:2,channel:'R',x:0,y:0,width:1,height:3,slotMask:16,stack:3,name:'Sword',pending:false},
  {entryId:1,itemId:3,channel:'I',slot:2,width:2,height:3,slotMask:2,stack:1,name:'Robe',pending:false},
  {entryId:2,itemId:4,channel:'I',slot:16384,width:1,height:1,slotMask:16384,stack:1,name:'Creature claw',pending:false}],
 layout:inventoryEquipmentLayout(true).map(row=>({...row,label:EQUIPMENT_SLOTS[Math.log2(row.slot)]})),
 summary:{weight:4,capacity:10,gold:20},armorClass:12,container:{ownerId:0x7f000000,pageCount:1}
};}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/inventory-fixture.mjs')){
 const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output)throw Error('Provide an unused --output');
 await fs.writeFile(output,JSON.stringify(inventoryUiFixture())+'\n',{flag:'wx'});console.log(JSON.stringify({output,scope:'Authored native inventory UI metadata only'}));
}
