'use strict';
// CDB command text only. Exact private-loopback sockaddr matching, no payloads.
function creationSocketTrace(port){
 if(!Number.isInteger(port)||port<1024||port>65535)throw Error('Explicit private IPC port required');
 const wirePort=((port&255)<<8)|(port>>>8),cap=32;
 const stop=`.if (@$t0>=0n${cap}) { .echo NATIVE_IPC_TRACE_CAP; bd6 7 8 9; }`;
 const matched=`r @$t1=@rcx; r @$t2=1; r @$t0=@$t0+1; .printf \\"NATIVE_IPC_TRACE CONNECT seq=%u socket=%p\\", @$t0, @rcx; .echo; .time; ${stop}`;
 const ipv4=`.if (dwo(@rdx+4)==0x0100007f) { ${matched} }`;
 const mapped=`.if (qwo(@rdx+8)==0) { .if (dwo(@rdx+16)==0xffff0000) { .if (dwo(@rdx+20)==0x0100007f) { ${matched} } } }`;
 const connect=`.if (wo(@rdx+2)==0x${wirePort.toString(16)}) { .if (wo(@rdx)==2) { ${ipv4} } .elsif (wo(@rdx)==0x17) { ${mapped} } }; gc`;
 const close=kind=>`.if (@$t2==1) { .if (@rcx==@$t1) { r @$t0=@$t0+1; .printf \\"NATIVE_IPC_TRACE ${kind} seq=%u socket=%p\\", @$t0, @rcx; .echo; .time; k0n12; ${kind==='CLOSE'?'r @$t2=0; ':''}${stop} } }; gc`;
 return {port,cap,breakpointIds:[6,7,8,9],commands:['r @$t0=0','r @$t1=0','r @$t2=0',`bu6 ws2_32!connect "${connect}"`,`bu7 ws2_32!WSAConnect "${connect}"`,`bu8 ws2_32!closesocket "${close('CLOSE')}"`,`bu9 ws2_32!shutdown "${close('SHUTDOWN')}"`],scope:'Only exact127.0.0.1 private port, IPv4 or IPv4-mapped IPv6. Matched handle only; timestamps/12-frame close stacks,32 events then trace-only breakpoint disable. No select/ioctl/recv breakpoints or payload reads.'};
}
module.exports={creationSocketTrace};
