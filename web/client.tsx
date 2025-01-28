import type { Inode } from "@bjorn3/browser_wasi_shim";
import { File } from "@bjorn3/browser_wasi_shim";
import { Cart, CartOptions, Memory, stdIo } from "cart-luau";

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

  const example_name = search_params.get("example") || "dom.luau";
  const response = await fetch(`/examples/${example_name}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch example: ${response.statusText}`);
  }
  const contents = await response.text();
  fs.set(example_name, new File(new TextEncoder().encode(contents)));

  const cart = new Cart(
    new CartOptions({
      memory: shared_mem,
      args: [example_name],
      env: [],
      fds: stdIo("", fs),
    })
  );
  await cart.load();
}

run();
