export fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn lAdd(l: *luau.Luau) i32 {
    const a = l.checkInteger(1);
    const b = l.checkInteger(2);
    l.pushInteger(add(a, b));
    return 1;
}

export fn open(l: *luau.Luau) callconv(.c) i32 {
    l.newTable();

    l.pushString("add");
    l.pushFunction(lAdd, "mylib.add");
    l.setTable(-3);

    l.setReadOnly(-1, true);

    return 1;
}

const luau = @import("luau");
const std = @import("std");
