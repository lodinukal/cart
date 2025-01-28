zig build -Dtarget=wasm32-wasi -Doptimize=Debug
xcopy .\zig-out\bin\cart.wasm .\packages\cart\cart.wasm /Y