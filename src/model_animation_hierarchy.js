const f=Math.fround;
// Complete AnimateHierarchy14004fe90..14004ffe8. Control callback18 belongs
// to the actual MdlNode subtype. IDs30/34 and physical arrays preserve duplicate
// names and sibling order; search starts at each physical child index modulo
// animation child count. The original depth counter is shared across recursion.
export function animateModelHierarchy(part,node,previous,time,weight,context,p){
 context.depth=(context.depth+1)|0;previous=f(previous);time=f(time);weight=f(weight);
 if((part.dirty60|0)===0){
  p.control(node,part,previous,time,weight);
  const light=p.light(part);
  if(light&&(light.field8c|0)===0)p.animateStaticLight(part.owner50,light);
 }
 if(context.depth<1000)for(let i=0;i<(part.childCount40|0);i++){
  const count=node.childCount70|0;if(count<=0)continue;
  const child=part.children38[i],nodes=node.children68,id=child.id30|0;
  for(let j=0;j<count;j++){
   const candidate=nodes[((i+j)|0)%count];
   if(id===(candidate.id34|0)){animateModelHierarchy(child,candidate,previous,time,weight,context,p);break;}
  }
 }
 context.depth=(context.depth-1)|0;
}
