import {readNativeGff} from './native_gff_fields.js';

// Whole CVirtualMachineStack::LoadStack140283230..1402835fa. Failure stores
// preceding fields and returns0; the situation loader ignores that result.
export async function loadScriptStack(stack,data,p){
 const read=p.read??readNativeGff,get=(n,t,d)=>read(data,n,t,d).value;
 stack.basePointer=get('BasePointer',5,0)|0;stack.stackPointer=get('StackPointer',5,0)|0;stack.totalSize=get('TotalSize',5,0)|0;stack.cells=[];
 const fail=line=>{stack.loadFailureLine=line;p.stackFailure?.(line);return 0;};
 if(stack.basePointer<0)return fail(0x165);if(stack.stackPointer<0)return fail(0x166);if(stack.totalSize<0)return fail(0x167);
 if(stack.totalSize>0){
  if(stack.stackPointer>stack.totalSize)throw new Error('Native saved VM stack writes beyond allocated elements');
  // Only active cells need host storage; native spare cells are separate capacity.
  stack.cells=Array.from({length:stack.stackPointer},()=>({type:0,value:0}));
  const list=read(data,'Stack',15,null);if(list.status===0)return fail(0x170);
  for(let i=0;i<stack.stackPointer;i++){
   if(i>=list.value.length)return fail(0x175);const row=list.value[i],type=read(row,'Type',1,0).value&255,cell=stack.cells[i];cell.type=type;
   if(type===3)cell.value=read(row,'Value',5,0).value|0;
   else if(type===4)cell.value=Math.fround(read(row,'Value',8,0).value);
   else if(type===5)cell.value=read(row,'Value',10,'').value;
   else if(type===6)cell.value=read(row,'Value',4,0).value>>>0;
   else{const slot={value:0};await p.loadEngine(type-16,row,slot);cell.value=slot.value;}
  }
 }
 return 1;
}

// Whole LoadScriptSituation_Internal140282ab0..140283229. CodeSize0 leaves
// the output pointer untouched. Successful code/metadata loading returns1 even
// when the lower stack loader emitted an error and returned0.
export async function loadScriptSituation(data,p,out={value:undefined}){
 const read=p.read??readNativeGff,get=(n,t,d)=>read(data,n,t,d).value,size=get('CodeSize',5,0)|0;if(size===0)return 0;
 if(size<0)throw new Error('Native saved VM negative code allocation is unavailable');
 const s={code:null,ndb:null,instructionPtr:0,secondaryPtr:0,name:'',stackSize:0,stack:{},jumps:[],scriptChunk:'',scriptEventId:0};out.value=s;
 const blob=(name,length)=>{const value=read(data,name,13,null);if(value.status===0||!(value.value instanceof Uint8Array)||value.value.length<length)throw new Error(`Native saved VM ${name} contains unwritten allocated bytes`);return value.value.slice(0,length);};
 s.code=blob('Code',size);const ndbSize=get('NDBSize',5,0)|0;if(ndbSize>0)s.ndb=blob('NDB',ndbSize);
 s.instructionPtr=get('InstructionPtr',5,0)|0;s.secondaryPtr=get('SecondaryPtr',5,0)|0;s.name=get('Name',10,'');s.stackSize=get('StackSize',5,0)|0;
 const nested=read(data,'Stack',14,null);if(nested.status===0)throw new Error('Native saved VM Stack struct is uninitialized');await loadScriptStack(s.stack,nested.value,p);
 const jumps=read(data,'JmpList',15,null);if(jumps.status!==0)for(const row of jumps.value){
  const get=(n,t,d)=>read(row,n,t,d).value,entry={label:get('Label',10,'').split('\0')[0]};
  for(const [label,key]of [['VMInstPtr','vmInstPtr'],['InstPtr','instPtr'],['StackPtr','stackPtr'],['InstPtrLevel','instPtrLevel']])entry[key]=get(label,5,0)|0;
  entry.fromJmp=Number(get('FromJmp',5,0)!==0);entry.retVal=get('RetVal',5,0)|0;
  await p.assignJump(s,entry);
 }
 s.scriptChunk=get('ScriptChunk',10,'');s.scriptEventId=get('ScriptEventID',5,0)|0;return 1;
}
