#include <cstdint>
#ifndef PROOF_EXTRA_BRANCH
#define PROOF_EXTRA_BRANCH 0
#endif
__attribute__((noinline)) static uint64_t cold_only(uint64_t value){return (value^0xa0761d6478bd642fULL)*0xe7037ed1a0b428dbULL;}
__attribute__((noinline)) static uint64_t mix(uint32_t value,uint32_t mode){
 const uint32_t selected=mode==0?((value&63U)?0U:(value&7U)):(value&7U);
 uint64_t result=value;
 switch(selected){
  case 0:result=(result*0x9e3779b185ebca87ULL)^0x243f6a8885a308d3ULL;break;
  case 1:result=(result<<17)^0x13198a2e03707344ULL;break;
  case 2:result=(result*33U)+(result>>3);break;
  case 3:result^=result<<29;break;
  case 4:result=(result>>7)*0xbf58476d1ce4e5b9ULL;break;
  case 5:result=~result+0x94d049bb133111ebULL;break;
  case 6:result=(result<<31)|(result>>1);break;
  default:result^=0xd1b54a32d192ed03ULL;break;
 }
#if PROOF_EXTRA_BRANCH
 if(value&256U)result^=0xdeadbeefU;
#endif
 return result;
}
extern "C" uint64_t evaluate(uint32_t seed,uint32_t mode,uint32_t count){
 uint64_t result=0xcbf29ce484222325ULL;
 for(uint32_t n=0;n<count;++n){seed=seed*1664525U+1013904223U;result=(result^mix(seed,mode))*0x100000001b3ULL;}
 return mode==9?cold_only(result):result;
}
