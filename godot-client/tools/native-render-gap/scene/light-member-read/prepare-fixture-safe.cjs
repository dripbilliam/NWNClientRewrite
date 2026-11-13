'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const original=path.join(__dirname,'fixture.gd'),output=path.join(__dirname,'fixture-base-safe.gd');if(fs.existsSync(output))throw Error('Existing B-only base fixture retained');let text=fs.readFileSync(original,'utf8');
function once(from,to){assert.equal(text.split(from).length,2,from.slice(0,100));text=text.replace(from,()=>to);}
const line=text.split('\n').find(line=>line.startsWith('const REORDERED='));assert(line);once(line,'const REORDERED="extends Node3D\\nvar native_properties_revision: int=0\\nvar native_state: Dictionary={}\\nvar native_properties: Dictionary={}\\n"');
const helper=`func reorder_current(writer: GDScript,nodes: Array)->void:
\t# Release Godot does not resize/remap old instance storage on reload(true).
\t# Keep slot count equal and explicitly restore current values by field name.
\tvar saved: Array=[]
\tfor node in nodes:saved.append([node.get("native_properties"),node.get("native_state"),node.get("native_properties_revision")])
\twriter.source_code=REORDERED;check(writer.reload(true)==OK,"Equal-count compiled member order changes")
\tfor index in nodes.size():
\t\tnodes[index].set("native_properties",saved[index][0]);nodes[index].set("native_state",saved[index][1]);nodes[index].set("native_properties_revision",saved[index][2])
\twriter.source_code=SOURCE
`;
once('func quiet_many()->void:',helper+'func quiet_many()->void:');
once('\tg.writer.source_code=REORDERED;check(g.writer.reload(true)==OK,"Compiled member order changes with state preserved")\n\tg.writer.source_code=SOURCE','\treorder_current(g.writer,g.nodes)');
once('\tvar writer: GDScript=g.writer\n\tfinalizer.action=func():','\tvar writer: GDScript=g.writer;var nodes: Array=g.nodes\n\tfinalizer.action=func():');
once('\t\twriter.source_code=REORDERED;check(writer.reload(true)==OK,"Scratch PREDELETE changes current member order")\n\t\twriter.source_code=SOURCE','\t\treorder_current(writer,nodes)');
fs.writeFileSync(output,text,{flag:'wx'});const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');console.log(JSON.stringify({output,sha256:sha(Buffer.from(text)),original,originalSha256:sha(fs.readFileSync(original)),scope:'B-only valid equal-count reordering oracle; failed 3-to-5 release-instance growth fixture remains unchanged.'}));
