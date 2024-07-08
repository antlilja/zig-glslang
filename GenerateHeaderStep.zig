const std = @import("std");
const Build = std.Build;

const GenerateHeaderStep = @This();

step: Build.Step,

glslang_root: Build.LazyPath,

generated_dir: Build.GeneratedFile,

pub fn create(
    builder: *Build,
    glslang_root: Build.LazyPath,
) *GenerateHeaderStep {
    const self = builder.allocator.create(GenerateHeaderStep) catch unreachable;
    self.* = .{
        .step = Build.Step.init(.{
            .id = .custom,
            .name = "intrinsic_header",
            .owner = builder,
            .makeFn = make,
        }),
        .glslang_root = glslang_root,
        .generated_dir = undefined,
    };
    self.generated_dir = .{ .step = &self.step };
    return self;
}

pub fn getPath(self: *GenerateHeaderStep) Build.LazyPath {
    return .{ .generated = .{ .file = &self.generated_dir } };
}

fn make(step: *Build.Step, progress: std.Progress.Node) !void {
    _ = progress;
    const b = step.owner;
    const self: *GenerateHeaderStep = @fieldParentPtr("step", step);
    const cwd = std.fs.cwd();

    var man = b.graph.cache.obtain();
    defer man.deinit();

    // Random bytes to make GeneratedIntrinsicHeader unique. Refresh this with
    // new random bytes when GeneratedIntrinsicHeader implementation is modified
    // in a non-backwards-compatible way.
    man.hash.add(@as(u32, 0xb7a568a2));

    // Build info header
    const build_info_contents = blk: {
        var file = try cwd.openFile(self.glslang_root.path(b, "CHANGES.md").getPath(b), .{});
        defer file.close();

        const contents = try file.readToEndAlloc(b.allocator, std.math.maxInt(usize));
        defer b.allocator.free(contents);

        const start = (std.mem.indexOf(u8, contents, "## ") orelse unreachable) + 3;
        const end = std.mem.indexOfScalar(u8, contents[start..], ' ') orelse unreachable;

        var it = std.mem.splitScalar(u8, contents[start..][0..end], '.');

        const major = it.next().?;
        const minor = it.next().?;
        const patch = it.next().?;
        const flavor = it.next() orelse "";

        const template =
            \\// Copyright (C) 2020 The Khronos Group Inc.
            \\//
            \\// All rights reserved.
            \\//
            \\// Redistribution and use in source and binary forms, with or without
            \\// modification, are permitted provided that the following conditions
            \\// are met:
            \\//
            \\//    Redistributions of source code must retain the above copyright
            \\//    notice, this list of conditions and the following disclaimer.
            \\//
            \\//    Redistributions in binary form must reproduce the above
            \\//    copyright notice, this list of conditions and the following
            \\//    disclaimer in the documentation and/or other materials provided
            \\//    with the distribution.
            \\//
            \\//    Neither the name of The Khronos Group Inc. nor the names of its
            \\//    contributors may be used to endorse or promote products derived
            \\//    from this software without specific prior written permission.
            \\//
            \\// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
            \\// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
            \\// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
            \\// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
            \\// COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
            \\// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
            \\// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
            \\// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
            \\// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
            \\// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
            \\// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
            \\// POSSIBILITY OF SUCH DAMAGE.
            \\
            \\#ifndef GLSLANG_BUILD_INFO
            \\#define GLSLANG_BUILD_INFO
            \\
            \\#define GLSLANG_VERSION_MAJOR @major@
            \\#define GLSLANG_VERSION_MINOR @minor@
            \\#define GLSLANG_VERSION_PATCH @patch@
            \\#define GLSLANG_VERSION_FLAVOR "@flavor@"
            \\
            \\#define GLSLANG_VERSION_GREATER_THAN(major, minor, patch) \
            \\    ((GLSLANG_VERSION_MAJOR) > (major) || ((major) == GLSLANG_VERSION_MAJOR && \
            \\    ((GLSLANG_VERSION_MINOR) > (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
            \\     (GLSLANG_VERSION_PATCH) > (patch)))))
            \\
            \\#define GLSLANG_VERSION_GREATER_OR_EQUAL_TO(major, minor, patch) \
            \\    ((GLSLANG_VERSION_MAJOR) > (major) || ((major) == GLSLANG_VERSION_MAJOR && \
            \\    ((GLSLANG_VERSION_MINOR) > (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
            \\     (GLSLANG_VERSION_PATCH >= (patch))))))
            \\
            \\#define GLSLANG_VERSION_LESS_THAN(major, minor, patch) \
            \\    ((GLSLANG_VERSION_MAJOR) < (major) || ((major) == GLSLANG_VERSION_MAJOR && \
            \\    ((GLSLANG_VERSION_MINOR) < (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
            \\     (GLSLANG_VERSION_PATCH) < (patch)))))
            \\
            \\#define GLSLANG_VERSION_LESS_OR_EQUAL_TO(major, minor, patch) \
            \\    ((GLSLANG_VERSION_MAJOR) < (major) || ((major) == GLSLANG_VERSION_MAJOR && \
            \\    ((GLSLANG_VERSION_MINOR) < (minor) || ((minor) == GLSLANG_VERSION_MINOR && \
            \\     (GLSLANG_VERSION_PATCH <= (patch))))))
            \\
            \\#endif // GLSLANG_BUILD_INFO
        ;

        const build_info_contents = try b.allocator.alloc(u8, template.len);
        errdefer b.allocator.free(build_info_contents);

        _ = std.mem.replace(
            u8,
            template,
            "@major@",
            major,
            build_info_contents,
        );

        const after_major_size =
            std.mem.replacementSize(
            u8,
            template,
            "@major@",
            major,
        );

        const after_minor_size =
            std.mem.replacementSize(
            u8,
            build_info_contents,
            "@minor@",
            minor,
        );

        _ = std.mem.replace(
            u8,
            build_info_contents[0..after_major_size],
            "@minor@",
            minor,
            build_info_contents,
        );

        const after_patch_size =
            std.mem.replacementSize(
            u8,
            build_info_contents,
            "@patch@",
            patch,
        );

        _ = std.mem.replace(
            u8,
            build_info_contents[0..after_minor_size],
            "@patch@",
            patch,
            build_info_contents,
        );

        _ = std.mem.replace(
            u8,
            build_info_contents[0..after_patch_size],
            "@flavor@",
            flavor,
            build_info_contents,
        );

        man.hash.addBytes(build_info_contents);

        break :blk build_info_contents;
    };
    defer b.allocator.free(build_info_contents);

    // Intrinsics header
    var intrinsics_contents = std.ArrayList(u8).init(b.allocator);
    defer intrinsics_contents.deinit();
    {
        const writer = intrinsics_contents.writer();

        try writer.writeAll(
            \\/***************************************************************************
            \\ *
            \\ * Copyright (c) 2015-2021 The Khronos Group Inc.
            \\ * Copyright (c) 2015-2021 Valve Corporation
            \\ * Copyright (c) 2015-2021 LunarG, Inc.
            \\ * Copyright (c) 2015-2021 Google Inc.
            \\ * Copyright (c) 2021 Advanced Micro Devices, Inc.All rights reserved.
            \\ *
            \\ ****************************************************************************/
            \\#pragma once
            \\
            \\#ifndef _INTRINSIC_EXTENSION_HEADER_H_
            \\#define _INTRINSIC_EXTENSION_HEADER_H_
            \\
        );

        var names = std.ArrayList([]const u8).init(b.allocator);
        defer {
            for (names.items) |name| {
                b.allocator.free(name);
            }
            names.deinit();
        }

        var intrinsics_dir = try cwd.openDir(
            self.glslang_root.path(b, "glslang/ExtensionHeaders").getPath(b),
            .{ .iterate = true },
        );
        defer intrinsics_dir.close();
        var iterator = intrinsics_dir.iterate();
        while (try iterator.next()) |entry| {
            if (std.mem.lastIndexOf(u8, entry.name, ".glsl")) |index| {
                const name = entry.name[0..index];

                try writer.print("std::string {s} = R\"(\n", .{name});

                var file = try intrinsics_dir.openFile(entry.name, .{});
                defer file.close();

                const start = intrinsics_contents.items.len;
                try intrinsics_contents.resize(start + try file.getEndPos());

                _ = try file.read(intrinsics_contents.items[start..]);

                try writer.writeAll(")\";\n");

                try names.append(try b.allocator.dupe(u8, name));

                man.hash.addBytes(name);
            }
        }

        try writer.writeAll(
            \\std::string getIntrinsic(const char* const* shaders, int n) {
            \\  std::string shaderString = "";
            \\  for (int i = 0; i < n; i++) {
            \\
        );

        for (names.items) |name| {
            try writer.print(
                \\    if(strstr(shaders[i], "{0s}") != nullptr) {{
                \\      shaderString.append({0s});
                \\    }}
                \\
            , .{name});
        }

        try writer.writeAll(
            \\  }
            \\	return shaderString;
            \\}
            \\
            \\#endif
        );

        man.hash.addBytes(intrinsics_contents.items);
    }

    if (try step.cacheHit(&man)) {
        const digest = man.final();
        self.generated_dir.path = try b.cache_root.join(b.allocator, &.{ "o", &digest });
        return;
    }

    const digest = man.final();
    const cache_path = "o" ++ std.fs.path.sep_str ++ digest ++ std.fs.path.sep_str ++ "glslang";

    var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
        return step.fail("unable to make path '{}{s}': {s}", .{
            b.cache_root, cache_path, @errorName(err),
        });
    };
    defer cache_dir.close();

    try cache_dir.writeFile(.{
        .sub_path = "build_info.h",
        .data = build_info_contents,
    });

    try cache_dir.writeFile(.{
        .sub_path = "glsl_intrinsic_header.h",
        .data = intrinsics_contents.items,
    });

    self.generated_dir.path = try b.cache_root.join(b.allocator, &.{ "o", &digest });
}
