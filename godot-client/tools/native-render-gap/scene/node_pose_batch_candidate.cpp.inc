// Private source fragment for Node3D. Root owns application to a fresh shared
// engine stage. Required header additions:
//   private: bool nwn_pose_defer_propagation = false;
//   public: bool nwn_try_set_pose_exact(const Vector3 &, const Quaternion &, const Vector3 &);
// Required P/Q/S setter change (ONLY these3direct setter bodies):
//   if (!nwn_pose_defer_propagation) { _propagate_transform_changed(this); }
// Do not add a flag check on every recursive descendant visit.
// Bind this private capability separately. Returning false performs NO writes;
// NativePoseStorage must run its original3ptrcalls and close checks itself.
bool Node3D::nwn_try_set_pose_exact(const Vector3 &p_position, const Quaternion &p_quaternion, const Vector3 &p_scale) {
	if (!Thread::is_main_thread() || is_group_processing() || Engine::get_singleton()->is_editor_hint() ||
			get_class_name() != Node3D::get_class_static() || get_script_instance() != nullptr ||
			data.notify_local_transform || nwn_pose_defer_propagation ||
			(is_inside_tree() && get_tree()->is_physics_interpolation_enabled())) {
		return false;
	}
	// Reject paths that could produce an error or require cache decomposition
	// while checking eligibility. Malformed/degenerate inputs retain all original
	// setter/error/partial-state boundaries in the native caller.
	if (!p_position.is_finite() || !p_scale.is_finite() || !p_quaternion.is_finite() || !p_quaternion.is_normalized() ||
			_test_dirty_bits(DIRTY_EULER_ROTATION_AND_SCALE) || !data.scale.is_finite() ||
			p_scale.x == 0 || p_scale.y == 0 || p_scale.z == 0 ||
			data.scale.x == 0 || data.scale.y == 0 || data.scale.z == 0) {
		return false;
	}
	struct DeferredPropagation {
		bool &flag;
		explicit DeferredPropagation(bool &p_flag) : flag(p_flag) { flag = true; }
		~DeferredPropagation() { flag = false; }
	};
	{
		DeferredPropagation deferred(nwn_pose_defer_propagation);
		set_position(p_position);
		set_quaternion(p_quaternion);
	}
	set_scale(p_scale);
	return true;
}
