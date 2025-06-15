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

