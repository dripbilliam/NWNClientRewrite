// Native major40 router76c9d0, complete scalar readers76d0b0..76d750.
// Commands address the active area's client audio owner, not a gameplay object.
export function readNetworkAmbient(r,minor){
 const result={kind:'ambient-command',operation:minor};
 if([1,4,6].includes(minor))result.play=r.readBool();
 else if([2,5].includes(minor))result.value=r.readInt();
 else if([3,7,8].includes(minor)){result.day=r.readBool();result.value=r.readInt();}
 else throw new Error('Unsupported native ambient command');
 return result;
}
