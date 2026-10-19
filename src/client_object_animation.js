// Native non-creature animation-name owners: placeable9b20a0, door9b0790.
// These are separate virtuals from creature961540. Empty override pools only;
// applying transmitted/custom animation replacements remains a separate owner.
export function clientObjectAnimationName(type,id,{doorDestroyed}={}){
 id&=65535;
 if(type===9){
  if([14,77,99,100,213,214,215,216].includes(id))return'damage';
  return({72:'dead',73:'on',74:'off',75:'open',76:'close',400:'on2off',401:'off2on',402:'close2open',403:'open2close',404:'die'})[id]??'default';
 }
 if(type===10){
  if([14,77,99,100,213,214,215,216].includes(id))return'damage';
  if(id===72){if(!Number.isInteger(doorDestroyed))throw new Error('Native door destroyed-model flag is unavailable');return doorDestroyed===0?'default':'dead';}
  return({22:'closed',50:'opened1',51:'opened2',300:'opening1',301:'opening2',302:'closing1',303:'closing2',304:'die'})[id]??'pause';
 }
 throw new Error('Native object animation type is unavailable');
}
