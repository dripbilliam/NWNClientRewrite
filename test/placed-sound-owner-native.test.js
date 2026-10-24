import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativePlacedSound,nativeSoundInterval,nativeSoundPitchRate,nativeSoundTileIndex} from '../src/native_placed_sound.js';
import {nativeWaveTiming} from '../src/native_wave_timing.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-placed-sound-owner-observations.json',import.meta.url))),bits=value=>{const b=Buffer.alloc(4);b.writeFloatLE(value);return b.toString('hex');};
function fixture(c){
 const calls=[];let draws=0;const rng=c.random??[17,2,31,127],random=()=>rng[draws++%rng.length],source={configure(){},hardwarePlaying:()=>Boolean(c.playing),setPosition:value=>calls.push({op:'position',value}),setResRef:value=>calls.push({op:'resref',value}),setVolume:value=>calls.push({op:'volume',value}),setPitchVariance:value=>calls.push({op:'pitch',value}),play(){calls.push({op:'play'});return c.duration??250;},stop:()=>calls.push({op:'stop'}),dispose(){}},sound={id:0x80000013,position:[3.25,8.5,Math.fround(1.8)],refs:Array.from({length:c.count??2},(_,i)=>'sound_'+i),fields:{'308':c.active??1,'30c':0,'310':c.loop??0,'314':c.volume??27,'318':c.volumeVariation??0,'31c':c.times??3,'320':Math.fround(.2),'324':c.hours??0,'348':c.interval??1000,'34c':c.variation??0,'350':1,'354':20,'358':c.continuous??1,'35c':c.randomList??0,'32c':c.randomPosition??0,'330':c.rangeX??10,'334':c.rangeY??10}},owner=new NativePlacedSound({sound,source,area:{width:12,height:10,tileHeightAt:()=>2},random});
 Object.assign(owner,{allowed:c.allowed??1,first:Boolean(c.first??1),index:c.index??0,remaining:c.remaining??0,gap:c.gap??0,loopPending:Boolean(c.loopPending??1),lastTime:0});calls.length=0;draws=0;
 return{owner,calls,random,draws:()=>draws};
}
const fields=o=>({'0x178':o.active>>>0,'0x188':o.allowed>>>0,'0x198':Number(o.loopPending),'0x1b8':o.index>>>0,'0x1c4':o.gap>>>0,'0x1c8':o.remaining>>>0,'0x1d4':Number(o.first)});
test('complete original scheduler matches active/time/loop/wait gates, source calls, random volume/position and failure removal',()=>{
 for(const row of oracle.cases.filter(c=>c.kind==='frame')){const c=row.case,h=fixture(c);h.owner.select=()=>c.ref??'stub_ref';h.owner.frame(c.elapsed??0,{hour:6,timeOfDay:1});assert.deepEqual(h.calls,row.calls,JSON.stringify(c));assert.deepEqual(fields(h.owner),row.fields,JSON.stringify(c));assert.deepEqual(h.owner.refs,row.refs,JSON.stringify(c));assert.equal(h.draws(),row.draws,JSON.stringify(c));assert.deepEqual(h.owner.position.map(bits),row.position.map(bits),JSON.stringify(c));}
});
test('complete original time gate retains unknown day/night states and masks custom hour shifts',()=>{
 for(const row of oracle.cases.filter(c=>c.kind==='gate')){const h=fixture(row.case);h.owner.timeGate(row.case);assert.deepEqual(fields(h.owner),row.fields,JSON.stringify(row.case));}
});
test('complete original repeat-interval helper keeps unsigned countdown storage and native random modulo',()=>{
 for(const row of oracle.cases.filter(c=>c.kind==='interval')){const h=fixture(row.case);h.owner.gap=nativeSoundInterval(h.owner.interval,h.owner.intervalVariation,h.random)??h.owner.gap;assert.equal(h.owner.gap,row.fields['0x1c4'],JSON.stringify(row.case));assert.equal(h.draws(),row.draws);}
});
test('original list selection and full random shuffle preserve ordering and reserved end marker',()=>{
 for(const row of oracle.cases.filter(c=>c.kind==='select')){const h=fixture(row.case);assert.equal(h.owner.select(),row.selected,JSON.stringify(row.case));assert.equal(h.owner.index,row.fields['0x1b8']);assert.equal(Number(h.owner.first),row.fields['0x1d4']);assert.deepEqual(h.owner.refs,row.refs,JSON.stringify(row.case));assert.equal(h.draws(),row.draws);}
});
test('complete original source Play matches unpitched duration and asymmetric sample-rate variation',()=>{
 for(const row of oracle.cases.filter(c=>c.kind==='pitch')){const c=row.case;let draws=0;const rng=()=>c.random[draws++%c.random.length];if(c.positional&&c.channels!==1){assert.equal(row.sampleRate,0);assert.equal(row.draws,0);}else{const rate=nativeSoundPitchRate(c.sampleRate,c.variation,rng);assert.equal(rate,row.sampleRate/c.sampleRate,JSON.stringify(c));assert.equal(draws,row.draws,JSON.stringify(c));}assert.equal(row.duration,Math.trunc(c.sampleRate/4)/c.sampleRate*1000>>>0,JSON.stringify(c));}
});
test('sound tile query retains inclusive edges and first-match ownership',()=>{assert.equal(nativeSoundTileIndex([0,0],2,2),0);assert.equal(nativeSoundTileIndex([10,10],2,2),0);assert.equal(nativeSoundTileIndex([10.01,10],2,2),1);assert.equal(nativeSoundTileIndex([20,20],2,2),3);assert.equal(nativeSoundTileIndex([-1,10],2,2),-1);});
test('fractional browser frame times preserve native integer world-clock elapsed time without accumulating truncation drift',()=>{const h=fixture({remaining:10,interval:0});for(let i=1;i<=17;i++)h.owner.frame(i*.6,{hour:6,timeOfDay:1});assert.equal(h.calls.filter(c=>c.op==='play').length,1);assert.equal(h.owner.remaining,250);});
test('original WAV parser and complete Play use raw compressed data length rather than fact or resampled duration',()=>{
 const rows=oracle.cases.filter(c=>c.kind==='wave-play');assert.ok(rows.length>0);
 for(const row of rows){const actual=nativeWaveTiming(Buffer.from(row.hex,'hex'));assert.equal(actual.duration,row.duration,JSON.stringify(row.case));assert.equal(actual.channels,row.case.channels);assert.equal(actual.sampleRate,row.case.sampleRate);assert.equal(actual.bits,row.case.bits);assert.equal(actual.dataBytes,row.case.dataBytes);}
});
