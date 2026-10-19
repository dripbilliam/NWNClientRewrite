import {gffRecord,gffField} from './gff_writer.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native script-situation ${n} is unavailable`);return v|0;};
const string=(v,n)=>{if(typeof v!=='string')throw new Error(`Native script-situation ${n} is unavailable`);return v;};
const bytes=(v,n)=>{if(!(v instanceof Uint8Array))throw new Error(`Native script-situation ${n} buffer is unavailable`);return v;};
const put=(r,n,t,v)=>{r.fields[n]=gffField(t,v);};

// Whole SaveScriptSituation_Internal140284d00..1402851c2. The fifth engine
// save argument is the current stack element (ASM284f35..284f45), despite
// the decompiler omitting it. Engine results do not gate subsequent writes.
export async function saveScriptSituation(s,p,root=gffRecord({})){
 const code=bytes(s.code,'code');put(root,'CodeSize',5,code.length|0);put(root,'Code',13,code.slice());
 if(s.ndb!==null){const ndb=bytes(s.ndb,'NDB');put(root,'NDBSize',5,ndb.length|0);put(root,'NDB',13,ndb.slice());}
 put(root,'InstructionPtr',5,integer(s.instructionPtr,'instruction pointer'));put(root,'SecondaryPtr',5,integer(s.secondaryPtr,'secondary pointer'));
 put(root,'Name',10,string(s.name,'name'));put(root,'StackSize',5,integer(s.stackSize,'original stack size'));
 const stack=s.stack,node=gffRecord({},0);put(root,'Stack',14,node);
 if(!stack||!Array.isArray(stack.cells))throw new Error('Native script-situation stack storage is unavailable');
 put(node,'BasePointer',5,integer(stack.basePointer,'base pointer'));put(node,'StackPointer',5,integer(stack.stackPointer,'stack pointer'));put(node,'TotalSize',5,integer(stack.totalSize,'stack capacity'));
 if(stack.totalSize>0){
  const rows=[];put(node,'Stack',15,rows);
  for(let i=0;i<stack.stackPointer;i++){
   const cell=stack.cells[i];if(!cell)throw new Error('Native script-situation element storage is unavailable');
   const row=gffRecord({},i),type=integer(cell.type,'element type')&255;rows.push(row);put(row,'Type',1,type<<24>>24);
   if(type===3)put(row,'Value',5,integer(cell.value,'INT cell'));
   else if(type===4){if(typeof cell.value!=='number')throw new Error('Native script-situation FLOAT cell is unavailable');put(row,'Value',8,Math.fround(cell.value));}
   else if(type===5)put(row,'Value',10,string(cell.value,'string cell'));
   else if(type===6)put(row,'Value',4,integer(cell.value,'object cell')>>>0);
   else await p.saveEngine(type-16,cell.value,row);
  }
 }
 if(!Array.isArray(s.jumps))throw new Error('Native script-situation jump-list order is unavailable');
 const jumps=[];put(root,'JmpList',15,jumps);
 for(const entry of s.jumps){
  const row=gffRecord({},0);jumps.push(row);put(row,'Label',10,string(entry.label,'jump label').split('\0')[0]);
  for(const [label,key]of [['VMInstPtr','vmInstPtr'],['InstPtr','instPtr'],['StackPtr','stackPtr'],['InstPtrLevel','instPtrLevel']])put(row,label,5,integer(entry[key],key));
  put(row,'FromJmp',5,integer(typeof entry.fromJmp==='boolean'?Number(entry.fromJmp):entry.fromJmp,'jump origin')&255);put(row,'RetVal',5,integer(entry.retVal,'jump return value'));
 }
 put(root,'ScriptChunk',10,string(s.scriptChunk,'script chunk'));put(root,'ScriptEventID',5,integer(s.scriptEventId,'event ID'));return root;
}
