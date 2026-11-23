namespace world_motion_batch {
GDExtensionInterfaceVariantIterInit iter_init;
GDExtensionInterfaceVariantIterNext iter_next;
GDExtensionInterfaceVariantIterGet iter_get;

Var lookup(const Var& dictionary, const Var& field, bool* found = nullptr) {
 Var value;
 destroy(value.data);
 GDExtensionBool valid = false;
 get_keyed(dictionary.data, field.data, value.data, &valid);
 if (found) *found = valid != 0;
 return value;
}

int64_t integer(const Var& value, int64_t fallback) {
 if (value.type() == GDEXTENSION_VARIANT_TYPE_INT) return value.integer();
 if (value.type() == GDEXTENSION_VARIANT_TYPE_FLOAT && std::isfinite(value.number()) &&
     value.number() >= -0x1p63 && value.number() < 0x1p63) return static_cast<int64_t>(value.number());
 return fallback;
}

V3 vector(const Var& value) {
 V3 out{};
 to[GDEXTENSION_VARIANT_TYPE_VECTOR3](out.data(), const_cast<uint8_t*>(value.data));
 return out;
}

Var vector_variant(const V3& value) {
 Var out;
 destroy(out.data);
 from[GDEXTENSION_VARIANT_TYPE_VECTOR3](out.data, const_cast<float*>(value.data()));
 return out;
}

float length(const V3& value) {
 const float square = ((value[0] * value[0]) + (value[1] * value[1])) + (value[2] * value[2]);
 return static_cast<float>(std::sqrt(static_cast<double>(square)));
}

V3 unit(const V3& value) {
 const float magnitude = length(value);
 if (!(magnitude > 0)) return {};
 return {value[0] / magnitude, value[1] / magnitude, value[2] / magnitude};
}

V3 horizontal_delta(const V3& target, const V3& point) {
 return {target[0] - point[0], target[1] - point[1], 0};
}

bool path_animation(int64_t animation) {
 switch (animation & 65535) {
  case 2: case 3: case 4: case 78: case 79: case 84: case 85: case 86: case 87: return true;
  default: return false;
 }
}

// Ordered path arithmetic stops before any scene or support callbacks. The
// script owner publishes these inputs, resolves support, and delivers cues.
Var path_step(const Var& row, int64_t dt) {
 try {
  int64_t animation = integer(get(row, "animation"), -1);
  if (!path_animation(animation)) return {};
  auto path = get(row, "path");
  const auto count = size(path);
  int64_t cursor = integer(get(row, "cursor"), -1);
  if (count == 0 || cursor < 0 || cursor >= count) return {};
  const auto origin_value = get(row, "position"), heading_value = get(row, "orientation");
  if (origin_value.type() != GDEXTENSION_VARIANT_TYPE_VECTOR3 ||
      heading_value.type() != GDEXTENSION_VARIANT_TYPE_VECTOR3) return {};
  const auto origin = vector(origin_value), heading = vector(heading_value);
  const auto point_at = [&](int64_t index) {
   const auto value = at(path, index);
   if (value.type() != GDEXTENSION_VARIANT_TYPE_VECTOR3)
    throw std::runtime_error("Invalid world motion path point");
   return vector(value);
  };
  const auto mode = animation & 65535;
  const bool walking = mode == 2 || mode == 3 || mode == 84 || mode == 85;
  const float rate = mode == 78 || mode == 79 ? 1600.0001220703125f :
      static_cast<float>(get(row, walking ? "walkRate" : "runRate").number());
  const bool scripted = get(row, "script").boolean();
  const float quantum = static_cast<float>(static_cast<double>(dt));
  float amount, acceleration = 1.0f;
  if (scripted) {
   const auto factor = static_cast<float>(get(row, "factor").number());
   amount = (quantum * (rate * factor)) / 1000000.0f;
  } else {
   float remaining = 0;
   V3 last = origin;
   for (int64_t index = cursor; index < count; ++index) {
    const auto point = point_at(index);
    remaining += length(horizontal_delta(point, last));
    last = point;
   }
   const float half_second = (rate * 1000.0f) / 2000000.0f;
   float limit = 1.0f;
   if (!(half_second < remaining)) {
    const float ratio = half_second != 0 ? remaining / half_second : 0;
    const float root = ratio < 0.01f ? 0.1f : static_cast<float>(std::sqrt(static_cast<double>(ratio)));
    limit = root - (quantum / 1000.0f);
   }
   const float old = static_cast<float>(get(row, "acceleration").number());
   float next = limit;
   if (old <= 1) {
    next = (quantum / (get(row, "newPath").boolean() ? 500.0f : 1000.0f)) + old;
    if (limit <= next) next = limit;
   }
   acceleration = next < 0.1f ? 0.1f : next;
   amount = (((quantum * rate) * (old + acceleration)) * 0.5f) / 1000000.0f;
  }
  V3 position = origin, direction = heading;
  bool done = false;
  while (cursor < count) {
   const auto point = point_at(cursor), delta = horizontal_delta(point, position);
   const float magnitude = length(delta);
   if (amount <= magnitude) {
    if (magnitude <= 0.01f) position = point;
    else {
     direction = unit(delta);
     for (size_t component = 0; component < 3; ++component)
      position[component] += direction[component] * amount;
    }
    if (cursor == count - 1) {
     const V3 residual = {position[0] - point[0], position[1] - point[1], position[2] - point[2]};
     done = length(residual) <= 0.01f;
    }
    break;
   }
   amount -= magnitude;
   position = point;
   if (magnitude > 0.01f) direction = unit(delta);
   if (cursor == count - 1) {
    done = true;
    break;
   }
   ++cursor;
  }
  if (cursor == count - 1 && !scripted) {
   const float remaining = length(horizontal_delta(point_at(count - 1), origin));
   const float dot = (direction[0] * heading[0]) + (direction[1] * heading[1]);
   if (remaining <= 1 && dot < -0.707f) {
    direction = {-direction[0], -direction[1], -direction[2]};
    animation = 3;
   }
  }
  auto result = Var::dictionary();
  set(result, "cursor", Var::integer(cursor));
  set(result, "animation", Var::integer(animation));
  set(result, "acceleration", Var::number(acceleration));
  set(result, "rate", Var::number(rate));
  set(result, "position", vector_variant(position));
  set(result, "direction", vector_variant(direction));
  set(result, "done", Var::boolean(done));
  return result;
 } catch (const std::exception&) {
  return {};
 }
}

enum Settled { Full, Cardinal, SameBearing, Deadband };

struct MotionFields {
 const Var& active = key("active");
 const Var& correction = key("correction");
 const Var& facing_target = key("facingTarget");
 const Var& old = key("orientation");
 const Var& target = key("targetOrientation");
 const Var& animation = key("animation");
 const Var& visual = key("visualAnimation");
 const Var& cue = key("correctionCue");
 const Var& turn = key("facingTurn");
};

Settled settle(Var& row, const MotionFields& fields, const Var& empty) {
 const auto old_value = lookup(row, fields.old), target_value = lookup(row, fields.target);
 if (old_value.type() != GDEXTENSION_VARIANT_TYPE_VECTOR3 ||
     target_value.type() != GDEXTENSION_VARIANT_TYPE_VECTOR3) return Full;
 const auto old = vector(old_value), target = vector(target_value);
 const bool cardinal = std::isfinite(old[0]) && std::isfinite(old[1]) && std::isfinite(old[2]) &&
     ((std::abs(target[0]) == 1 && target[1] == 0 && old[0] == target[0]) ||
      (std::abs(target[1]) == 1 && target[0] == 0 && old[1] == target[1]));
 Settled branch = Full;
 V3 facing{};
 if (cardinal) {
  branch = Cardinal;
  facing = {target[0], target[1], 0};
 } else {
  const auto desired = unit({target[0], target[1], 0});
  const float dot = ((old[1] * desired[1]) + (old[0] * desired[0])) + (old[2] * desired[2]);
  if (dot == 1) {
   branch = SameBearing;
   facing = unit(desired);
  } else if (dot < 1 && dot >= 0.99f) {
   bool has_visual = false;
   const auto visual = lookup(row, fields.visual, &has_visual);
   const auto animation = integer(has_visual ? visual : lookup(row, fields.animation), -1);
   if (animation == 0 || animation == 1 || animation == 53 || animation == 54) branch = Deadband;
  }
 }
 if (branch != Full) {
  GDExtensionBool valid = false;
  if (branch != Deadband) {
   const auto direction = vector_variant(facing);
   set_keyed(row.data, fields.old.data, direction.data, &valid);
  }
  set_keyed(row.data, fields.cue.data, empty.data, &valid);
  set_keyed(row.data, fields.turn.data, empty.data, &valid);
 }
 return branch;
}

template<class Visit>
bool visit_rows(const Var& objects, const Visit& visit) {
 GDExtensionBool valid = false;
 Var iter;
 destroy(iter.data);
 bool has_row = iter_init(objects.data, iter.data, &valid) != 0;
 while (valid && has_row) {
  Var id;
  destroy(id.data);
  iter_get(objects.data, iter.data, id.data, &valid);
  if (!valid) return false;
  auto row = lookup(objects, id);
  if (!visit(id, row)) return false;
  has_row = iter_next(objects.data, iter.data, &valid) != 0;
 }
 return valid != 0;
}

void advance(void*, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr* arguments,
             GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError* error) {
 if (!particle_upload::count_ok(count, 4, result, error)) return;
 const Var objects(arguments[0]), callback(arguments[1]), profile(arguments[2]);
 const auto dt = Var(arguments[3]).integer();
 const MotionFields fields;
 const Name call("call");
 const Var empty;
 constexpr int64_t invalid_target = 0x7f000000;
 int64_t rows = 0, active_rows = 0, correcting = 0, targeted = 0;
 int64_t settled = 0, cardinal = 0, deadband = 0, full = 0, native_settled = 0, native_paths = 0;
 const bool diagnostics = profile.boolean();
 const bool completed = visit_rows(objects, [&](const Var& id, Var& row) {
  const auto active = lookup(row, fields.active);
  const auto correction = lookup(row, fields.correction);
  const auto target = integer(lookup(row, fields.facing_target), invalid_target);
  const bool is_active = !active.nil() && active.boolean();
  const bool is_correcting = integer(correction, 0) != 0;
  const bool is_targeted = target != invalid_target && target != integer(id, invalid_target);
  auto branch = !is_active && !is_correcting && !is_targeted ? settle(row, fields, empty) : Full;
  if (diagnostics && branch != Full) ++native_settled;
  if (branch == Full) {
   GDExtensionCallError callback_error{};
   const auto native_path = is_active ? path_step(row, dt) : Var();
   if (diagnostics && !native_path.nil()) ++native_paths;
   const GDExtensionConstVariantPtr args[] = {id.data, row.data, native_path.data};
   Var branch_result;
   destroy(branch_result.data);
   variant_call(const_cast<uint8_t*>(callback.data), call.data, args, 3, branch_result.data, &callback_error);
   if (callback_error.error != GDEXTENSION_CALL_OK) return false;
   branch = static_cast<Settled>(integer(branch_result, Full));
  }
  if (diagnostics) {
   ++rows;
   active_rows += is_active;
   correcting += is_correcting;
   targeted += is_targeted;
   settled += branch != Full;
   cardinal += branch == Cardinal;
   deadband += branch == Deadband;
   full += branch == Full;
  }
  return true;
 });
 auto totals = Var::dictionary();
 set(totals, "completed", Var::boolean(completed));
 if (diagnostics) {
  set(totals, "rows", Var::integer(rows));
  set(totals, "active", Var::integer(active_rows));
  set(totals, "correcting", Var::integer(correcting));
  set(totals, "targeted", Var::integer(targeted));
  set(totals, "settled", Var::integer(settled));
  set(totals, "cardinal", Var::integer(cardinal));
  set(totals, "deadband", Var::integer(deadband));
  set(totals, "full", Var::integer(full));
  set(totals, "native_settled", Var::integer(native_settled));
  set(totals, "native_paths", Var::integer(native_paths));
 }
 new_copy(result, totals.data);
}

template<class Property>
void register_methods(Name& owner, const Property& property) {
 Name advance_name("advance_world_motion"), objects("objects"),
     callback("callback"), diagnostics("diagnostics"), quantum("milliseconds"), empty("");
 GDExtensionPropertyInfo args[] = {property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, objects),
     property(GDEXTENSION_VARIANT_TYPE_CALLABLE, callback), property(GDEXTENSION_VARIANT_TYPE_BOOL, diagnostics),
     property(GDEXTENSION_VARIANT_TYPE_INT, quantum)};
 auto returned = property(GDEXTENSION_VARIANT_TYPE_DICTIONARY, empty);
 GDExtensionClassMethodArgumentMetadata metadata[4]{};
 GDExtensionClassMethodInfo method{};
 method.name = advance_name.data;
 method.call_func = advance;
 method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
 method.argument_count = 4;
 method.arguments_info = args;
 method.arguments_metadata = metadata;
 method.has_return_value = true;
 method.return_value_info = &returned;
 register_method(library, owner.data, &method);
}
}
