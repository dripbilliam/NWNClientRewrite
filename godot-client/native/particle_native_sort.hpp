// Original particle sort semantics, derived from the SHA-checked instruction
// bodies 1400c0580/1400bfa90/1400bf590/1400bfeb0. Its tie comparator is not a
// strict weak ordering across unrelated sources. Do not pass it to std::sort.
// Explicit bounded index operations preserve the native swaps without relying
// on a standard library's comparator preconditions or partition sentinels.
namespace particle_native_sort {
struct Stats {int64_t partitions=0,medians=0,insertion=0,heaps=0;};
template<class Value,class Less>struct Sort {
 std::vector<Value>& values;Less less;Stats stats;
 Value& at(size_t index){if(index>=values.size())throw std::runtime_error("Native particle sort index outside admitted list");return values[index];}
 void swap(size_t a,size_t b){std::swap(at(a),at(b));}
 void median(size_t first,size_t middle,size_t last){
  ++stats.medians;if(less(at(middle),at(first)))swap(middle,first);
  if(less(at(last),at(middle))){swap(last,middle);if(less(at(middle),at(first)))swap(middle,first);}
 }
 std::pair<size_t,size_t> partition(size_t first,size_t last){
  ++stats.partitions;const auto count=last-first,middle=first+count/2;
  // The original tests (count-1)>40 before its nine-element median guess.
  if(count>41){const auto step=count/8;median(first,first+step,first+2*step);median(middle-step,middle,middle+step);median(last-1-2*step,last-1-step,last-1);median(first+step,middle,last-1-step);}
  else median(first,middle,last-1);
  auto low=middle,high=middle+1;
  while(first<low&&!less(at(low-1),at(low))&&!less(at(low),at(low-1)))--low;
  while(high<last&&!less(at(high),at(low))&&!less(at(low),at(high)))++high;
  auto right=high,left=low;
  for(;;){
   for(;right<last;++right){if(less(at(low),at(right)))continue;if(less(at(right),at(low)))break;if(high!=right)swap(high,right);++high;}
   for(;first<left;--left){if(less(at(left-1),at(low)))continue;if(less(at(low),at(left-1)))break;--low;if(low!=left-1)swap(low,left-1);}
   if(left==first&&right==last)return {low,high};
   if(left==first){if(high!=right)swap(low,high);++high;swap(low,right);++low;++right;}
   else if(right==last){--left;--low;if(left!=low)swap(left,low);--high;swap(low,high);}
   else{--left;swap(right,left);++right;}
  }
 }
 void insert(size_t first,size_t last){
  ++stats.insertion;if(last-first<2)return;
  for(auto next=first+1;next<last;++next){const auto value=at(next);
   if(less(value,at(first))){for(auto hole=next;hole>first;--hole)at(hole)=at(hole-1);at(first)=value;}
   else{auto hole=next;while(hole>first&&less(value,at(hole-1))){at(hole)=at(hole-1);--hole;}at(hole)=value;}
  }
 }
 void hole(size_t first,size_t top,size_t count,Value value){
  auto index=top;const auto last_parent=(count-1)/2;
  while(index<last_parent){auto child=index*2+2;if(less(at(first+child),at(first+child-1)))--child;at(first+index)=at(first+child);index=child;}
  if(index==last_parent&&count%2==0){at(first+index)=at(first+count-1);index=count-1;}
  while(top<index){const auto parent=(index-1)/2;if(!less(at(first+parent),value))break;at(first+index)=at(first+parent);index=parent;}at(first+index)=value;
 }
 void heap(size_t first,size_t last){
  ++stats.heaps;const auto count=last-first;for(auto parent=count/2;parent>0;){--parent;hole(first,parent,count,at(first+parent));}
  for(auto end=count;end>1;){--end;const auto value=at(first+end);at(first+end)=at(first);hole(first,0,end,value);}
 }
 void run(size_t first,size_t last,int64_t budget){
  while(last-first>32){if(budget<1){heap(first,last);return;}const auto cut=partition(first,last);budget=(budget>>1)+(budget>>2);
   if(cut.first-first<last-cut.second){run(first,cut.first,budget);first=cut.second;}
   else{run(cut.second,last,budget);last=cut.first;}
  }insert(first,last);
 }
};
template<class Value,class Less>Stats sort(std::vector<Value>& values,Less less,int64_t budget=-1){Sort<Value,Less> operation{values,less,{}};operation.run(0,values.size(),budget<0?static_cast<int64_t>(values.size()):budget);return operation.stats;}
} // namespace particle_native_sort
