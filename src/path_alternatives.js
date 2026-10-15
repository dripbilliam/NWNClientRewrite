const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native path alternatives ${n} is unavailable`);return v|0;};
function storage(path,index){
  index=integer(index,'index');const count=path.raw.getInt32(0x104,true);
  const nodes=path.allocations.get(0x118),starts=path.allocations.get(0x108),sizes=path.allocations.get(0x110);
  if(index<0||index>=count||!Array.isArray(nodes)||!Array.isArray(starts)||!Array.isArray(sizes)||nodes.length<count||starts.length<count||sizes.length<count)
    throw new Error('Native path alternative storage is unavailable');return{index,nodes,starts,sizes};
}
// DeleteFirstTileFValueAlternatives140294090. A null pointer returns without
// clearing count or other pools. Delete numeric POD successor allocations;
// stale/unknown pointer representations must still fail before disposal.
export function deletePathAlternatives(path){
  const nodes=path.allocations.get(0x118);if(nodes==null)return;
  const count=path.raw.getInt32(0x104,true);
  if(!Array.isArray(nodes)||count>nodes.length)throw new Error('Native path search-node disposal is unavailable');
  for(let n=0;n<count;n++){
    if(nodes[n]!==null&&!Array.isArray(nodes[n]))throw new Error('Native path successor node disposal is unavailable');nodes[n]=null;
  }
  for(const offset of [0x108,0x110,0x118]){path.allocations.delete(offset);path.raw.setBigUint64(offset,0n,true);}
  path.raw.setInt32(0x104,0,true);
}
// Create140293eb0. Only pointer cells are initialized by the owner; the
// two INT allocations remain unreadable until Set supplies their raw values.
export function createPathAlternatives(path,count){
  count=integer(count,'count');if(count<0)throw new Error('Native path alternative allocation overflow is unsupported');
  if(path.allocations.get(0x118)!=null)deletePathAlternatives(path);
  path.allocations.set(0x118,Array(count).fill(null));path.allocations.set(0x108,Array(count).fill(undefined));path.allocations.set(0x110,Array(count).fill(undefined));
  path.raw.setInt32(0x104,count,true);
}
// Get1402941c0/Set140294b20 transfer the same successor allocation identity.
export function getPathAlternatives(path,index){
  const s=storage(path,index);
  return{start:integer(s.starts[s.index],'saved start'),count:integer(s.sizes[s.index],'saved count'),nodes:s.nodes[s.index]};
}
export function setPathAlternatives(path,index,start,count,nodes){
  const s=storage(path,index);s.starts[s.index]=integer(start,'start');s.sizes[s.index]=integer(count,'saved count');s.nodes[s.index]=nodes;
}
