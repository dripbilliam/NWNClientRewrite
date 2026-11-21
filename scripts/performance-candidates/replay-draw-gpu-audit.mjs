// Diagnostic only: elapsed windows surround raw draw entry points, excluding
// CPU preparation BETWEEN draws. Uploads, clears and other GPU work are outside
// these windows; this is not a full-frame utilization or FPS measurement.
export async function auditReplayDrawGPU({renderer,draw,requestFrame=callback=>requestAnimationFrame(callback),now=()=>performance.now(),deadlineMs=10000,maxQueries=8192}){
 const gl=renderer.getContext(),timer=gl.getExtension('EXT_disjoint_timer_query_webgl2');if(!timer)return{available:false};
 if(gl.getError()!==gl.NO_ERROR||gl.getQuery(timer.TIME_ELAPSED_EXT,gl.CURRENT_QUERY))throw Error('Per-draw audit requires clean, unnested timers');
 draw();const rows=[],restores=[];let nesting=0;
 const wrap=(object,key)=>{
  const before=object?.[key];if(typeof before!=='function')return;
  function measured(...args){
   if(nesting)return before.apply(this,args);
   if(rows.length>=maxQueries)throw Error('Per-draw audit query capacity');
   const query=gl.createQuery();if(!query)throw Error('Per-draw audit allocation');
   rows.push({query,method:key,target:renderer.getRenderTarget()===null?'main':'offscreen'});gl.beginQuery(timer.TIME_ELAPSED_EXT,query);nesting++;
   try{return before.apply(this,args);}finally{nesting--;gl.endQuery(timer.TIME_ELAPSED_EXT);}
  }
  object[key]=measured;restores.push(()=>{if(object[key]===measured)object[key]=before;});
 };
 try{
  for(const key of ['drawArrays','drawElements','drawArraysInstanced','drawElementsInstanced'])wrap(gl,key);
  const multi=gl.getExtension('WEBGL_multi_draw');for(const key of ['multiDrawArraysWEBGL','multiDrawElementsWEBGL','multiDrawArraysInstancedWEBGL','multiDrawElementsInstancedWEBGL'])wrap(multi,key);
  const start=now();try{draw();}finally{for(const restore of restores.reverse())restore();restores.length=0;}
  const instrumentedSubmitMs=now()-start,until=now()+deadlineMs;
  while(rows.some(r=>!gl.getQueryParameter(r.query,gl.QUERY_RESULT_AVAILABLE))){if(now()>until)throw Error('Per-draw audit deadline');await new Promise(requestFrame);}
  const disjoint=Boolean(gl.getParameter(timer.GPU_DISJOINT_EXT)),groups={};let sumDrawWindowsMs=0;
  for(const row of rows){const ms=disjoint?null:gl.getQueryParameter(row.query,gl.QUERY_RESULT)/1e6,key=row.target+':'+row.method,group=groups[key]??={calls:0,ms:disjoint?null:0,maxMs:disjoint?null:0};group.calls++;if(!disjoint){sumDrawWindowsMs+=ms;group.ms+=ms;group.maxMs=Math.max(group.maxMs,ms);}}
  if(gl.getError()!==gl.NO_ERROR)throw Error('Per-draw audit WebGL error');
  return{available:true,scope:'One warmed frozen frame; sum of elapsed timer windows immediately around raw draws, excluding between-draw preparation, uploads and clears. Instrumented CPU time is diagnostic only.',disjoint,sumDrawWindowsMs:disjoint?null:sumDrawWindowsMs,instrumentedSubmitMs,queries:rows.length,groups};
 }finally{for(const restore of restores.reverse())restore();for(const row of rows)gl.deleteQuery(row.query);}
}
