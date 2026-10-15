// ExecuteCommandGetBaseItemType14051f910 reads item+40 as a raw INT.
export function getItemBaseType(item){
  if(item?.objectType!==6)return 256;
  if(!Number.isInteger(item.baseItem))throw new Error('Native base item storage is unavailable');return item.baseItem|0;
}
