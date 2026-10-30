import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {readNetworkNui,writeNuiJson} from '../src/network_nui.js';
const root=fileURLToPath(new URL('../',import.meta.url));
const python=process.env.NWN_WIKI_PYTHON??(process.platform==='win32'?path.join(process.env.LOCALAPPDATA,'Programs/Python/Python312/python.exe'):'python3');
const code=String.raw`
import sys,json,base64
sys.path.insert(0,'scripts')
from wiki_nui_data import *
articles=load_export('wikiexport2.xml'); r=WikiReader(articles)
assert len(articles)==66
forest=next(a for a in articles if a.title=='Forest Gnome')
details=next(t for h,t in forest.sections if h=='Details')
assert 'Strength: -2' in details and 'Dexterity: 0' in details
assert 'Skill Affinity: Concentration' in details and '{{' not in details
cloud=next(a for a in articles if a.title=='Cloud Half-Giant')
assert 'Half-Giants share no traditions' in '\n'.join(t for h,t in cloud.sections)
assert all(len(t)<=MAX_SECTION_CHARS for a in articles for h,t in a.sections)
assert any('[Illustration:' in t for a in articles for h,t in a.sections)
r.click('contents'); assert r.contents
r.click('section_1'); assert not r.contents and r.section==1
r.click('article_0'); assert r.article==0
r.click('back'); assert r.article==r.by_title['forest gnome'] and r.section==1
print(json.dumps({'articles':len(articles),'sections':sum(len(a.sections) for a in articles),'packets':[{'mode':mode,'create':r.create(mode).hex(),'update':r.update(mode).hex(),'destroy':r.destroy(mode).hex()} for mode in [0,1,2]]}))
`;
const fixtures=JSON.parse(execFileSync(python,['-c',code],{cwd:root,encoding:'utf8',maxBuffer:2*1024*1024}));
const context={Uint8Array,DataView};vm.createContext(context);vm.runInContext(fs.readFileSync(new URL('../scripts/wiki-nui-agent.js',import.meta.url),'utf8'),context);
const filter=context.WikiNuiWire.filterWikiNuiPacket,localToken=0x6e770001;
function read(bytes,mode,minor){const r=new NativeMessageReader(mode);assert.equal(r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1),1);const value=readNetworkNui(r,minor);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);return value;}

test('real export preserves race stats, transclusion and bounded article sections',()=>{assert.equal(fixtures.articles,66);assert.ok(fixtures.sections>600);});
test('Python-generated create/update/destroy packets decode with the existing native codec in all format modes',()=>{
 for(const f of fixtures.packets){
  const create=read(Buffer.from(f.create,'hex'),f.mode,1);assert.equal(create.token,localToken);assert.equal(create.layout.title,'Arelith Wiki - local stock NUI experiment');
  assert.equal(create.layout.root.children[1].children[0].children[0].children.length,66);
  const update=read(Buffer.from(f.update,'hex'),f.mode,5);assert.equal(update.element,'wiki_content');assert.ok(update.layout.children.at(-1).value.includes('Strength: -2'));
  assert.equal(read(Buffer.from(f.destroy,'hex'),f.mode,2).token,localToken);
 }
});
function outputPacket(mode,minor,tokens,indexed=true){
 const w=new NativeMessageWriter(mode);w.create(64,0xffffffff,1);w.writeInt(tokens.length);
 for(const token of tokens){w.writeInt(token);w.writeStringBytes(new TextEncoder().encode(minor===3?'click':'somebind'));if(minor===3){w.writeStringBytes(new TextEncoder().encode('button'));w.writeInt(-1);writeNuiJson(w,null);}else{writeNuiJson(w,'unchanged remote value');if(indexed)w.writeInt(7);}}
 w.setPrefix(Uint8Array.of(80,55,minor));return Uint8Array.from(w.getWriteMessage().data);
}
test('output containment removes only local records, preserving mixed real server events and bindings byte-for-byte',()=>{
 for(const mode of [0,1,2])for(const minor of [3,4])for(const indexed of [true,false]){
  const mixed=outputPacket(mode,minor,[17,localToken,23,localToken],indexed),result=filter(mixed,mode,minor,localToken,indexed);
  assert.equal(result.removed,2);assert.deepEqual(result.bytes,outputPacket(mode,minor,[17,23],indexed));
  assert.equal(filter(outputPacket(mode,minor,[localToken],indexed),mode,minor,localToken,indexed).bytes,null);
  const real=outputPacket(mode,minor,[17,23],indexed);assert.equal(filter(real,mode,minor,localToken,indexed).bytes,real);
 }
});
test('malformed output is rejected before any forwarding',()=>{
 assert.throws(()=>filter(Uint8Array.of(1),1,3,localToken),/Truncated/);
 const broken=outputPacket(1,3,[localToken]);new DataView(broken.buffer).setUint32(3,0xffffffff,true);
 assert.throws(()=>filter(broken,1,3,localToken),/boundary/);
});
