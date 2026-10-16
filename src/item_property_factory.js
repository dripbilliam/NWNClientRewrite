// ExecuteCommandItemPropertyEffect1405338c0..140534ae3. These are engine
// constructor ordinals/property layouts, never spell IDs. Validation reads the
// active ITEMPROPDEF, subtype, cost and parameter tables through providers.
const subtypeCost=new Map([[616,0],[618,2],[619,3],[620,4],[621,5],[623,7],[624,8],[625,9],[629,13],[630,15],[631,16],[635,20],[637,22],[638,23],[639,24],[641,27],[642,28],[643,29],[652,40],[653,41],[659,49],[660,50],[662,52],[667,57],[668,58],[669,59],[678,70]]);
const cost=new Map([[617,1],[622,6],[626,10],[627,11],[636,21],[644,32],[651,39],[656,45],[661,51],[663,53],[665,55],[666,56],[670,60],[677,67],[681,73],[682,74],[684,77],[685,78],[687,80],[758,84],[845,85],[846,86],[847,87]]);
const subtype=new Map([[628,12],[645,33],[646,34],[649,37],[664,54],[672,62],[673,63],[674,64],[675,65],[739,83]]);
const flag=new Map([[640,26],[647,35],[648,36],[650,38],[654,43],[657,47],[679,71],[683,75]]);
export const itemPropertyFactoryOrdinals=new Set([...subtypeCost.keys(),...cost.keys(),...subtype.keys(),...flag.keys(),632,633,634,655,658,671,680,686,688,733,954]);
const count=table=>{if(!Number.isInteger(table?.count)||table.count<0)throw new Error('Native item-property table row count is unavailable');return table.count;};
const integer=value=>{if(!Number.isInteger(value))throw new Error('Native item-property factory integer is unavailable');return value|0;};

export async function createItemProperty(ordinal,args,creator,p){
 ordinal=integer(ordinal);args=args.map(integer);const argc=args.length;
 const effect=p.create(91,creator,Array(9).fill(-1));effect.durationType=(effect.durationType&0xfffa)|2;
 const values=effect.integers;values[7]=100;values[8]=1;
 const arg=i=>{if(i>=args.length)throw new Error('Native item-property constructor argument is unavailable');return args[i];};
 if(subtypeCost.has(ordinal)){values[0]=subtypeCost.get(ordinal);values[1]=arg(0);values[3]=arg(1);}
 else if(cost.has(ordinal)){values[0]=cost.get(ordinal);values[3]=arg(0);}
 else if(subtype.has(ordinal)){values[0]=subtype.get(ordinal);values[1]=arg(0);}
 else if(flag.has(ordinal))values[0]=flag.get(ordinal);
 else if([632,633,634].includes(ordinal)){values[0]=ordinal-615;values[1]=arg(0);values[5]=arg(1);values[3]=arg(2);}
 else if(ordinal===655){values[0]=44;values[3]=arg(0);values[5]=arg(1);}
 else if(ordinal===658){
  values[0]=48;values[1]=arg(0);
  if([0,1,2,3,5,6,7,9,14,15,16,18,19,20,21,22,23].includes(arg(0))){values[3]=arg(1);values[5]=arg(2);}
  else if([8,10,11,12,13,24,25].includes(arg(0)))values[3]=arg(1);
  else if(arg(0)===17){args[1]=(arg(1)-1)|0;values[3]=args[1];}
 }else if(ordinal===671){values[0]=61;values[1]=0;values[3]=arg(0);}
 else if(ordinal===680){values[0]=72;values[1]=arg(0);if(arg(0)>=0&&arg(0)<=9&&(0x265>>arg(0)&1)!==0)values[5]=arg(0);}
 else if(ordinal===686){values[0]=79;values[1]=arg(0)===0?1:arg(0);}
 else if(ordinal===688){values[0]=81;values[5]=arg(0);}
 else if(ordinal===733){values[0]=82;values[1]=arg(0);args[1]=(arg(1)-1)|0;values[3]=args[1];}
 else if(ordinal===954){values[0]=arg(0);values[1]=arg(1);values[3]=arg(2);values[5]=arg(3);}
 let invalid=[618,623,632,667,672].includes(ordinal)&&((values[1]-1)>>>0)>4||values[0]===-1;
 if(ordinal!==954&&args.slice(0,argc).some(n=>n<0))invalid=true;
 const definition=ordinal===954||!invalid?await p.definition():null;
 if(ordinal===954){
  const a=await p.string(definition,args[0],'SubTypeResRef');if(a.status!==0&&args[1]===-1)invalid=true;
  const b=await p.int(definition,args[0],'CostTableResRef');if(b.status!==0&&b.value>0&&args[2]===-1)invalid=true;
  const c=await p.int(definition,args[0],'Param1ResRef');if(c.status!==0&&args[3]===-1)invalid=true;
 }
 let subtypeTable=null;
 if(!invalid){
  const costIndex=await p.int(definition,values[0],'CostTableResRef');if(costIndex.status!==0)values[2]=costIndex.value|0;
  if(values[1]!==-1){
   if(values[1]<0)invalid=true;
   else{
    const ref=await p.string(definition,values[0],'SubTypeResRef');
    if(ref.status!==0){subtypeTable=await p.table(ref.value);if(subtypeTable){
     if(values[1]>=count(subtypeTable))invalid=true;
     else{const entry=await p.int(subtypeTable,values[1],'Name');if(entry.status===0||entry.value===0)invalid=true;}
    }}
   }
  }
  if(!invalid&&values[3]!==-1){
   const table=await p.cost(costIndex.value&255);
   if(!table||values[3]<0||values[3]>=count(table))invalid=true;
   else{const entry=await p.int(table,values[3],'Name');if(entry.status===0||entry.value===0)invalid=true;}
  }
  if(!invalid&&values[5]!==-1){
   if(values[5]<0)invalid=true;
   else{
    const initial=await p.int(definition,values[0],'Param1ResRef');let param=initial.value|0;
    if(initial.status===0&&values[2]!==-1){
     if(!subtypeTable){const ref=await p.string(definition,values[0],'SubTypeResRef');if(ref.status!==0)subtypeTable=await p.table(ref.value);}
     if(subtypeTable)param=(await p.int(subtypeTable,values[1],'Param1ResRef')).value|0;
    }
    if(param!==-1){
     const definition=await p.table('IPRP_PARAMTABLE');
     if(definition){const ref=await p.string(definition,param,'TableResRef');if(ref.status!==0){const table=await p.table(ref.value);if(table&&values[5]>=count(table))invalid=true;}}
    }
   }
  }
 }
 if(invalid)effect.type=0;
 return effect;
}

export function bindItemPropertyFactory(session,api){
 for(const spec of api)if(itemPropertyFactoryOrdinals.has(spec.id)&&spec.returns==='itemproperty'){
  session.commands[spec.name]=(args,frame)=>createItemProperty(spec.id,args,frame.self,session.items.propertyFactoryProviders());
 }
}
