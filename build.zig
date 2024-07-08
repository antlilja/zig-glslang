const std = @import("std");

const GenerateHeaderStep = @import("GenerateHeaderStep.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glslang_dep = b.dependency("glslang", .{});
    const glslang_root = glslang_dep.path("");

    const header_gen = GenerateHeaderStep.create(
        b,
        glslang_root,
    );

    const flags = [_][]const u8{
        "-DENABLE_OPT=0",
        "-fno-sanitize=undefined",
    };

    const exe = b.addExecutable(.{
        .name = "glslang",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.linkLibCpp();

    exe.addIncludePath(glslang_root);
    exe.addIncludePath(header_gen.getPath());

    exe.addCSourceFiles(.{
        .root = glslang_root,
        .files = &.{
            "StandAlone/StandAlone.cpp",

            "glslang/MachineIndependent/glslang_tab.cpp",
            "glslang/MachineIndependent/iomapper.cpp",
            "glslang/MachineIndependent/InfoSink.cpp",
            "glslang/MachineIndependent/attribute.cpp",
            "glslang/MachineIndependent/Constant.cpp",
            "glslang/MachineIndependent/IntermTraverse.cpp",
            "glslang/MachineIndependent/Intermediate.cpp",
            "glslang/MachineIndependent/Initialize.cpp",
            "glslang/MachineIndependent/ParseContextBase.cpp",
            "glslang/MachineIndependent/ParseHelper.cpp",
            "glslang/MachineIndependent/PoolAlloc.cpp",
            "glslang/MachineIndependent/RemoveTree.cpp",
            "glslang/MachineIndependent/Scan.cpp",
            "glslang/MachineIndependent/ShaderLang.cpp",
            "glslang/MachineIndependent/SpirvIntrinsics.cpp",
            "glslang/MachineIndependent/SymbolTable.cpp",
            "glslang/MachineIndependent/Versions.cpp",
            "glslang/MachineIndependent/intermOut.cpp",
            "glslang/MachineIndependent/limits.cpp",
            "glslang/MachineIndependent/linkValidate.cpp",
            "glslang/MachineIndependent/parseConst.cpp",
            "glslang/MachineIndependent/reflection.cpp",
            "glslang/MachineIndependent/preprocessor/Pp.cpp",
            "glslang/MachineIndependent/preprocessor/PpAtom.cpp",
            "glslang/MachineIndependent/preprocessor/PpContext.cpp",
            "glslang/MachineIndependent/preprocessor/PpScanner.cpp",
            "glslang/MachineIndependent/preprocessor/PpTokens.cpp",
            "glslang/MachineIndependent/propagateNoContraction.cpp",

            "glslang/GenericCodeGen/CodeGen.cpp",
            "glslang/GenericCodeGen/Link.cpp",

            "glslang/CInterface/glslang_c_interface.cpp",

            "glslang/ResourceLimits/ResourceLimits.cpp",
            "glslang/ResourceLimits/resource_limits_c.cpp",

            "SPIRV/SpvPostProcess.cpp",
            "SPIRV/GlslangToSpv.cpp",
            "SPIRV/Logger.cpp",
            "SPIRV/InReadableOrder.cpp",
            "SPIRV/SpvBuilder.cpp",
            "SPIRV/doc.cpp",
            "SPIRV/SpvTools.cpp",
            "SPIRV/disassemble.cpp",
            "SPIRV/CInterface/spirv_c_interface.cpp",
        },
        .flags = &flags,
    });
    exe.addCSourceFiles(.{
        .root = glslang_root,
        .files = switch (target.result.os.tag) {
            .linux => &.{"glslang/OSDependent/Unix/ossource.cpp"},
            .windows => &.{"glslang/OSDependent/Windows/ossource.cpp"},
            else => unreachable,
        },
        .flags = &flags,
    });

    b.installArtifact(exe);
}
