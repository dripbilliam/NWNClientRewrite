'use strict';
const fs=require('node:fs'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'prepare.cjs'),'utf8');
const next=source.replace('scene/static-prefix-core-a','scene/static-prefix-core-b').replace("fs.writeFileSync(path.join(out,'project/oracle.gd'),gd);","fs.writeFileSync(path.join(out,'project/oracle.gd'),gd.replace(/\\t/g,' '));fs.mkdirSync(path.join(out,'project/.godot'),{recursive:true});fs.writeFileSync(path.join(out,'project/.godot/global_script_class_cache.cfg'),'list=[]\\n');").replace("'oracle_main.cpp','prepare.cjs'","'oracle_main.cpp','prepare-b.cjs'");
if(next===source)throw Error('transform failed');fs.writeFileSync(path.join(__dirname,'prepare-b.cjs'),next,{flag:'wx'});
