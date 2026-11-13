// Included inside resident. Selection is fixed at successful configure;
// no clocks, channels, parameter values, Nodes, or callback state are cached.
namespace empty_clips {
bool requested=false;
void bind(){
 Name os_name("OS");auto object=global_singleton(os_name.data);if(!object)return;
 EngineVar os;destroy(os.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](os.data,&object);
 auto args=::method(os,"get_cmdline_user_args");
 requested=::method(args,"has",{EngineVar::text("--particle-empty-clips=skip")}).boolean();
 if(::method(args,"has",{EngineVar::text("--particle-empty-clips=legacy")}).boolean())requested=false;
}
}
