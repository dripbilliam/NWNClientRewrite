 if(light_dictionary_single_requested() && input.get_type()==Variant::DICTIONARY){
  const Dictionary dictionary=input;
  const bool read_only=dictionary.is_read_only(),typed_key=dictionary.is_typed_key();
  if(!read_only && !typed_key){
   ++light_dictionary_read_stats.reads;
   const Variant *found=dictionary.getptr(key);
   if(!found){++light_dictionary_read_stats.missing;out=fallback;return true;}
   // Retain the original Variant copy/refcount hooks. No borrowed value or
   // source pointer is used after this copy; numeric/bool/error rules stay old.
   Variant value=*found;
   if(value.get_type()==Variant::BOOL){out=bool(value)?1.0:0.0;return true;}
   return numeric(value,out,error);
  }
  // has() and getptr() use different typed-key validation diagnostics. Also,
  // old nonconst operator[] writes read-only scratch (possibly destroying a
  // RefCounted). Preserve both old paths after this local Dictionary expires.
  if(read_only)++light_dictionary_read_stats.read_only_fallbacks;
  if(typed_key)++light_dictionary_read_stats.typed_key_fallbacks;
 }
