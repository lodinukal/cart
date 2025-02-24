export class Memory {
  memory?: WebAssembly.Memory;
  exports?: Record<string, any>;
  sizet_size: number = 4;

  constructor() { }

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

  storef32Array(ptr: number, arr: Float32Array) {
    new Float32Array(this.mem!.buffer, ptr, arr.length).set(arr);
  }

  storef64Array(ptr: number, arr: Float64Array) {
    new Float64Array(this.mem!.buffer, ptr, arr.length).set(arr);
  }

  storei32Array(ptr: number, arr: Int32Array) {
    new Int32Array(this.mem!.buffer, ptr, arr.length).set(arr);
  }

  storei64Array(ptr: number, arr: BigInt64Array) {
    new BigInt64Array(this.mem!.buffer, ptr, arr.length).set(arr);
  }

  storeu32Array(ptr: number, arr: Uint32Array) {
    new Uint32Array(this.mem!.buffer, ptr, arr.length).set(arr);
  }

  storeu64Array(ptr: number, arr: BigUint64Array) {
    new BigUint64Array(this.mem!.buffer, ptr, arr.length).set(arr);
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

  storeZString(ptr: number, str: string) {
    this.storeString(ptr, str);
    this.storeu8(ptr + str.length, 0);
  }

  alloc(len: number) {
    const ptr = this.exports!["cart_alloc"](len);
    return ptr;
  }

  free(ptr: number) {
    this.exports!["cart_free"](ptr);
  }

  allocZString(str: string) {
    const ptr = this.alloc(str.length + 1);
    this.storeZString(ptr, str);
    return ptr;
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
  Directory,
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

  debug: boolean = false;

  public constructor(init?: Partial<CartOptions>) {
    Object.assign(this, init);
  }
}

class NativeException extends Error {
  constructor(public readonly ptr: number) {
    super("native exception at " + ptr);
  }
}

export enum ThreadStatus {
  ok,
  yield,
  err_runtime,
  err_syntax,
  err_memory,
  err_error,
}

export class LuauThread {
  cart: Cart;
  handle: number;

  constructor(cart: Cart, handle: number) {
    this.cart = cart;
    this.handle = handle;
  }

  get valid() {
    return this.handle !== 0;
  }

  close() {
    const cart_closeThread = this.cart.memory.exports!["cart_closeThread"] as (
      thread: number
    ) => void;
    cart_closeThread(this.handle);
  }

  async execute() {
    const cart_executeThread = this.cart.memory.exports![
      "cart_executeThread"
    ] as (thread: number) => void;
    cart_executeThread(this.handle);
    while (this.is_scheduled) {
      await new Promise((resolve) => setTimeout(resolve, 0));
    }
  }

  get is_scheduled(): boolean {
    const cart_threadIsScheduled = this.cart.memory.exports![
      "cart_threadIsScheduled"
    ] as (thread: number) => number;
    return cart_threadIsScheduled(this.handle) !== 0;
  }

  get status(): ThreadStatus {
    const cart_threadStatus = this.cart.memory.exports![
      "cart_threadStatus"
    ] as (thread: number) => number;
    return cart_threadStatus(this.handle);
  }
}

// reserve the first handles:
// 0: null
// 1: undefined
// 2: empty string
// 3: true
// 4: false

export const enum TaggedValueType {
  null = 0,
  undefined = 1,
  empty_string = 2,
  true = 3,
  false = 4,
  start = 5,
}

export const enum MarshalType {
  null = 0,
  string = 1,
  number = 2,
  bigint = 3,
  boolean = 4,
  symbol = 5,
  undefined = 6,
  object = 7,
  function = 8,

  uint8array = 9,
  array = 10,
}

export class TaggedValue {
  value: any;
  free_fn: (value: TaggedValue) => void;

  constructor(
    value: any,
    free_fn: (value: TaggedValue) => void = TaggedValue.defaultFree
  ) {
    this.value = value;
    this.free_fn = free_fn;
  }

  free() {
    this.free_fn(this);
  }

  private static defaultFree(value: TaggedValue) { }
}

export class LuaFunction {
  cart: Cart;
  l: number;
  handle: number;

  constructor(cart: Cart, l: number, handle: number) {
    this.cart = cart;
    this.l = l;
    this.handle = handle;
  }

  destroy() {
    const cart_destroyFunction = this.cart.memory.exports![
      "cart_destroyFunction"
    ] as (l: number, f: number) => void;
    cart_destroyFunction(this.l, this.handle);
  }

  callFn = (...args: any[]) => {
    const cart_callFunction = this.cart.memory.exports![
      "cart_callFunction"
    ] as (l: number, f: number, args_ptr: number, args_len: number) => number;
    const args_ptr = this.cart.memory.alloc(args.length * 4);
    const args_handles = args.map((arg) => {
      const handle = this.cart.alloc_handle();
      this.cart.handles[handle] = new TaggedValue(arg);
      return handle;
    });
    this.cart.memory.storeu32Array(args_ptr, new Uint32Array(args_handles));
    const result = cart_callFunction(
      this.l,
      this.handle,
      args_ptr,
      args_handles.length
    );
    this.cart.memory.free(args_ptr);
    for (const handle of args_handles) {
      this.cart.free_handle(handle);
    }
    return this.cart.handles[result]?.value;
  };
}

export class Cart {
  memory: Memory;
  wasi: WASI;

  started: boolean = false;

  handles: Array<TaggedValue | undefined> = [
    new TaggedValue(null),
    new TaggedValue(undefined),
    new TaggedValue(""),
    new TaggedValue(true),
    new TaggedValue(false),
  ];
  maxHandle: number = TaggedValueType.start;
  freeHandles: Array<number> = [];
  customRequireHandler:
    | ((path: string, resolved_source: string) => string | undefined)
    | undefined;

  constructor(options: CartOptions) {
    this.memory = options.memory || new Memory();
    this.memory.setIntSize(options.sizet_size || 4);

    this.wasi = new WASI(["cart", ...options.args], options.env, options.fds, {
      debug: options.debug,
    });
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
            } else {
              throw e;
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

          const url = self.memory.loadString(url_ptr, url_len);
          fetch(url)
            .then((response) => response.text())
            .then((text) => {
              // allocate a new buffer in the wasm memory
              const ptr = self.memory.alloc(text.length);
              if (ptr === 0) {
                console.error("Failed to allocate memory for fetch response");
                cart_on_fetched_error(context);
                return;
              }
              self.memory.storeString(ptr, text);
              cart_on_fetched_success(context, ptr, text.length);
              self.memory.free(ptr);
            })
            .catch((error) => {
              console.error(`Failed to fetch ${url}: ${error}`);
              cart_on_fetched_error(context);
            });
        },
        cart_require_handler(
          path_ptr: number,
          path_len: number,
          resolved_source_ptr: number,
          resolved_source_len_ptr: number,
          out_len_ptr: number
        ): number {
          if (self.customRequireHandler === undefined) {
            return 0;
          }
          const path = self.memory.loadString(path_ptr, path_len);
          const resolved_source = self.memory.loadString(
            resolved_source_ptr,
            resolved_source_len_ptr
          );
          const result = self.customRequireHandler(path, resolved_source);
          if (result === undefined) {
            return 0;
          }
          const result_ptr = self.memory.alloc(result.length);
          self.memory.storeString(result_ptr, result);
          self.memory.storeusize(out_len_ptr, result.length);
          return result_ptr;
        },

        cart_web_string(ptr: number, len: number): number {
          if (len === 0) return TaggedValueType.empty_string;

          const str = self.memory.loadString(ptr, len);
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue(str);
          return handle;
        },

        cart_web_as_string(
          handle: number,
          str_ptr_ptr: number,
          str_len_ptr: number
        ): number {
          const value = self.handles[handle]?.value;
          if (value === undefined) {
            return 0;
          }
          const str = value as string;
          const str_ptr = self.memory.alloc(str.length);
          self.memory.storeString(str_ptr, str);
          self.memory.storeusize(str_len_ptr, str.length);
          self.memory.storeusize(str_ptr_ptr, str_ptr);
          return 1;
        },

        cart_web_number(value: number): number {
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue(value);
          return handle;
        },

        cart_web_as_number(handle: number, ptr: number): number {
          const value = self.handles[handle]?.value;
          if (value === undefined) {
            return 0;
          }
          const f64 = value as number;
          self.memory.storef64(ptr, f64);
          return 1;
        },

        cart_web_boolean(value: number): number {
          return value !== 0 ? TaggedValueType.true : TaggedValueType.false;
        },

        cart_web_as_boolean(handle: number, ptr: number): number {
          const value = self.handles[handle]?.value;
          if (value === undefined) {
            return 0;
          }
          const b = value as boolean;
          self.memory.storebool8(ptr, b);
          return 1;
        },

        cart_web_buffer(ptr: number, len: number): number {
          const bytes = self.memory.loadBytes(ptr, len);
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue(bytes);
          return handle;
        },

        cart_web_as_buffer(
          handle: number,
          ptr_ptr: number,
          len_ptr: number
        ): number {
          const value = self.handles[handle]?.value;
          if (value === undefined) {
            return 0;
          }
          const bytes = value as Uint8Array;
          const ptr = self.memory.alloc(bytes.length);
          self.memory.storeBytes(ptr, bytes);
          self.memory.storeusize(len_ptr, bytes.length);
          self.memory.storeusize(ptr_ptr, ptr);
          return 1;
        },

        cart_web_object(): number {
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue({});
          return handle;
        },

        cart_web_array(): number {
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue([]);
          return handle;
        },

        cart_web_free(handle: number) {
          self.free_handle(handle);
        },

        cart_web_typeof(handle: number): number {
          if (self.handles[handle]?.value === null) {
            return MarshalType.null;
          }
          switch (typeof self.handles[handle]?.value) {
            case "string":
              return MarshalType.string;
            case "number":
              return MarshalType.number;
            case "bigint":
              return MarshalType.bigint;
            case "boolean":
              return MarshalType.boolean;
            case "symbol":
              return MarshalType.symbol;
            case "undefined":
              return MarshalType.undefined;
            case "object":
              if (self.handles[handle]?.value instanceof Array) {
                return MarshalType.array;
              }
              if (self.handles[handle]?.value instanceof Uint8Array) {
                return MarshalType.uint8array;
              }
              return MarshalType.object;
            case "function":
              return MarshalType.function;
            default:
              return MarshalType.undefined;
          }
        },

        cart_web_get(handle: number, index: number): number {
          const value = self.handles[handle]?.value;
          if (value === undefined) {
            return TaggedValueType.undefined;
          }
          const resolved_index = self.handles[index]?.value;
          const returning = self.alloc_handle();
          self.handles[returning] = new TaggedValue(value[resolved_index]);
          return returning;
        },

        cart_web_set(handle: number, index: number, value: number) {
          const obj = self.handles[handle]?.value;
          if (obj === undefined) {
            return;
          }
          obj[self.handles[index]?.value] = self.handles[value]?.value;
        },

        cart_web_call(
          handle: number,
          args_ptr: number,
          args_len: number
        ): number {
          const func = self.handles[handle]?.value;
          if (func === undefined) {
            return TaggedValueType.undefined;
          }
          const args_handles = self.memory.loadu32Array(args_ptr, args_len);
          const args = [];
          for (let i = 0; i < args_len; i++) {
            args.push(self.handles[args_handles[i]]?.value);
          }
          const result = func(...args);
          const returning = self.alloc_handle();
          self.handles[returning] = new TaggedValue(result);
          return returning;
        },

        cart_web_invoke(
          handle: number,
          name_ptr: number,
          name_len: number,
          args_ptr: number,
          args_len: number
        ): number {
          const obj = self.handles[handle]?.value;
          if (obj === undefined) {
            return TaggedValueType.undefined;
          }
          const name = self.memory.loadString(name_ptr, name_len);

          const args_handles = self.memory.loadu32Array(args_ptr, args_len);
          const args = [];
          for (let i = 0; i < args_len; i++) {
            let value = self.handles[args_handles[i]]?.value;
            if (value instanceof LuaFunction) {
              value = value.callFn;
            }
            args.push(value);
          }
          if (obj[name] === undefined) {
            console.error(`No method ${name} on object ${obj}`);
            return TaggedValueType.undefined;
          }
          let result = obj[name](...args);
          const returning = self.alloc_handle();
          self.handles[returning] = new TaggedValue(result);
          return returning;
        },

        cart_web_global(name_ptr: number, name_len: number): number {
          const name = self.memory.loadString(name_ptr, name_len);
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue((globalThis as any)[name]);
          return handle;
        },

        // takes a lua ref
        cart_web_function(l: number, f: number): number {
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue(
            new LuaFunction(self, l, f),
            (v) => {
              const func = v.value as LuaFunction;
              func.destroy();
            }
          );
          return handle;
        },

        // grab something from memory export
        cart_web_wasm_export(name_ptr: number, name_len: number): number {
          const name = self.memory.loadString(name_ptr, name_len);
          const handle = self.alloc_handle();
          self.handles[handle] = new TaggedValue(self.memory.exports![name]);
          return handle;
        },
      },
      wasi_snapshot_preview1: this.wasi.wasiImport,
    };
  }

  alloc_handle() {
    if (this.freeHandles.length > 0) {
      return this.freeHandles.pop()!;
    }
    const v = this.maxHandle;
    this.maxHandle++;
    return v;
  }

  free_handle(handle: number) {
    if (this.handles[handle] !== undefined) {
      this.handles[handle]!.free();
    }
    this.handles[handle] = undefined;
    this.freeHandles.push(handle);
  }

  allocate(size: number): number {
    const ptr = this.memory.exports!["cart_alloc"](size);
    return ptr;
  }

  popLastError(): string | undefined {
    const ptr = this.memory.exports!["cart_popLastError"]();
    if (ptr === 0) return undefined;
    const message = this.memory.loadZString(ptr);
    return message;
  }

  loadThreadFromFile(path: string): LuauThread {
    const cart_loadThreadFromFile = this.memory.exports![
      "cart_loadThreadFromFile"
    ] as (path_ptr: number, path_len: number) => number;
    const path_ptr = this.memory.allocZString(path);
    const thread_ptr = cart_loadThreadFromFile(path_ptr, path.length);
    this.memory.free(path_ptr);
    return new LuauThread(this, thread_ptr);
  }

  loadThreadFromString(path: string, source: string): LuauThread {
    const cart_loadThreadFromString = this.memory.exports![
      "cart_loadThreadFromString"
    ] as (
      path_ptr: number,
      path_len: number,
      source_ptr: number,
      source_len: number
    ) => number;
    const path_ptr = this.memory.allocZString(path);
    const source_ptr = this.memory.allocZString(source);
    const thread_ptr = cart_loadThreadFromString(
      path_ptr,
      path.length,
      source_ptr,
      source.length
    );
    this.memory.free(path_ptr);
    this.memory.free(source_ptr);
    return new LuauThread(this, thread_ptr);
  }

  setCustomRequireHandler(
    f: (path: string, resolved_source: string) => string | undefined
  ) {
    this.customRequireHandler = f;
  }

  async load(path: string) {
    return fetch(path)
      .then(async (res) => res.arrayBuffer())
      .then(async (buffer) => WebAssembly.compile(buffer))
      .then(async (module) => this.run(module));
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
    const start = exports._start as (() => void) | undefined;
    if (start !== undefined && !this.started) {
      this.wasi.start({
        exports: {
          memory: this.memory.memory!,
          _start: start,
        },
      });
      this.started = true;
    } else if (start !== undefined && this.started) {
      console.warn(
        "Ignoring _start function as it was already called once in another module"
      );
    }

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

export const file = (content: string) => new File(new TextEncoder().encode(content))
export const directory = (entries: [string, Inode][]) => new Directory(new Map<string, Inode>(entries))