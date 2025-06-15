const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
//    const optimize = b.standardOptimizeOption(.{});
    
    const lib = b.addSharedLibrary(.{
        .name = "redis_publish",
        .root_source_file = b.path("redis_publish.zig"),
        .target = target,
        .optimize = .Debug,
        .pic = true,  // Enable Position-Independent Code here
    });

   // Ensure symbols are exported
    lib.linker_allow_shlib_undefined = true;

    // Add include paths
    lib.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    lib.addIncludePath(.{ .cwd_relative = "/opt/ibm/informix/incl/public" });
    
    // Add library path
    lib.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    
    // Link libraries
    lib.linkSystemLibrary("hiredis");
    lib.linkSystemLibrary("c");


    
    b.installArtifact(lib);

    // Custom step to copy to Informix directory with verbose output
    const copy_cmd = b.addSystemCommand(&[_][]const u8{
        "cp", "-v",
        "zig-out/lib/libredis_publish.so",
        "/opt/ibm/informix/extend/my_ext/libredis_publish.so"
    });
    copy_cmd.step.dependOn(b.getInstallStep());
    
    // Create a step that runs the copy command
    const install_step = b.step("install-informix", "Install library to Informix directory");  
    install_step.dependOn(&copy_cmd.step);
    
    // Also create a step to just show where the file was built
    const show_file = b.addSystemCommand(&[_][]const u8{
        "ls", "-la", "zig-out/lib/libredis_publish.so"
    });
    show_file.step.dependOn(b.getInstallStep());
    
    const show_step = b.step("show", "Show built library location");
    show_step.dependOn(&show_file.step);
}

