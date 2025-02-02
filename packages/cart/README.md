# cart

To install dependencies:

```bash
bun install
```

## Example usage

```ts
import type { Inode } from "@bjorn3/browser_wasi_shim";
import { File } from "@bjorn3/browser_wasi_shim";
import { Cart, CartOptions, Memory, stdIo } from "../../packages/cart";

const shared_mem = new Memory();

const fs = new Map<string, Inode>();

const cart = new Cart(
  new CartOptions({
    memory: shared_mem,
    args: [],
    env: [],
    fds: stdIo("", fs),
  })
);

async function run() {
  await cart.load(/*wasm path*/);
  const thread = cart.loadThreadFromString("fib", `
local function fib(n)
  if n == 0 then
    return 0
  elseif n == 1 then
    return 1
  else
    return fib(n - 1) + fib(n - 2)
  end
end

print(fib(10))
  `);
  if (!thread.valid) {
    throw new Error("Failed to load example");
  }
  await thread.execute();
}

run();
```
