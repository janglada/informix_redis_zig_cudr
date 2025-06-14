const std = @import("std");
const c = @cImport({
    @cInclude("hiredis/hiredis.h");
    @cInclude("stdlib.h"); // For free()
    @cInclude("mi.h");     // For mi_integer
});

pub export fn my_redis_publish() c.mi_integer {

    // Connect to Redis
    const context = c.redisConnect("127.0.0.1", 6379);
    if (context == null) {
        return 0; // Return 0 for error
    }

    // Publish message
    const reply = c.redisCommand(context, "PUBLISH %s %s", "informix_channel", "Hello from Zig UDR");
    if (reply == null) {
        c.free(context);
        return 0; // Return 0 for error
    }


    // Clean up
    c.free(reply);
    c.free(context);

    return 1; // Return 1 for success
}

