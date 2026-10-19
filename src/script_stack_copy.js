import {nativeAssignedString} from './native_gff_fields.js';

// Whole CopyFromStack14027fd60..140280019: signed byte counts shift right2,
// independent region clamps, tail-of-base/tail-of-stack, and16 spare cells.
// Engine structure copying remains an explicit implementer-owned operation.
export function copyScriptStack(source,topBytes,baseBytes,p={}){
 for(const v of [topBytes,baseBytes,source.basePointer,source.stackPointer])if(!Number.isInteger(v))throw new Error('Native script stack-copy scalar is unavailable');
 const sp=source.stackPointer|0,bp=source.basePointer|0;if(bp<0||sp<0||bp>sp||source.cells.length<sp)throw new Error('Native script stack-copy source storage is unavailable');
 let top=(topBytes|0)>>2,base=(baseBytes|0)>>2;if(top===0&&base===0){base=bp;top=sp-base;}
 base=Math.min(Math.max(base,0),65536,bp);top=Math.min(Math.max(top,0),65536);
 if(top>sp)throw new Error('Native script stack-copy reads before source storage');
 const cells=[],copy=cell=>{
  const type=cell.type&255;let value=0;
  if(type===3)value=cell.value|0;else if(type===4)value=Math.fround(cell.value);else if(type===6)value=cell.value>>>0;
  else if(type===5)value=nativeAssignedString(cell.value);
  else if(type>=16&&type<=25){if(typeof p.copyEngine!=='function')throw new Error('Native VM engine-structure copy owner is unavailable');value=p.copyEngine(type-16,cell.value);}
  return{type,value};
 };
 for(let i=bp-base;i<bp;i++)cells.push(copy(source.cells[i]));
 for(let i=sp-top;i<sp;i++)cells.push(copy(source.cells[i]));
 return{basePointer:cells.length?base:0,stackPointer:cells.length,totalSize:cells.length?cells.length+16:0,cells};
}
