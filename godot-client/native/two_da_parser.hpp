// Worker-local 2DA scanner. Preserve the script decoder's complete public graph
// and row/column identity while eliminating per-cell interpreted scanner loops.
// The original binary's indexed CExoString matrix motivates future compact
// consumers; this compatibility boundary intentionally still returns dictionaries.
struct TableArray {
 Var value=Var::container(GDEXTENSION_VARIANT_TYPE_ARRAY);
 explicit TableArray(size_t count){
  if(count>static_cast<size_t>(INT32_MAX))throw std::runtime_error("2DA array exceeds engine bounds");
  Name resize("resize");auto length=Var::integer(static_cast<int64_t>(count));GDExtensionConstVariantPtr args[]={length.data};Var result;destroy(result.data);GDExtensionCallError error{};variant_call(value.data,resize.data,args,1,result.data,&error);
  if(error.error!=GDEXTENSION_CALL_OK||result.integer()!=0)throw std::runtime_error("2DA array allocation failed");
 }
 void set(size_t index,const Var& item){Raw raw(value.data,GDEXTENSION_VARIANT_TYPE_ARRAY);auto slot=array_mutable(raw.data,static_cast<GDExtensionInt>(index));if(!slot)throw std::runtime_error("2DA array index exceeds bounds");destroy(slot);new_copy(slot,item.data);}
};
struct TableStrings {
 std::unordered_map<std::u32string,Var> values;
 const Var& get(const std::u32string& source){
  auto found=values.find(source);if(found!=values.end())return found->second;
  alignas(8) uint8_t raw[8];string_new32(raw,source.data(),static_cast<GDExtensionInt>(source.size()));Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_STRING](value.data,raw);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);
  return values.emplace(source,std::move(value)).first->second;
 }
};
bool table_space(char32_t c){return c==U' '||c==U'\t'||c==U'\r'||c==U'\n';}
std::vector<std::u32string> table_tokens(std::u32string_view line){
 std::vector<std::u32string> out;size_t index=0;
 while(index<line.size()){
  while(index<line.size()&&table_space(line[index]))++index;if(index==line.size())break;
  std::u32string token;
  if(line[index]==U'"'){
   ++index;while(index<line.size()){
    if(line[index]==U'"'){if(index+1<line.size()&&line[index+1]==U'"'){token.push_back(U'"');index+=2;continue;}++index;break;}
    token.push_back(line[index++]);
   }
  }else{const auto start=index;while(index<line.size()&&!table_space(line[index]))++index;token.assign(line.substr(start,index-start));}
  out.push_back(std::move(token));
 }
 return out;
}
Var parse_two_da(const Var& input){
 if(get_type(input.data)!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("2DA source must be text");
 Raw raw(input.data,GDEXTENSION_VARIANT_TYPE_STRING);const auto length=raw.size();if(length<0)throw std::runtime_error("Invalid 2DA source length");
 std::u32string source;source.reserve(static_cast<size_t>(length));
 if(length){const auto* data=string_at(raw.data,0);for(int64_t i=0;i<length;++i)if(data[i]!=U'\r')source.push_back(data[i]);}
 std::vector<std::u32string_view> lines;const std::u32string_view text(source);size_t start=0;
 while(start<text.size()){
  auto end=text.find(U'\n',start);if(end==std::u32string_view::npos)end=text.size();auto line=text.substr(start,end-start);
  while(!line.empty()&&line.front()<=32)line.remove_prefix(1);while(!line.empty()&&line.back()<=32)line.remove_suffix(1);
  if(!line.empty()&&line.front()!=U';')lines.push_back(line);start=end+1;
 }
 if(lines.empty()||lines[0].substr(0,5)!=U"2DA V")throw std::runtime_error("Unsupported 2DA header");
 size_t cursor=1;std::u32string default_value=U"****";
 if(cursor<lines.size()){
  const auto line=lines[cursor];bool is_default=line.size()>=8;constexpr char32_t prefix[]=U"DEFAULT:";
  for(size_t i=0;i<8&&is_default;++i){auto c=line[i];if(c>=U'a'&&c<=U'z')c-=32;is_default=c==prefix[i];}
  if(is_default){auto tokens=table_tokens(line);if(tokens.size()>1)default_value=tokens[1];++cursor;}
 }
 if(cursor==lines.size())throw std::runtime_error("Missing 2DA columns");
 const auto columns=table_tokens(lines[cursor++]);TableStrings pool;TableArray column_values(columns.size());
 std::vector<Var> column_keys;column_keys.reserve(columns.size());std::vector<bool> first;std::unordered_set<std::u32string> seen;
 for(size_t i=0;i<columns.size();++i){column_keys.emplace_back(pool.get(columns[i]));column_values.set(i,column_keys.back());first.push_back(seen.emplace(columns[i]).second);}
 const auto row_count=lines.size()-cursor;TableArray ordered(row_count),cells(row_count),labels(row_count);auto rows=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);
 const auto fallback=pool.get(default_value);Name valid_int("is_valid_int"),to_int("to_int");
 for(size_t index=0;cursor<lines.size();++cursor,++index){
  const auto tokens=table_tokens(lines[cursor]);if(tokens.empty())throw std::runtime_error("Invalid empty 2DA row");
  auto row=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);TableArray physical(columns.size());
  for(size_t i=0;i<columns.size();++i){const auto& value=i+1<tokens.size()?pool.get(tokens[i+1]):fallback;physical.set(i,value);if(first[i])put(row,column_keys[i],value);}
  auto label=pool.get(tokens[0]);ordered.set(index,row);cells.set(index,physical.value);labels.set(index,label);
  Var valid;destroy(valid.data);GDExtensionCallError error{};variant_call(label.data,valid_int.data,nullptr,0,valid.data,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("2DA row validation failed");
  GDExtensionBool numeric=false;to[GDEXTENSION_VARIANT_TYPE_BOOL](&numeric,valid.data);
  if(numeric){Var number;destroy(number.data);variant_call(label.data,to_int.data,nullptr,0,number.data,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("2DA row conversion failed");put(rows,number,row);}
 }
 auto result=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(result,Var::text("defaultValue"),fallback);put(result,Var::text("columns"),column_values.value);put(result,Var::text("rows"),rows);put(result,Var::text("orderedRows"),ordered.value);put(result,Var::text("orderedCells"),cells.value);put(result,Var::text("rowLabels"),labels.value);return result;
}
void call_two_da(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=1){error->error=count<1?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=1;new_nil(result);return;}
 try{Var input(args[0]);auto out=parse_two_da(input);new_copy(result,out.data);}catch(const std::exception& failure){auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,Var::text("error"),Var::text(failure.what()));new_copy(result,out.data);}
}
