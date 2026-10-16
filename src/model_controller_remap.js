// ReadBinaryNode14007b870..14007b93a, within complete14007b6c0..14007b9e1.
// Actual subtype queries14008c2e0/360/300 require the base flag as well as
// the subtype bit. Controller offsets are signed INTs; additions wrap INT32.
export function remapModelController(displacement,flags){
 displacement|=0;flags&=255;
 if((flags&5)===5){
  if(displacement>=436)return(displacement+84)|0;
  if(displacement>=392)return(displacement+64)|0;
  if(displacement>=356)return(displacement+56)|0;
  if(displacement>=328)return(displacement+48)|0;
  if(displacement>=276)return(displacement+44)|0;
  if(displacement>=228)return(displacement+36)|0;
  if(displacement>=76)return(displacement+28)|0;
 }else if((flags&33)===33){
  if(displacement>=128)return(displacement+40)|0;
  if(displacement>=116)return(displacement+36)|0;
  if(displacement>=76)return(displacement+28)|0;
 }else if((flags&3)===3&&displacement>=76)return(displacement+28)|0;
 if(displacement>=72)return(displacement+24)|0;
 return displacement>=8?(displacement+8)|0:displacement;
}

// Preserve runtime-remapped controller storage in addition to legacy decoded
// tracks. No quaternion normalization, key sorting, sentinel removal or value
// pool repacking occurs here. Caller owns disk range and node/tree validation.
export function readModelControllerStorage(data,start,range){
 range(start,112);const flags98=data.getUint32(start+108,true),controllersOffset=12+data.getUint32(start+84,true),controllerCount80=data.getUint32(start+88,true),valuesOffset=12+data.getUint32(start+96,true),valueCount90=data.getUint32(start+100,true);
 range(controllersOffset,controllerCount80*12);range(valuesOffset,valueCount90*4);
 const controllers78=Array.from({length:controllerCount80},(_,i)=>{const at=controllersOffset+i*12;return{displacement0:remapModelController(data.getInt32(at,true),flags98),rows4:data.getUint16(at+4,true),timeIndex6:data.getUint16(at+6,true),valueIndex8:data.getUint16(at+8,true),columnsA:data.getUint8(at+10),paddingB:data.getUint8(at+11)};});
 return{id34:data.getInt32(start+28,true),flags98,controllers78,controllerCount80,valueCount90,values88:Array.from({length:valueCount90},(_,i)=>data.getFloat32(valuesOffset+i*4,true)),children68:[],childCount70:0};
}
