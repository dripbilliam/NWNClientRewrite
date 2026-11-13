// NWN_LIGHT_DICTIONARY_SINGLE_READ_A. Main-thread polling only; no values cached.
struct LightDictionaryReadStats {
 uint64_t reads=0,missing=0,read_only_fallbacks=0,typed_key_fallbacks=0;
};
thread_local LightDictionaryReadStats light_dictionary_read_stats;
bool light_dictionary_single_requested() {
 static const bool enabled=OS::get_singleton() && OS::get_singleton()->get_cmdline_user_args().find("--light-dictionary-read=single")!=nullptr;
 return enabled;
}
