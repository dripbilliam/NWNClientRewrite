def can_build(env, platform):
    return env.get("vulkan", False) and not env["disable_3d"]


def configure(env):
    pass
