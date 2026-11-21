// Authored local files only. Original observation metadata is a development
// oracle, never a runtime asset/preparation service. No installed assets copied.
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const folder=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-reference-'));
const source=await fs.readFile(new URL('../../backups/animations/native-binary-reference-observations.json',import.meta.url)),original=JSON.parse(source),samples=[];
for(const[index,row]of original.rows.entries()){
 const bytes=Buffer.alloc(2048),node=244;bytes.writeUInt32LE(2036,4);bytes.write('reference_probe',20);bytes.writeUInt32LE(232,84);bytes.writeUInt32LE(1,88);bytes.write('NULL',180);bytes.write('reference_part',node+32);bytes.writeUInt32LE(0x11,node+108);Buffer.from(row.rawModel).copy(bytes,node+112);bytes.writeUInt32LE(row.case.reattachable>>>0,node+176);
 const name='header'+index+'.mdl';await fs.writeFile(path.join(folder,name),bytes,{flag:'wx'});
 // NUL-terminated names are stored as raw bytes. Avoid an embedded-NUL JSON
 // string, which Godot's Unicode string owner cannot represent.
 samples.push({name,sha256:hash(bytes),expectedModel:row.case.name.split('\0')[0],rawModel:row.rawModel,reattachable:row.reattachable,flags:row.flags});
}
const model=(name,nodes)=>`newmodel ${name}\nsetsupermodel ${name} NULL\nbeginmodelgeom ${name}\nnode dummy ${name}\nparent NULL\nendnode\n${nodes}\nendmodelgeom ${name}\n`;
const reference=(name,parent,child,position='0 0 0',scale=1)=>`node reference ${name}\nparent ${parent}\nposition ${position}\nscale ${scale}\nrefmodel ${child}\nreattachable 1\nendnode`;
const geometry=(parent)=>`node trimesh mesh\nparent ${parent}\nbitmap synthetic_texture\nrender 1\nshadow 0\nverts 3\n0 0 0\n0.2 0 0\n0 0 0.4\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode`;
const emitter=`node emitter lightning\nparent beam\nupdate Lightning\nrender Linked\nblend Lighten\ntexture synthetic_texture\nbirthrate 9\nlifeexp 0\nsizestart .15\nsizeend .15\nalphastart 1\nalphaend 1\ncolorstart .4 .7 1\ncolorend 1 1 1\nlightningdelay .01\nlightningradius .3\nlightningscale .75\nxgrid 2\nygrid 2\nframestart 0\nframeend 3\nfps 10\np2p 1\naffectedbywind 1\nbounce 1\nendnode`;
const files={
 'beam.mdl':model('beam',`${emitter}\n${reference('z_first','lightning','endcap','0 4 0',3)}\n${reference('a_second','lightning','endcap','4 0 0')}`),
 'endcap.mdl':model('endcap',`${geometry('endcap')}\n${reference('nested','endcap','leaf','0 0 1')}`),
 'leaf.mdl':model('leaf',geometry('leaf')),
 'cycle_a.mdl':model('cycle_a',reference('to_b','cycle_a','cycle_b')),
 'cycle_b.mdl':model('cycle_b',reference('to_a','cycle_b','cycle_a')),
 'missing.mdl':model('missing',reference('absent','missing','unavailable_model')),
 'invalid.mdl':model('invalid','node reference ref\nparent invalid\nrefmodel leaf\nreattachable nope\nendnode')
};
const identities={};for(const[name,text]of Object.entries(files)){await fs.writeFile(path.join(folder,name),text,{flag:'wx'});identities[name]=hash(text);}
const tga=Buffer.alloc(34);tga[2]=2;tga.writeUInt16LE(2,12);tga.writeUInt16LE(2,14);tga[16]=32;tga[17]=8;Buffer.from([255,255,255,255,255,200,100,255,200,100,50,255,255,255,255,255]).copy(tga,18);await fs.writeFile(path.join(folder,'synthetic_texture.tga'),tga,{flag:'wx'});
const file=path.join(folder,'fixture.json');await fs.writeFile(file,JSON.stringify({folder,originalBinarySha256:original.binarySha256,originalEvidenceSha256:hash(source),samples,identities},null,2),{flag:'wx'});console.log(file);
