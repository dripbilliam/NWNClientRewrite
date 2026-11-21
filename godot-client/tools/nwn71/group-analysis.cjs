'use strict';
function fields(text){const result={};for(const match of text.matchAll(/(?:^|;)([a-z_]+)=([^;]*)/g))result[match[1]]=match[2];return result;}
function key(label){return label.pool&&/^-?\d+$/.test(label.group??'')?label.pool.toLowerCase().replace(/^0x/,'').replace(/^0+(?=.)/,'')+':'+label.group:null;}
function taskKey(label){return label.pool&&/^\d+$/.test(label.task??'')?label.pool.toLowerCase().replace(/^0x/,'').replace(/^0+(?=.)/,'')+':'+label.task:null;}
function analyze(rows){
 const tasks=[],waits=[],shaderWaits=[],variants=[],taskWaits=[],pipelineStages=[];
 for(const row of rows){const label=fields(row.value??''),record={...row,label,key:key(label),taskKey:taskKey(label)};if(row.name==='NWNCapture/Worker/task_scope')tasks.push(record);else if(row.name==='NWNCapture/Worker/wait_group_scope')waits.push(record);else if(row.name==='NWN71/Shader/compile_group_wait')shaderWaits.push(record);else if(row.name==='NWN71/Shader/compile_variant')variants.push(record);else if(row.name==='NWNCapture/Worker/wait_task_scope')taskWaits.push(record);else if(row.name.startsWith('NWN71/Pipeline/'))pipelineStages.push(record);}
 const groups=new Map();for(const row of [...tasks,...waits,...shaderWaits])if(row.key){if(!groups.has(row.key))groups.set(row.key,{key:row.key,pool:row.label.pool,group_id:row.label.group,tasks:[],waits:[],shader_waits:[]});const target=groups.get(row.key);if(row.name==='NWNCapture/Worker/task_scope')target.tasks.push(row);else if(row.name==='NWNCapture/Worker/wait_group_scope')target.waits.push(row);else target.shader_waits.push(row);}
 const result=[];
 for(const group of groups.values()){
  if(!group.waits.length)continue;
  const descriptions=[...new Set(group.tasks.map(row=>row.label.description??''))].filter(Boolean),shaders=[...new Set(group.shader_waits.map(row=>row.label.shader??''))].filter(Boolean);
  const children=[];
  for(const variant of variants){const enclosing=tasks.filter(task=>task.thread===variant.thread&&task.start_ns<=variant.start_ns&&task.end_ns>=variant.end_ns).sort((a,b)=>(a.end_ns-a.start_ns)-(b.end_ns-b.start_ns));if(enclosing[0]?.key===group.key)children.push(variant);}
  result.push({...group,descriptions,shaders,shader_variants:children,identified_by:'exact exported pool+group label; variant children use innermost enclosing same-thread task',wait_max_ms:Math.max(...group.waits.map(row=>row.duration_ms))});
 }
 const individual=[];
 for(const wait of taskWaits){if(!wait.taskKey)continue;const producers=tasks.filter(task=>task.taskKey===wait.taskKey),stages=[];if(producers.length===1){const producer=producers[0];for(const stage of pipelineStages){const enclosing=tasks.filter(task=>task.thread===stage.thread&&task.start_ns<=stage.start_ns&&task.end_ns>=stage.end_ns).sort((a,b)=>(a.end_ns-a.start_ns)-(b.end_ns-b.start_ns));if(enclosing[0]?.taskKey===producer.taskKey)stages.push(stage);}}
  individual.push({key:wait.taskKey,pool:wait.label.pool,task_id:wait.label.task,wait,producers,pipeline_stages:stages,producerIdentified:producers.length===1,descriptions:[...new Set(producers.map(row=>row.label.description??''))].filter(Boolean),scope:'Exact exported pool+task ID join; no task is assigned from temporal overlap alone'});
 }
 return {groups:result.sort((a,b)=>b.wait_max_ms-a.wait_max_ms),individual_tasks:individual.sort((a,b)=>b.wait.duration_ms-a.wait.duration_ms),pipeline_stages:pipelineStages,counts:{tasks:tasks.length,waits:waits.length,shader_waits:shaderWaits.length,shader_variants:variants.length,labeled_tasks:tasks.filter(row=>row.key).length,labeled_waits:waits.filter(row=>row.key).length,task_waits:taskWaits.length,labeled_task_waits:taskWaits.filter(row=>row.taskKey).length,pipeline_stages:pipelineStages.length},scope:'CPU instrumented elapsed dependency attribution only. Worker spans may overlap each other and render/main waits; durations are never added. GPU or normal-build gains are not inferred.'};
}
module.exports={fields,key,taskKey,analyze};
