// Installed ipm_chest050 has header DWORD8=11 but only ordinary palette IDs
// 0,3,5,6. Accept this observed variant without altering asset bytes or the
// working client's strict decoder. Unknown extra pixel layers stay rejected.
export function acceptsPltHeader11(bytes,width,height){
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<=0||height<=0||width*height>16_777_216||24+width*height*2>bytes.byteLength)return false;
 for(let pixel=0;pixel<width*height;pixel++)if(bytes[25+pixel*2]>=10)return false;
 return true;
}
export function isolatePltCompatibility(source){
 const guard='!layerCount || layerCount > PLT_PALETTE_NAMES.length';
 if(source.split(guard).length!==2||source.includes('acceptsPltHeader11'))throw Error('PLT compatibility boundary changed');
 return `const acceptsPltHeader11=${acceptsPltHeader11.toString()};\n`+source.replace(guard,'(!(layerCount === 11 && acceptsPltHeader11(bytes, width, height)) && (!layerCount || layerCount > PLT_PALETTE_NAMES.length))');
}
