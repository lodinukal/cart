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
fs.set(
  "cart",
  new File([], {
    readonly: true,
  })
);
fs.set(
  ".luaurc",
  new File(
    new TextEncoder().encode(`
{
  "languageMode": "strict",
  "lint": {
    "*": true
  },
  "lintErrors": false,
  "typeErrors": true,
  "globals": [
    "warn"
  ],
  "aliases": {
  }
}`),
    {
      readonly: true,
    }
  )
);

fs.set(
  "test.luau",
  new File(
    new TextEncoder().encode(
      `
local task = require("@cart/task")
local fs = require("@cart/fs")
local function fib(n)
  if n <= 1 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end

local result = fib(10)

fs.openFile("output.temp.txt", {
    create_if_not_exists = true,
    open_mode = "read_write",
})
    :writer()
    :write(buffer.fromstring(\`result {result}\`))
`
    )
  )
);

const cart = new Cart(
  new CartOptions({
    memory: shared_mem,
    args: ["test.luau"],
    env: [],
    fds: stdIo("", fs),
  })
);

async function run() {
  await cart.load();
  console.log(shared_mem.exports);
}

run();
```
