// Resource preparation can overlap IO/link polling. Logical scene attachment
// remains with the caller, in its original order and under its owner guards.
export async function prepareResourceBatch(requests,prepare,{limit=4,current=()=>true}={}){
 if(!Number.isInteger(limit)||limit<1)throw Error('Invalid resource preparation limit');
 const results=new Array(requests.length);let next=0;
 await Promise.all(Array.from({length:Math.min(limit,requests.length)},async()=>{
  while(current()){
   const index=next++;if(index>=requests.length)return;
   try{results[index]={status:'fulfilled',value:await prepare(requests[index],index)};}
   catch(reason){results[index]={status:'rejected',reason};}
  }
 }));
 return results;
}
