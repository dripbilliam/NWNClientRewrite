import {decodeGffText} from './gff_text.js';
// Original sender4e2360 -> envelope24/5 -> receiver76c450.
// Existing item only: primary+16c/+170 is the object's+124/+128 subobject.
export function readItemTextBubbleOverride(reader){
 const itemId=reader.readObjectIdClient(),mode=reader.readInt(),value=reader.readCExoString();
 return{kind:'item-text-bubble-override',itemId,mode,text:value.bytes?decodeGffText(value.bytes):''};
}
