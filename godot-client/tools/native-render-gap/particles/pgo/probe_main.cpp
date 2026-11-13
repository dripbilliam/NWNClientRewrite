#include <cstdint>
#include <cstdio>
#include <cstdlib>
extern "C" uint64_t evaluate(uint32_t seed,uint32_t mode,uint32_t count);
int main(int argc,char** argv){
 const uint32_t mode=argc>1?static_cast<uint32_t>(std::strtoul(argv[1],nullptr,10)):0;
 const uint32_t count=argc>2?static_cast<uint32_t>(std::strtoul(argv[2],nullptr,10)):20000;
 const uint32_t seed=argc>3?static_cast<uint32_t>(std::strtoul(argv[3],nullptr,10)):12345;
 std::printf("%016llx\n",static_cast<unsigned long long>(evaluate(seed,mode,count)));
 return 0;
}
