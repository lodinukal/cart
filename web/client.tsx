import type { Inode } from "@bjorn3/browser_wasi_shim";
import { File } from "@bjorn3/browser_wasi_shim";
import { Cart, CartOptions, LuauThread, Memory, stdIo } from "../packages/cart";

const shared_mem = new Memory();

const search_params = new Map<string, string>(
  window.location.search
    .split("?")[1]
    .split("&")
    .map((param) => {
      const [key, value] = param.split("=");
      return [key, value];
    })
);

let cart: Cart;
const default_luaurc = `
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
}`;

async function run() {
  const fs = new Map<string, Inode>();
  fs.set(
    "cart",
    new File([], {
      readonly: true,
    })
  );
  fs.set(
    ".luaurc",
    new File(new TextEncoder().encode(default_luaurc), {
      readonly: true,
    })
  );

  const example_with_args_name = search_params.get("example") || "dom.luau";
  const split_example_with_args = example_with_args_name.split("|");
  const example_name = split_example_with_args[0];
  const example_args = split_example_with_args.slice(1);
  const response = await fetch(`/examples/${example_name}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch example: ${response.statusText}`);
  }
  const contents = await response.text();

  cart = new Cart(
    new CartOptions({
      memory: shared_mem,
      args: example_args,
      env: [],
      fds: stdIo("", fs),
    })
  );
  await cart.load();

  const thread = cart.loadThreadFromString(example_name, contents);
  if (!thread.valid) {
    throw new Error("Failed to load example");
  }
  await thread.execute();
}

run();
