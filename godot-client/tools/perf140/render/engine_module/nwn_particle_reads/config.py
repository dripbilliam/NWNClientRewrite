def can_build(env, platform):
    # This first private ABI is deliberately x64/single-precision only.
    return (not env["disable_3d"] and env["arch"] == "x86_64"
            and env.get("precision", "single") == "single")


def configure(env):
    pass
