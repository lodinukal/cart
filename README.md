# CART

this is the rewrite branch

a `cross application run time` for luau

TODO:

# stage 1 (simple runtime capabilities for a mvp)
- [x] make function wrapper able to work with yielding functions
- [ ] asyncify cart/net (sockets)
- [ ] asyncify cart/fs (file system)
- [ ] create cart/process (process spawning)
- [ ] create cart/json (json parsing)
- [ ] create cart/crypto (crypto functions)
- [ ] port back cart/web (js functions and wasm ffi)
- [ ] create cart/ffi (ffi functions)
- [ ] create cart/http (http functions) 
- [ ] create cart/websocket (websocket functions)

# stage 2 (extra libraries that would be nice to have)
- [ ] cart/vendor/raylib (raylib bindings)
- [ ] cart/gui (rmgui framework)
- [ ] cart/gui/plot (matplotlib like graphing library)

## Building

Currently using zig version `0.15.0-dev.2571`

```bash
zig build run -- examples/test.luau
```

## Web

Use the `cart-luau` package to use cart within a js epplcation. Some examples also can be run by launching a server:

```bash
# in /web
bun install
bun run dev
```
