// NWN_LIGHT_MEMBER_INDICES_E. Poll-local layout only; never member values.
bool light_member_indices_requested() {
 static const bool enabled=OS::get_singleton() && OS::get_singleton()->get_cmdline_user_args().find("--light-member-read=indices")!=nullptr;
 return enabled;
}
struct LightMemberIndexSegment {
 int values[3]={-1,-1,-1};
 void invalidate() { for(int &value:values)value=-1; }
 ~LightMemberIndexSegment() { invalidate(); }
};
bool light_member_scratch_boundary(const Variant &value) {
 // A nonconst read-only Dictionary read may destroy its prior scratch Object.
 // Inspect only the built-in container header; no child value is borrowed.
 return value.get_type()==Variant::DICTIONARY && VariantInternal::get_dictionary(&value)->is_read_only();
}
