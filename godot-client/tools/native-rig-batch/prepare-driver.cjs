const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3);
const source='systems/model_rigs.gd',bytes=fs.readFileSync(source),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
if(sha(bytes)!=='864c13017c41618a038c18ad59787b7be236a36a1a15632148caacc78a96824a')throw Error('Frozen active-cleanup rig source differs');
const base=bytes.toString('utf8').replace(/\r\n/g,'\n'),start=base.indexOf('func _update(delta: float) -> void:\n'),end=base.indexOf('\nfunc _vec(',start);
if(start<0||end<0)throw Error('Actual update function boundary differs');let update=base.slice(start,end);
const loopStart=update.indexOf('\t\tfor model_index in entry.animated_models'),loopEnd=update.indexOf('\t\t# Native Part60',loopStart);
const original=update.slice(loopStart,loopEnd),body=original.slice(original.indexOf('\n')+1);
const postStart=body.indexOf('\t\t\t\tvar after: float'),post=body.slice(postStart);
if(loopStart<0||loopEnd<0||postStart<0||!body.includes('var model: Dictionary = entry.models[model_index]'))throw Error('Exact animation-loop/post-advance seam differs');
const indent=(text,n)=>text.split('\n').map(line=>line?'\t'.repeat(n)+line:line).join('\n');
const native=`\t\tvar _nwb_indices: Variant=entry.animated_models if entry.has("animated_models") else range(entry.models.size())
\t\tif _nwb_indices is Array:
\t\t\tvar _nwb_batch: Variant=_nwb_context(int(id),entry)
\t\t\tvar _nwb_status:=int(_nwb_batch.step(entry,_nwb_indices,delta))
\t\t\tvar _nwb_start:=0
\t\t\tvar _nwb_post: Dictionary={}
\t\t\tif _nwb_status in [0,1]:
\t\t\t\t_nwb_start=_nwb_indices.size()
\t\t\t\tif _nwb_status==1:emitted=_nwb_batch.take_events()
\t\t\telif _nwb_status!=3:
\t\t\t\temitted=_nwb_batch.take_events()
\t\t\t\tvar _nwb_result: Dictionary=_nwb_batch.take_continuation()
\t\t\t\tif _nwb_status==2:_nwb_start=int(_nwb_result.cursor)
\t\t\t\telif _nwb_status==4:_nwb_start=int(_nwb_result.cursor);_nwb_post=_nwb_result
\t\t\t\telse:
\t\t\t\t\tif emitted!=null:_release_event_batch(emitted)
\t\t\t\t\t_nwb_release_binding(int(id),entry)
\t\t\t\t\tpush_error("Private native animation batch stopped after scene work: "+str(_nwb_result.get("reason","unknown")))
\t\t\t\t\treturn
\t\t\tvar _nwb_cursor:=_nwb_start
\t\t\twhile not _nwb_post.is_empty() or _nwb_cursor<_nwb_indices.size():
\t\t\t\tvar model_index: Variant
\t\t\t\tif not _nwb_post.is_empty():
\t\t\t\t\tmodel_index=_nwb_post.model_index
\t\t\t\t\t_nwb_cursor=int(_nwb_post.cursor)+1
\t\t\t\t\tvar model: Dictionary=_nwb_post.model
\t\t\t\t\tvar player: AnimationPlayer=_nwb_post.player
\t\t\t\t\tvar before: float=_nwb_post.before
\t\t\t\t\tvar length: float=_nwb_post.length
\t\t\t\t\tvar serial: int=_nwb_post.serial
\t\t\t\t\t_nwb_post={}
${indent(post,1)}\t\t\t\telse:
\t\t\t\t\tmodel_index=_nwb_indices[_nwb_cursor]
\t\t\t\t\t_nwb_cursor+=1
${indent(body,2)}\t\telse:
\t\t\t# Unsupported iterator containers retain their original for-loop.
\t\t\tfor model_index in _nwb_indices:
${indent(body,1)}`;
update=update.slice(0,loopStart)+native+update.slice(loopEnd);
update=update.replace('func _update(delta: float) -> void:\n','func _update(delta: float) -> void:\n\tif not _nwb_enabled:super._update(delta);return\n');
const release='if emitted!=null:_release_event_batch(emitted)';
// The inline fatal path already releases its binding. All original attachment/
// skin exit paths release only the stale entry binding after that same phase.
update=update.split('\n').map((line,i,all)=>line.includes(release)&&!all[i+1]?.includes('_nwb_release_binding')?line+'\n'+line.match(/^\t*/)[0]+'_nwb_release_binding(int(id),entry)':line).join('\n');
const prefix=fs.readFileSync(path.join(__dirname,'driver-prefix.gd.inc'),'utf8');const output=arg('out')??'.cache/nwn65/native-batch-source-a/candidate_rigs.gd';
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,prefix+'\n'+update+'\n',{flag:'wx'});
const receipt={source:{file:source,sha256:sha(bytes)},candidate:{file:output,sha256:sha(fs.readFileSync(output))},defaultOffSetting:'nwn/rig_animation_batch',ordinaryScriptFallback:'inline same current index; post-advance resumes captured old model and before/length/serial, even if the retained index array was cleared',productionWrites:0,compiled:false};
fs.writeFileSync(path.join(path.dirname(output),'driver-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(receipt));
