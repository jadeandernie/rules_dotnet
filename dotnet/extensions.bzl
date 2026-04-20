"extensions for bzlmod"

load(":repositories.bzl", "dotnet_register_toolchains")

_DEFAULT_NAME = "dotnet"

_ATTRS = {
    "name": attr.string(
        doc = "Base name for generated repositories",
        default = _DEFAULT_NAME,
    ),
    "dotnet_version": attr.string(
        doc = "Version of the .Net SDK",
    ),
    "coverage_tool": attr.label(
        doc = """Optional label for a coverlet.console-compatible DLL.

When set, `bazel coverage` will route csharp_test/fsharp_test through
`dotnet exec <coverage_tool>` to produce LCOV output. The label is resolved
against the calling module's repo mapping, so user repos referenced via
`use_repo` are valid (e.g. `@coverlet_console//:coverlet_dll`). See the
`coverage_tool` attribute on `dotnet_toolchain` for the runtime contract.""",
    ),
}

def _toolchain_extension(module_ctx):
    registrations = {}
    coverage_tools = {}
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            if toolchain.name in registrations.keys():
                if toolchain.name == _DEFAULT_NAME:
                    # Prioritize the root-most registration of the default dotnet toolchain version and
                    # ignore any further registrations (modules are processed breadth-first)
                    continue
                if toolchain.dotnet_version == registrations[toolchain.name]:
                    # No problem to register a matching toolchain twice
                    continue
                fail("Multiple conflicting toolchains declared for name {} ({} and {})".format(
                    toolchain.name,
                    toolchain.dotnet_version,
                    registrations[toolchain.name],
                ))
            else:
                registrations[toolchain.name] = toolchain.dotnet_version

                # `attr.label` already resolves against the calling module's
                # repo mapping, so the canonical "@@repo+//pkg:tgt" string we
                # get from str(Label) is safe to embed in any other repo's
                # BUILD file (in particular the dotnet SDK toolchain repo).
                coverage_tools[toolchain.name] = str(toolchain.coverage_tool) if toolchain.coverage_tool else ""
    for name, dotnet_version in registrations.items():
        dotnet_register_toolchains(
            name = name,
            dotnet_version = dotnet_version,
            coverage_tool = coverage_tools.get(name, ""),
            register = False,
        )

dotnet = module_extension(
    implementation = _toolchain_extension,
    tag_classes = {
        "toolchain": tag_class(attrs = _ATTRS),
    },
)
