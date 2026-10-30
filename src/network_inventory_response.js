// Original client79f150 and server writers4da470..4dac1f. Results concern
// native UI action acknowledgements; G/object updates still own actual items.
export function readInventoryResponse(r,minor){
 if(minor===14)return{kind:'inventory-ack',itemId:r.readObjectIdClient(),alternate:r.readBool(),operation:'learn'};
 const itemId=r.readObjectIdClient(),alternate=r.readBool(),value={kind:'inventory-result',itemId,alternate,operation:({1:'equip',2:'equip',3:'drop',4:'drop',5:'pickup',6:'pickup',7:'unequip',8:'unequip',9:'move',10:'move'})[minor],success:minor%2===1};
 if(minor===1||minor===2)value.slot=r.readDword();return value;
}
