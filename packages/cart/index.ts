export class Memory {
  memory?: WebAssembly.Memory;
  exports?: Record<string, any>;
  sizet_size: number = 4;

  constructor() {}

  setMemory(memory: WebAssembly.Memory) {
    this.memory = memory;
  }

  setExports(exports: Record<string, any>) {
    this.exports = exports;
  }

  setIntSize(size: number) {
    this.sizet_size = size;
  }

  get mem() {
    if (!this.memory) return undefined;
    return new DataView(this.memory.buffer);
  }

  loadf32Array(ptr: number, len: number) {
    const arr = new Float32Array(this.mem!.buffer, ptr, len);
    return arr;
  }

  loadf64Array(ptr: number, len: number) {
    const arr = new Float64Array(this.mem!.buffer, ptr, len);
    return arr;
  }

  loadi32Array(ptr: number, len: number) {
    const arr = new Int32Array(this.mem!.buffer, ptr, len);
    return arr;
  }

  loadi64Array(ptr: number, len: number) {
    const arr = new BigInt64Array(this.mem!.buffer, ptr, len);
    return arr;
  }

  loadu32Array(ptr: number, len: number) {
    const arr = new Uint32Array(this.mem!.buffer, ptr, len);
    return arr;
  }

  loadu64Array(ptr: number, len: number) {
    const arr = new BigUint64Array(this.mem!.buffer, ptr, len);
    return arr;
  }

  loadu8(ptr: number) {
    return this.mem!.getUint8(ptr);
  }

  loadi8(ptr: number) {
    return this.mem!.getInt8(ptr);
  }

  loadu16(ptr: number) {
    return this.mem!.getUint16(ptr, true);
  }

  loadi16(ptr: number) {
    return this.mem!.getInt16(ptr, true);
  }

  loadu32(ptr: number) {
    return this.mem!.getUint32(ptr, true);
  }

  loadi32(ptr: number) {
    return this.mem!.getInt32(ptr, true);
  }

  loadf32(ptr: number) {
    return this.mem!.getFloat32(ptr, true);
  }

  loadf64(ptr: number) {
    return this.mem!.getFloat64(ptr, true);
  }

  loadu64(ptr: number) {
    return this.mem!.getBigUint64(ptr, true);
  }

  loadi64(ptr: number) {
    return this.mem!.getBigInt64(ptr, true);
  }

  loadusize(ptr: number) {
    if (this.sizet_size === 4) {
      return this.loadu32(ptr);
    } else {
      return this.loadu64(ptr);
    }
  }

  loadisize(ptr: number) {
    if (this.sizet_size === 4) {
      return this.loadi32(ptr);
    } else {
      return this.loadi64(ptr);
    }
  }

  loadbool8(ptr: number) {
    return this.loadu8(ptr) !== 1;
  }

  loadbool32(ptr: number) {
    return this.loadu32(ptr) !== 1;
  }

  loadBytes(ptr: number, len: number) {
    const bytes = new Uint8Array(this.mem!.buffer, ptr, len);
    return bytes;
  }

  loadString(ptr: number, len: number) {
    const bytes = this.loadBytes(ptr, len);
    const decoder = new TextDecoder();
    return decoder.decode(bytes);
  }

  loadZBytes(ptr: number) {
    let len = 0;
    while (this.loadu8(ptr + len) !== 0) {
      len++;
    }
    return this.loadBytes(ptr, len);
  }

  loadZString(ptr: number) {
    let len = 0;
    while (this.loadu8(ptr + len) !== 0) {
      len++;
    }
    return this.loadString(ptr, len);
  }

  storeu8(ptr: number, val: number) {
    this.mem!.setUint8(ptr, val);
  }

  storei8(ptr: number, val: number) {
    this.mem!.setInt8(ptr, val);
  }

  storeu16(ptr: number, val: number) {
    this.mem!.setUint16(ptr, val, true);
  }

  storei16(ptr: number, val: number) {
    this.mem!.setInt16(ptr, val, true);
  }

  storeu32(ptr: number, val: number) {
    this.mem!.setUint32(ptr, val, true);
  }

  storei32(ptr: number, val: number) {
    this.mem!.setInt32(ptr, val, true);
  }

  storef32(ptr: number, val: number) {
    this.mem!.setFloat32(ptr, val, true);
  }

  storef64(ptr: number, val: number) {
    this.mem!.setFloat64(ptr, val, true);
  }

  storeu64(ptr: number, val: bigint) {
    this.mem!.setBigUint64(ptr, val, true);
  }

  storei64(ptr: number, val: bigint) {
    this.mem!.setBigInt64(ptr, val, true);
  }

  storeusize(ptr: number, val: number) {
    if (this.sizet_size === 4) {
      this.storeu32(ptr, val);
    } else {
      this.storeu64(ptr, BigInt(val));
    }
  }

  storeisize(ptr: number, val: number) {
    if (this.sizet_size === 4) {
      this.storei32(ptr, val);
    } else {
      this.storei64(ptr, BigInt(val));
    }
  }

  storebool8(ptr: number, val: boolean) {
    this.storeu8(ptr, val ? 1 : 0);
  }

  storebool32(ptr: number, val: boolean) {
    this.storeu32(ptr, val ? 1 : 0);
  }

  storeBytes(ptr: number, bytes: Uint8Array) {
    new Uint8Array(this.mem!.buffer, ptr, bytes.length).set(bytes);
  }

  storeString(ptr: number, str: string) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    this.storeBytes(ptr, bytes);
  }
}

