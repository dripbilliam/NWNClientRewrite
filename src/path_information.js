// CPathfindInformation constructor 140293a70; creature attachment/owner
// 14037a5d7..14037a5e2. Local scalar storage, not native pointers or a packet.
// Owned search allocations are kept separately; pathfinding is still pending.
export class PathInformation {
  constructor(ownerId){
    this.raw=new DataView(new ArrayBuffer(0x1e8));this.allocations=new Map();
    const qzero=[0x13c,0x148,0x154,0x15c,0x164,0x180,0x138,0x14,0x1c,0x19c,0x24,
      0x30,0x38,0x40,0x48,0x50,0x58,0x60,0x68,0x70,0x80,0x90,0x98,0xa0,0xa8,0xb0,
      0xc0,0xd0,0xd8,0xe8,0xf0,0xf8,0x100,0x118,0x120,0x108,0x110,0x128,0x190,
      0x1b0,0x170,0x1d0,0x1e0];
    qzero.forEach(offset=>this.raw.setBigUint64(offset,0n,true));
    [0x14c,0,0x88,0xb8,0xe0,0x134,0x140,0x2c,0x1d8].forEach(offset=>this.raw.setUint32(offset,0,true));
    this.raw.setFloat32(4,Math.fround(0.6),true);this.raw.setFloat32(8,Math.fround(0.6),true);
    this.raw.setFloat32(0xc,0.5,true);this.raw.setBigUint64(0x78,1n,true);
    this.raw.setBigUint64(0xc8,0x7f000000n,true);this.raw.setBigUint64(0x144,0x3f800000n,true);
    this.raw.setUint8(0x130,0);this.raw.setUint8(0x1a8,0);
    this.raw.setUint32(0x24,ownerId>>>0,true);
  }
  get field8(){return this.raw.getFloat32(8,true);}
  get field4(){return this.raw.getFloat32(4,true);}
  set field4(value){this.raw.setFloat32(4,value,true);}
  set field8(value){this.raw.setFloat32(8,value,true);}
  get fieldC(){return this.raw.getFloat32(0xc,true);}
  set fieldC(value){this.raw.setFloat32(0xc,value,true);}
  get field24(){return this.raw.getUint32(0x24,true);}
  get field19c(){return this.raw.getUint32(0x19c,true);}
  set field19c(value){this.raw.setUint32(0x19c,value,true);}
  get fieldC8(){return this.raw.getUint32(0xc8,true);}
  get field28(){return this.raw.getUint32(0x28,true);}
  set field28(value){this.raw.setUint32(0x28,value,true);}
  computeGridTolerance(){
    let radius=this.field4;if(Math.fround(.1)<radius&&radius<=Math.fround(.65))radius=Math.fround(.1);
    const divisor=Math.max(Math.fround(.1),radius),value=Math.fround(this.raw.getFloat32(0x58,true)/divisor);
    this.raw.setInt32(0x5c,value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648,true);
  }
  resetInterTile(){
    if(this.allocations.get(0x118))throw new Error('Native path search-node disposal 140294090 is unavailable');
    for(const offset of [0xd0,0xd8,0xe8,0xf0,0x120]){this.allocations.delete(offset);this.raw.setBigUint64(offset,0n,true);}
    this.raw.setInt32(0xcc,0,true);this.raw.setInt32(0xe0,0,true);this.raw.setBigUint64(0xf8,0n,true);this.raw.setInt32(0x100,0,true);
  }
  resetGrid(){
    for(const offset of [0x190,0x1b0,0x170,0x1e0,0x1d0]){this.allocations.delete(offset);this.raw.setBigUint64(offset,0n,true);}
    this.raw.setInt32(0x1d8,0,true);
  }
  resetWaypoints(){
    for(const offset of [0x80,0x90]){this.allocations.delete(offset);this.raw.setBigUint64(offset,0n,true);}
    for(const [offset,size] of [[0x7c,4],[0x138,12],[0x144,12],[0x88,4],[0x98,4],[0x128,4],[0x134,4]])new Uint8Array(this.raw.buffer,offset,size).fill(0);
    this.raw.setFloat32(0x144,1,true);
  }
  // ResetAtEndOfPath 140294430..45b then ResetInterAreaSearchData
  // 140294750..97b. Preserve radius, owner, target and unrelated scalar bytes.
  resetAtEnd(){
    if(this.allocations.get(0x118))throw new Error('Native path search-node disposal 140294090 is unavailable');
    for(const [offset,size] of [[0x19c,4],[0x30,16],[0x44,24],[0x60,20]])new Uint8Array(this.raw.buffer,offset,size).fill(0);
    this.resetInterArea();
  }
  // ResetInterAreaSearchData retains goal/start/range and +19c. This is
  // also called directly by action19 and PlotPath, independently of resetAtEnd.
  resetInterArea(){
    if(this.allocations.get(0x118))throw new Error('Native path search-node disposal 140294090 is unavailable');
    const zero=(offset,size)=>new Uint8Array(this.raw.buffer,offset,size).fill(0);
    [[0x14,8],[0x1c,4],[0xb8,4],
      [0x9c,12],[0x1d8,4],[0x7c,4],[0x88,4],[0x98,4],[0x128,4],[0x134,4],
      [0x138,12],[0x144,12],[0xcc,4],[0xe0,4],[0xf8,12]].forEach(([o,n])=>zero(o,n));
    this.raw.setUint32(0x74,0,true);this.raw.setUint32(0x78,1,true);this.raw.setFloat32(0x144,1,true);
    for(const offset of [0xc0,0xa8,0xb0,0x190,0x1b0,0x170,0x1e0,0x1d0,0x80,0x90,0xd0,0xd8,0xe8,0xf0,0x120]){
      this.allocations.delete(offset);zero(offset,8);
    }
  }
}
