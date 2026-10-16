// ExecuteCommandSet/GetDroppableFlag140540ee0/140522b30 access raw INT448.
// This is the same canonical cell used by acquisition, possession and corpse
// transfer. A script setter does not rewrite the original authored template.
export function scriptSetDroppable(item,value){if(item?.objectType===6){if(!Number.isInteger(value))throw new Error('Native item droppable value is unavailable');item.droppable=value|0;}}
export function scriptGetDroppable(item){if(item?.objectType!==6)return 0;if(!Number.isInteger(item.droppable))throw new Error('Native item droppable field448 is unavailable');return item.droppable|0;}
