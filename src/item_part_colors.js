// CNWItem::GetLayeredTextureColorPerPart14029dd60..dd83 and
// SetLayeredTextureColorPerPart1402a0ff0..1065. Missing is sentinel255,
// independent of the six global palette bytes. Allocation is lazy per channel.
export function getItemPartColor(item,channel,part){
 channel&=255;part&=255;return channel<6&&part<19&&item.partColors[channel]?item.partColors[channel][part]&255:255;
}
export function setItemPartColor(item,channel,part,value){
 channel&=255;part&=255;value&=255;if(channel>=6||part>=19)return;
 if(!item.partColors[channel]){if(value===255)return;item.partColors[channel]=Array(19).fill(255);}
 item.partColors[channel][part]=value;
}
