namespace visual_clock_batch {
constexpr uint64_t word_mask = 0xffffffffu;

uint32_t word(const Var& value) {
 if (value.type() == GDEXTENSION_VARIANT_TYPE_INT)
  return static_cast<uint32_t>(static_cast<uint64_t>(value.integer()) & word_mask);
 const auto number = value.number();
 if (!std::isfinite(number) || number < -0x1p63 || number >= 0x1p63)
  throw std::runtime_error("Invalid effect timer value");
 return static_cast<uint32_t>(static_cast<uint64_t>(static_cast<int64_t>(number)) & word_mask);
}

bool enabled(const Var& value) {
 return !value.nil() && value.boolean();
}

void write_timer(Var& slots, int64_t index, const Var& value) {
 GDExtensionBool valid = false, out_of_bounds = false;
 set_indexed(slots.data, index, value.data, &valid, &out_of_bounds);
}

bool render_available(Var& target, const Var& identity) {
 const Name call("call");
 const GDExtensionConstVariantPtr arguments[] = {identity.data};
 GDExtensionCallError error{};
 Var result;
 destroy(result.data);
 variant_call(target.data, call.data, arguments, 1, result.data, &error);
 if (error.error != GDEXTENSION_CALL_OK || result.type() != GDEXTENSION_VARIANT_TYPE_BOOL)
  throw std::runtime_error("Invalid bound-effect host query");
 return result.boolean();
}

// A phase can be stepped as pure timers when no program, sound, or model
// callback can occur. Callback-capable phases take the ordinary ordered path
// before this function has mutated any state.
Var advance_quiet(Var& state, double delta, double elapsed, double previous, Var& target) {
 const double updated = elapsed + delta * 1000.0;
 if (!std::isfinite(updated) || !std::isfinite(previous)) return {};
 const double now = std::floor(updated);
 const double difference = std::fmod(now - previous, 4294967296.0);
 if (!std::isfinite(difference) || difference < 0.0) return {};
 const auto step = static_cast<uint32_t>(difference);

 if (!get(state, "sound118").nil()) return {};
 const auto phase = word(get(state, "programPhaseFa")) & 255u;
 const bool timed_program = phase == 1 || phase == 3;
 const auto program = timed_program ? word(get(state, "programRemainingCc")) : 0u;
 if ((timed_program && program <= step) ||
     ((timed_program || phase == 2) && enabled(get(state, "updateProgramD8")) &&
      enabled(get(state, "attached114")))) return {};

 auto model_timers = get(state, "modelRemaining5c");
 std::array<uint32_t, 3> model_remaining{};
 for (int64_t index = 0; index < 3; ++index) {
  const auto remaining = word(at(model_timers, index));
  if (remaining != 0 && remaining <= step) return {};
  model_remaining[static_cast<size_t>(index)] = remaining;
 }

 const bool retiring = enabled(get(state, "retiringE8"));
 Var retirement, retired;
 std::array<bool, 3> pending{};
 std::array<uint32_t, 3> retire_remaining{};
 if (retiring) {
  retirement = get(state, "retireRemainingC0");
  retired = get(state, "retiredDc");
  for (int64_t index = 0; index < 3; ++index) {
   const auto slot = static_cast<size_t>(index);
   pending[slot] = !enabled(at(retired, index));
   if (pending[slot]) retire_remaining[slot] = word(at(retirement, index));
  }
 }
 if (!render_available(target, get(state, "target54"))) return Var::number(updated);

 if (timed_program) set(state, "programRemainingCc", Var::integer(program - step));
 bool active_model = false;
 for (int64_t index = 0; index < 3; ++index) {
  const auto slot = static_cast<size_t>(index);
  if (model_remaining[slot] != 0) {
   active_model = true;
   write_timer(model_timers, index, Var::integer(model_remaining[slot] - step));
  }
  if (pending[slot]) {
   if (retire_remaining[slot] <= step) write_timer(retired, index, Var::integer(1));
   else write_timer(retirement, index, Var::integer(retire_remaining[slot] - step));
  }
 }
 if (active_model) set(state, "finishedF4", Var::integer(0));
 return Var::number(updated);
}

void dispatch(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* arguments,
              GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
 if (!particle_upload::count_ok(count, 5, result, error)) return;
 try {
  Var state(arguments[0]), target(arguments[4]);
  const auto output = advance_quiet(state, Var(arguments[1]).number(), Var(arguments[2]).number(),
      Var(arguments[3]).number(), target);
  new_copy(result, output.data);
 } catch (const std::exception&) {
  // Unknown state and a failed host query leave the original phase in charge.
  new_nil(result);
 }
}

// The native area runtime supplies a fresh snapshot from its clock provider.
// Return 2 when any callback can occur so the phase owner resumes immediately
// after the original clock writes. It can still observe every callback change.
int advance_area(Var& state, const Var& now) {
 const auto since = get(state, "since");
 uint32_t elapsed = word(get(now, "time")) - word(get(since, "time"));
 const auto day_length = word(get(now, "length"));
 if (!day_length) return 0;
 if (elapsed >= day_length) elapsed += day_length;
 const bool sound = !get(state, "sound170").nil();
 const auto remaining = sound ? 0u : word(get(state, "remaining17c"));
 const bool retiring = !sound && enabled(get(state, "retiring188"));
 const auto retirement = retiring ? word(get(state, "retire178")) : 0u;
 set(state, "elapsed58", Var::integer(elapsed));
 set(state, "since", now);
 if (sound || (remaining && elapsed >= remaining) || (retiring && elapsed >= retirement)) return 2;
 if (remaining) set(state, "remaining17c", Var::integer(remaining - elapsed));
 if (retiring) set(state, "retire178", Var::integer(retirement - elapsed));
 return 1;
}

void dispatch_area(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* arguments,
                   GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
 if (!particle_upload::count_ok(count, 2, result, error)) return;
 int handled = 0;
 try {
  Var state(arguments[0]);
  handled = advance_area(state, Var(arguments[1]));
 } catch (const std::exception&) {
  // The normal phase still receives the already-sampled clock.
 }
 const auto output = Var::integer(handled);
 new_copy(result, output.data);
}

template<class Property>
void register_method_info(Name& owner, const Property& property) {
 Name name("advance_quiet_visual_clock"), state("state"), delta("delta"), elapsed("elapsed"),
     previous("previous"), host("host_available"), empty("");
 auto returned = property(GDEXTENSION_VARIANT_TYPE_NIL, empty);
 returned.usage |= 131072;
 GDExtensionPropertyInfo args[] = {property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, state),
     property(GDEXTENSION_VARIANT_TYPE_FLOAT, delta), property(GDEXTENSION_VARIANT_TYPE_FLOAT, elapsed),
     property(GDEXTENSION_VARIANT_TYPE_FLOAT, previous), property(GDEXTENSION_VARIANT_TYPE_CALLABLE, host)};
 GDExtensionClassMethodArgumentMetadata metadata[5]{};
 GDExtensionClassMethodInfo method{};
 method.name = name.data;
 method.call_func = dispatch;
 method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
 method.argument_count = 5;
 method.arguments_info = args;
 method.arguments_metadata = metadata;
 method.has_return_value = true;
 method.return_value_info = &returned;
 register_method(library, owner.data, &method);

 Name area("advance_area_visual_clock"), now("now");
 args[1] = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, now);
 returned = property(GDEXTENSION_VARIANT_TYPE_INT, empty);
 method.name = area.data;
 method.call_func = dispatch_area;
 method.argument_count = 2;
 register_method(library, owner.data, &method);
}
}
