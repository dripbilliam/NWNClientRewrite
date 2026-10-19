/* Private binary IPC helper. Session/static secret keys never leave this process.
 * Cryptographic operations use the pinned, unmodified ISC libhydrogen source.
 * This helper does not inject into or load the original game executable.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <io.h>
#include <windows.h>
#include "hydrogen.h"

static uint32_t read32(const uint8_t *p) {
    return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24;
}
static int reply(uint8_t status, const uint8_t *data, uint32_t length) {
    uint32_t size = length + 1;
    uint8_t header[5] = {(uint8_t)size,(uint8_t)(size>>8),(uint8_t)(size>>16),(uint8_t)(size>>24),status};
    if (fwrite(header,1,5,stdout)!=5 || (length && fwrite(data,1,length,stdout)!=length)) return -1;
    return fflush(stdout);
}
int main(void) {
    hydro_kx_keypair identity;
    hydro_kx_state state;
    hydro_kx_session_keypair keys;
    uint8_t input[65536], output[65536], header[4];
    const char session_context[hydro_secretbox_CONTEXTBYTES]={'p','l','a','y','e','r',0,0};
    int stage=0, result=0;
    DWORD application_id=GetTickCount(); /* CAppManager constructor14003d280 */
    _setmode(_fileno(stdin),_O_BINARY);
    _setmode(_fileno(stdout),_O_BINARY);
    memset(&state,0,sizeof state);memset(&keys,0,sizeof keys);
    if (hydro_init()!=0) return 2;
    hydro_kx_keygen(&identity);
    for (;;) {
        size_t count=fread(header,1,4,stdin);
        uint32_t length;
        if (!count) break;
        if (count!=4) {result=3;break;}
        length=read32(header);
        if (length<1 || length>sizeof input || fread(input,1,length,stdin)!=length) {result=3;break;}
        if (input[0]==1 && length==1 && stage==0) {
            if (hydro_kx_xx_1(&state,output,NULL)==0) {stage=1;if(reply(0,output,32))break;}
            else if(reply(2,NULL,0))break;
        } else if (input[0]==2 && length==81 && stage==1) {
            if (hydro_kx_xx_3(&state,&keys,output,output+48,input+1,NULL,&identity)==0) {
                stage=3;if(reply(0,output,80))break;
            } else {
                hydro_memzero(&state,sizeof state);hydro_memzero(&keys,sizeof keys);stage=0;
                if(reply(2,NULL,0))break;
            }
        } else if (input[0]==3 && length==1) {
            hydro_memzero(&state,sizeof state);hydro_memzero(&keys,sizeof keys);stage=0;
            if(reply(0,NULL,0))break;
        } else if (input[0]==4 && length==34) {
            const char context[hydro_secretbox_CONTEXTBYTES]={'p','s','i','d',0,0,0,0};
            /* CConnectionLib::GetPlatformSpecificIdentifier: empty payload,
             * message ID=platform byte, build-specific shared validation key. */
            if(hydro_secretbox_encrypt(output,"",0,input[1],context,input+2)==0) {
                if(reply(0,output,hydro_secretbox_HEADERBYTES))break;
            } else if(reply(2,NULL,0))break;
        } else if (input[0]==5 && stage==3 && length<=65467) {
            if(hydro_secretbox_encrypt(output,input+1,length-1,0,session_context,keys.tx)==0) {
                if(reply(0,output,length-1+hydro_secretbox_HEADERBYTES))break;
            } else if(reply(2,NULL,0))break;
        } else if (input[0]==6 && stage==3 && length>=1+hydro_secretbox_HEADERBYTES) {
            if(hydro_secretbox_decrypt(output,input+1,length-1,0,session_context,keys.rx)==0) {
                if(reply(0,output,length-1-hydro_secretbox_HEADERBYTES))break;
            } else if(reply(2,NULL,0))break;
        } else if (input[0]==7 && length==1) {
            output[0]=(uint8_t)application_id;output[1]=(uint8_t)(application_id>>8);
            output[2]=(uint8_t)(application_id>>16);output[3]=(uint8_t)(application_id>>24);
            if(reply(0,output,4))break;
        } else if(reply(1,NULL,0))break;
        hydro_memzero(input,sizeof input);hydro_memzero(output,sizeof output);
    }
    hydro_memzero(&identity,sizeof identity);hydro_memzero(&state,sizeof state);
    hydro_memzero(&keys,sizeof keys);hydro_memzero(input,sizeof input);hydro_memzero(output,sizeof output);
    return result;
}
