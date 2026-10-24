// Generated code contains only locally authored operations and numeric slots.
// Shader sources, resource names and server data never become executable text.
const numeric=/^uniform(?:[1234](?:f|i|ui|fv|iv|uiv)|Matrix[234](?:x[234])?fv)$/;
const allowed=new Set(['useProgram','activeTexture','bindTexture','bindSampler','bindVertexArray','bindBuffer','enable','disable','blendEquation','blendEquationSeparate','blendFunc','blendFuncSeparate','blendColor','colorMask','depthMask','depthFunc','stencilMask','stencilMaskSeparate','stencilFunc','stencilFuncSeparate','stencilOp','stencilOpSeparate','cullFace','frontFace','polygonOffset','lineWidth','viewport','scissor','drawArrays','drawElements','depthRange','bindBufferBase','bindBufferRange','bindFramebuffer','bindRenderbuffer','enableVertexAttribArray','disableVertexAttribArray','vertexAttribPointer','vertexAttribIPointer','vertexAttribDivisor','vertexAttrib1f','vertexAttrib2f','vertexAttrib3f','vertexAttrib4f','vertexAttrib1fv','vertexAttrib2fv','vertexAttrib3fv','vertexAttrib4fv','vertexAttribI4i','vertexAttribI4ui','vertexAttribI4iv','vertexAttribI4uiv']);
const clone=value=>ArrayBuffer.isView(value)?new value.constructor(value):Array.isArray(value)?value.slice():value;

export function compileRendererPackets(plan,{maxCommands=100000,maxCodeBytes=96*1024*1024,blockSize=128}={}){
 if(!plan?.commands?.length||plan.commands.length>maxCommands||!Number.isInteger(blockSize)||blockSize<1||blockSize>1024)throw Error('Invalid render packet capacity');
 const args=[],calls=[],states=[],draws=[],programs=[],stateIds=new Map(),programIds=new Map();let code='',blocks=[],bytes=0,previousProgram;
 const programSlot=value=>{if(!programIds.has(value)){programIds.set(value,programs.length);programs.push(value);}return programIds.get(value);};
 const flush=()=>{if(!code)return;bytes+=code.length*2;if(bytes>maxCodeBytes)throw Error('Generated render packet capacity');blocks.push(new Function('a','f','s','d','p','gl','owner','generation','stats',code));code='';};
 for(let i=0;i<plan.commands.length;i++){
  const command=plan.commands[i],name=command.name,row=command.args;
  if(!allowed.has(name)&&!numeric.test(name)||typeof command.run!=='function'||!Array.isArray(row)||row.length>9)throw Error('Unsupported render packet operation: '+String(name).slice(0,60));
  args.push(row);calls.push(command.run);const value=k=>`a[${i}][${k}]`,invoke=(values=row.map((_,k)=>value(k)))=>`f[${i}](${values.join(',')});`;
  if(command.program&&command.program!==previousProgram){code+=`gl.useProgram(p[${programSlot(command.program)}]);`;previousProgram=command.program;}
  if(name==='useProgram')previousProgram=row[0];
  if(command.draw){
   if(!['drawElements','drawArrays'].includes(name))throw Error('Invalid render packet draw');
   const drawIndex=draws.length;draws.push(command.draw);
   // The validated geometry/layout stays owned by Three. Counts/ranges remain
   // live and do not allocate temporary objects at submission time.
   const geometry=command.draw.geometry,indexBytes=command.indexed?command.draw.indexBytes:0;
   if(command.indexed&&(!Number.isInteger(indexBytes)||indexBytes<1||indexBytes>4))throw Error('Missing render packet index format');
   code+=`{const draw=d[${drawIndex}],g=draw.geometry,r=g.drawRange,group=draw.group;let start=r.start,end=start+r.count;if(group){start=Math.max(start,group.start);end=Math.min(end,group.start+group.count);}start=Math.max(start,0);end=Math.min(end,g.index?g.index.count:g.attributes.position?.count??0);const count=end-start;if(count>=0&&Number.isFinite(count)){`;
   code+=command.indexed?invoke([value(0),'count',value(2),`start*${indexBytes}`]):invoke([value(0),'start','count']);
   code+=`owner.renderer.info.update(count,${value(0)},1);stats.draws++;}}`;
  }else if(command.uniform){
   if(!numeric.test(name)||!command.uniformState)throw Error('Invalid render packet uniform');
   let at=stateIds.get(command.uniformState);if(at===undefined){at=states.length;stateIds.set(command.uniformState,at);states.push({generation:-1,args:row.map(clone)});}
   const state=states[at];if(state.args.length!==row.length)throw Error('Mixed uniform packet layout');
   const conditions=[`s[${at}].generation!==generation`],copies=[];
   for(let k=1;k<row.length;k++){
    const v=row[k],cached=state.args[k];
    if(ArrayBuffer.isView(v)||Array.isArray(v)){
     if(!cached||cached.length!==v.length||v.length>4096)throw Error('Mixed uniform packet storage');
     for(let j=0;j<v.length;j++)conditions.push(`${value(k)}[${j}]!==s[${at}].args[${k}][${j}]`);
     copies.push(ArrayBuffer.isView(cached)?`s[${at}].args[${k}].set(${value(k)});`:`for(let j=0;j<${v.length};j++)s[${at}].args[${k}][j]=${value(k)}[j];`);
    }else{conditions.push(`${value(k)}!==s[${at}].args[${k}]`);copies.push(`s[${at}].args[${k}]=${value(k)};`);}
   }
   code+=`if(${conditions.join('||')}){${invoke()}${copies.join('')}s[${at}].generation=generation;stats.uniformUploads++;}else{stats.uniformSkipped++;}`;
  }else code+=invoke();
  if((i+1)%blockSize===0)flush();
 }
 flush();
 return{commands:args.length,blocks:blocks.length,codeBytes:bytes,execute(owner,generation,gl,stats){for(const block of blocks)block(args,calls,states,draws,programs,gl,owner,generation,stats);}};
}
