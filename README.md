

# Informix UDR in Zig with Redis Publish

This repository demonstrates how to write an Informix User-Defined Routine (UDR) in **Zig**, which uses the C **hiredis** library to publish a message to Redis. The UDR returns `1` for success and `0` for failure, using Informix’s `mi_integer` type from `mi.h`.




## Prerequisites

* **Informix Developer Edition** with Extend/UDR enabled
* **Redis server** reachable from the Informix machine
* **Zig** (preferably v0.11+; v0.15 dev also works for building)
* **hiredis** installed (`libhiredis.so` and headers in `/usr/local/include` & `/usr/local/lib`)

---

## Install Informix Developer Edition


```bash
docker run -it --name ifx -h ifx --privileged -e LICENSE=accept \
    -p 9088:9088 -p 9089:9089 -p 27017:27017 -p 27018:27018 -p 27883:27883 \
    --add-host=host.docker.internal:host-gateway \
    ibmcom/informix-developer-database:latest
``
---

##  Zig Source

Create `redis_publish.zig`:

```zig
const std = @import("std");
const c = @cImport({
    @cInclude("hiredis/hiredis.h");
    @cInclude("stdlib.h");
    @cInclude("mi.h");
});

// Try using the alternative export method

export fn redis_publish()  c.mi_integer {
    // Connect to Redis
    const context = c.redisConnect("127.0.0.1", 6379);
    if (context == null) {
        return 0; // Return 0 for error
    }
    
    // Check connection status
    if (context.*.err != 0) {
        c.redisFree(context);
        return 0;
    }
    
    // Publish message
    const reply = c.redisCommand(context, "PUBLISH %s %s", "informix_channel", "Hello from Zig UDR");
    if (reply == null) {
        c.redisFree(context);
        return 0; // Return 0 for error
    }
    
    // Clean up properly
    c.freeReplyObject(reply);  // Use freeReplyObject for reply
    c.redisFree(context);      // Use redisFree for context
    
    return 1; // Return 1 for success
}

```

---

## Build Shared Library & Deploy

Add build.zig

```zig
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

```

Run:

```bash
zig build install-informix
```

This generates `libredis_publish.so` and copies it to Informix's extend directory:



---

## Register in Informix

In `dbaccess` or your SQL client:

```sql
CREATE FUNCTION redis_publish()
RETURNING INT
EXTERNAL NAME '/opt/ibm/informix/extend/my_ext/libredis_publish.so(redis_publish)'
LANGUAGE C;
```

---

## Test the UDR

```sql
EXECUTE FUNCTION redis_publish();
```

If Redis receives the message, return value is `1`. Otherwise, `0`.

---



