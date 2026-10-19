import {readNativeGff} from './native_gff_fields.js';
// CNWSDoor ctor14041d8e6/8ec; LoadDoor140420c11..c33 and1404220c1..0e2.
// BYTE difficulty and INT lock state are separate live cells.
export function initializeDoorLocks(object){object.nativeDoorOpenLockDC41f??=0;object.nativeDoorKeyRequired450??=0;object.locked??=0;}
export function loadDoorLocks(object,data){
 object.nativeDoorKeyRequired450=Number((readNativeGff(data,'KeyRequired',0,object.nativeDoorKeyRequired450&255).value&255)!==0);
 object.nativeDoorOpenLockDC41f=readNativeGff(data,'OpenLockDC',0,object.nativeDoorOpenLockDC41f&255).value&255;
 object.locked=Number((readNativeGff(data,'Locked',0,object.locked&255).value&255)!==0);
}
export function doorOpenLockDC(object){
 if(!Number.isInteger(object.nativeDoorOpenLockDC41f))throw new Error('Native door OpenLockDC field41f is unavailable');
 return object.nativeDoorOpenLockDC41f&255;
}
