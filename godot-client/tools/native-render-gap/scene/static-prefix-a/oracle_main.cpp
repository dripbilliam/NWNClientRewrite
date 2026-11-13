#include "coarse_prefix.hpp"
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
struct Reader {
 std::ifstream stream;
 explicit Reader(const char *file):stream(file,std::ios::binary){if(!stream)throw std::runtime_error("input missing");}
 template<class T>T read(){T value{};if(!stream.read(reinterpret_cast<char*>(&value),sizeof(value)))throw std::runtime_error("input truncated");return value;}
};
std::string bits(double value){uint64_t raw;std::memcpy(&raw,&value,8);std::ostringstream text;for(unsigned n=0;n<8;++n)text<<std::hex<<std::setfill('0')<<std::setw(2)<<((raw>>(n*8))&255);return text.str();}
int main(int argc,char **argv){try{
 if(argc!=3)throw std::runtime_error("expected input/output paths");Reader input(argv[1]);if(input.read<uint32_t>()!=0x31505343)throw std::runtime_error("input magic");const auto cases=input.read<uint32_t>();if(cases>100000)throw std::runtime_error("case bound");std::ofstream output(argv[2],std::ios::binary);output<<"{\"version\":1,\"cases\":[";
 for(uint32_t at=0;at<cases;++at){coarse_static_prefix::Query query;for(auto &v:query.from)v=input.read<float>();for(auto &v:query.to)v=input.read<float>();query.radius=input.read<double>();const auto count=input.read<uint32_t>();if(count>10000)throw std::runtime_error("group bound");std::vector<coarse_static_prefix::Group> groups(count);
  for(auto &group:groups){group.empty_bounds=input.read<uint8_t>()!=0;group.model_exists=input.read<uint8_t>()!=0;group.model_empty=input.read<uint8_t>()!=0;group.model_error=input.read<uint8_t>()!=0;for(auto &v:group.bounds)v=input.read<double>();const auto states=input.read<uint32_t>();if(states>10000)throw std::runtime_error("state bound");group.states.resize(states);for(auto &state:group.states){state.pending=input.read<uint8_t>()!=0;state.radius_present=input.read<uint8_t>()!=0;state.radius=input.read<double>();}}
  const auto result=coarse_static_prefix::evaluate(query,groups);if(at)output<<',';output<<"{\"index\":"<<at<<",\"ready\":"<<(result.ready?"true":"false")<<",\"rows\":[";for(std::size_t n=0;n<result.rows.size();++n){const auto &row=result.rows[n];if(n)output<<',';output<<"{\"index\":"<<row.index<<",\"expansion\":\""<<bits(row.expansion)<<"\",\"pending\":"<<(row.pending?"true":"false")<<'}';}output<<"]}";
 }
 if(input.stream.peek()!=std::char_traits<char>::eof())throw std::runtime_error("input tail");output<<"]}\n";if(!output)throw std::runtime_error("output failed");std::cout<<"numeric cases "<<cases<<" completed\n";return 0;
}catch(const std::exception &error){std::cerr<<error.what()<<'\n';return 1;}}