import {
  WASI,
  File,
  OpenFile,
  Fd,
  ConsoleStdout,
  PreopenDirectory,
  Inode,
} from "@bjorn3/browser_wasi_shim";

export function stdIo(
  stdin: string,
  files: Map<string, Inode> = new Map<string, Inode>()
): Fd[] {
  return [
    new OpenFile(new File(new TextEncoder().encode(stdin))),
    ConsoleStdout.lineBuffered((line) => console.log(line)),
    ConsoleStdout.lineBuffered((line) => console.error(line)),
    new PreopenDirectory(".", files),
  ];
}

export class CartOptions {
  memory: Memory = new Memory();
  sizet_size: number = 4;

  args: string[] = ["cart"];
  env: string[] = [];
  fds: Fd[] = stdIo("");

  public constructor(init?: Partial<CartOptions>) {
    Object.assign(this, init);
  }
}

import cart_wasm from "./cart.wasm";

class NativeException extends Error {
  constructor(public readonly ptr: number) {
    super("native exception at " + ptr);
  }
}

export class Cart {
  memory: Memory;
  wasi: WASI;

  constructor(options: CartOptions) {
    this.memory = options.memory || new Memory();
    this.memory.setIntSize(options.sizet_size || 4);

    this.wasi = new WASI(["cart", ...options.args], options.env, options.fds);
  }

  defaultImports(): Record<string, any> {
    var self = this;
    return {
      env: {
        memory: this.memory.memory,
        throw(ptr: number) {
          throw new NativeException(ptr);
        },
        try_catch(ctx: number) {
          let try_js = self.memory.exports!["zig_luau_try_impl"];
          let catch_js = self.memory.exports!["zig_luau_catch_impl"];
          try {
            try_js(ctx);
          } catch (e) {
            if (e instanceof NativeException) {
              catch_js(ctx, e.ptr);
            }
          }
        },
        cart_fetch(url_ptr: number, url_len: number, context: number) {
          const cart_on_fetched_success = self.memory.exports![
            "cart_on_fetched_success"
          ];
          const cart_on_fetched_error = self.memory.exports![
            "cart_on_fetched_error"
          ];

          const cart_alloc = self.memory.exports!["cart_alloc"] as (
            size: number
          ) => number;
          const cart_free = self.memory.exports!["cart_free"] as (
            ptr: number
          ) => void;

          const url = self.memory.loadString(url_ptr, url_len);
          fetch(url)
            .then((response) => response.text())
            .then((text) => {
              // allocate a new buffer in the wasm memory
              const ptr = cart_alloc(text.length);
              if (ptr === 0) {
                console.error("Failed to allocate memory for fetch response");
                cart_on_fetched_error(context);
                return;
              }
              self.memory.storeString(ptr, text);
              cart_on_fetched_success(context, ptr, text.length);
              cart_free(ptr);
            })
            .catch((error) => {
              console.error(`Failed to fetch ${url}: ${error}`);
              cart_on_fetched_error(context);
            });
        },
      },
      wasi_snapshot_preview1: this.wasi.wasiImport,
    };
  }

  async load() {
    const response = await fetch(cart_wasm);
    const buffer = await response.arrayBuffer();
    const module = await WebAssembly.compile(buffer);
    await this.run(module);
  }

  async run(
    module: WebAssembly.Module,
    extra_imports: Record<string, any> = {}
  ) {
    const imports = {
      ...this.defaultImports(),
      ...extra_imports,
    };

    const instance = await WebAssembly.instantiate(module, imports);
    const exports = instance.exports;
    this.memory.setExports({
      ...this.memory.exports,
      ...exports,
    });

    if (exports.memory !== undefined) {
      if (this.memory.memory !== undefined)
        throw new Error(
          "Memory already set; it is invalid to load more than one memory"
        );
      this.memory.setMemory(exports.memory as WebAssembly.Memory);
    }
    const start = exports._start as () => void;
    this.wasi.start({
      exports: {
        memory: this.memory.memory!,
        _start: start,
      },
    });

    const end = exports.cart_end as (() => void) | undefined;

    if (exports.cart_step !== undefined) {
      let prev_time: number | undefined = undefined;
      function step(current_time: number) {
        if (prev_time === undefined) {
          prev_time = current_time;
        }
        const delta = current_time - prev_time;
        prev_time = current_time;
        const continues = (exports.cart_step as (arg0: number) => boolean)(
          delta / 1000
        );
        if (!continues) {
          end?.();
          return;
        }
        requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    } else {
      end?.();
    }
  }
}
