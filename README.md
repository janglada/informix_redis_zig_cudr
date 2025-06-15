

# Informix UDR in Zig with Redis Publish

This repository demonstrates how to write an Informix User-Defined Routine (UDR) in **Zig**, which uses the C **hiredis** library to publish a message to Redis. The UDR returns `1` for success and `0` for failure, using Informix’s `mi_integer` type from `mi.h`.

---

## 🔧 Prerequisites

* **Informix Developer Edition** with Extend/UDR enabled
* **Redis server** reachable from the Informix machine
* **Zig** (preferably v0.11+; v0.15 dev also works for building)
* **hiredis** installed (`libhiredis.so` and headers in `/usr/local/include` & `/usr/local/lib`)

---

##  Zig Source

Create `redis_publish.zig`:

```zig
const std = @import("std");
const c = @cImport({
    @cInclude("hiredis/hiredis.h");
    @cInclude("stdlib.h");
    @cInclude("mi.h"); // Informix MI API
});

// UDR exposed for Informix: returns mi_integer (0/1)
pub export fn my_redis_publish() c.mi_integer {
    const ctx = c.redisConnect("127.0.0.1", 6379);
    if (ctx == null) return 0;

    const reply = c.redisCommand(ctx, "PUBLISH %s %s", "informix_channel", "Hello from Zig UDR");
    if (reply == null) {
        c.free(ctx);
        return 0;
    }

    c.free(reply);
    c.free(ctx);
    return 1;
}
```

---

## Build Shared Library

Run:

```bash
zig build-lib redis_publish.zig \
  -dynamic \
  -I/usr/local/include \
  -L/usr/local/lib \
  -lhiredis \
  -lc \
  -fPIC \
  -target native-linux-gnu
```

This generates `libredis_publish.so`.

---

## Deploy to Informix

Copy the library to Informix's extend directory:

```bash
cp libredis_publish.so \
   /opt/ibm/informix/extend/my_ext/
chmod 755 /opt/ibm/informix/extend/my_ext/libredis_publish.so
```

---

## Register in Informix

In `dbaccess` or your SQL client:

```sql
CREATE FUNCTION my_redis_publish()
RETURNING INT
EXTERNAL NAME '/opt/ibm/informix/extend/my_ext/libredis_publish.so(my_redis_publish)'
LANGUAGE C;
```

---

## Test the UDR

```sql
EXECUTE FUNCTION my_redis_publish();
```

If Redis receives the message, return value is `1`. Otherwise, `0`.

---



