# CART

a `cross application run time` for luau

TODO:

- [ ] @cart/net implementation
  - [x] fetch
  - [ ] websocket
  - [ ] server
- [x] @cart/web implementation
- [x] @cart/process implementation
  - [x] basic process spawning
  - [x] asyncify :wait()
  - [x] io redirection
- [ ] @cart/json implementation
- [ ] Add more examples
- [ ] Automate js package building (currently a batch script with copy)
- [ ] Build js package instead of publishing ts files to npm
- [ ] Add tests

## Building

Currently using zig version `0.14.0-dev.2571`

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
