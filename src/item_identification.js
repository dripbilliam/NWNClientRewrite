// SetIdentified14046c420 stores the unrestricted INT. Only exactly1 sets
// price dirty398 to1; setting0/2/-1 does not clear or force that cache.
export function setItemIdentified(item,value){
  if(!Number.isInteger(value))throw new Error('Native item identification INT is unavailable');
  item.identified=value|0;if(item.identified===1)item.nativePriceDirty398=1;
}
