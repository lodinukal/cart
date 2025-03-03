import { Inode } from "@bjorn3/browser_wasi_shim";
import { Cart, CartOptions, Memory, stdIo, file, directory } from "../packages/cart";

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

async function run() {
  const fs = new Map<string, Inode>();

  // adding files so luau can access them
  fs.set("example.luau", file("return 42"))
  fs.set("shared", directory([
    ["init.luau", file("return 500")]
  ]))

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

  const path = `/static/cart.wasm`;
  await cart.load(path);

  // const extra_lib = "/static/lib_test.wasm";
  // await cart.load(extra_lib);

  // const adder = cart.memory.exports!.my_add as (a: number, b: number) => number;
  // console.log(adder(1, 2));

  cart.setCustomRequireHandler((path, resolved_source) => {
    if (path === "EXAMPLE_REQUIRE") {
      return `return { path = "${path}", from = "${resolved_source}" }`;
    }
  });

  const thread = cart.loadThreadFromString(example_name, contents);
  if (!thread.valid) {
    throw new Error("Failed to load example");
  }
  await thread.execute();


  // for the thread let's get the top of the stack
  // memory for string len
  const str = thread.toString(-1);
  console.log(str);
  // const num = thread.toNumber(-1);
  // console.log(num);
  const bool = thread.toBoolean(-1);
  console.log(bool);
  const top_stack = thread.top;
  console.log(top_stack);
}

run();
