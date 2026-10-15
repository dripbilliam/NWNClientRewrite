// ExecuteCommandGetLocked14052b4c0: door cast before placeable, returning
// raw native INT424/378. Other objects and missing canonical IDs return0.
export function getObjectLocked(o){
  if(!o||![9,10].includes(o.objectType))return 0;
  const value=o.locked;if(typeof value==='boolean')return Number(value);
  if(!Number.isInteger(value))throw new Error('Native object lock storage is unavailable');return value|0;
}
