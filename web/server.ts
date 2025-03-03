import { Hono } from "hono";
import { serveStatic } from "hono/bun";

const app = new Hono();

const build_result = await Bun.build({
  entrypoints: ["./client.tsx"],
  outdir: "./dist",
  publicPath: "/static/",
});

app.use(
  "/static/*",
  serveStatic({
    root: "./dist",
    rewriteRequestPath: (path) => path.replace(/^\/static/, ""),
  })
);

app.use(
  "/examples/*",
  serveStatic({
    root: "../examples",
    // replace the /examples prefix with an empty string
    rewriteRequestPath: (path) => path.replace(/^\/examples/, ""),
  })
);

app.use(
  "/favicon.ico",
  serveStatic({
    path: "./favicon.ico",
  })
);

app.get("/example/*", async (c) => {
  c.header("Cross-Origin-Opener-Policy", "same-origin");
  c.header("Cross-Origin-Embedder-Policy", "require-corp");
  return c.html(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Cart</title>
      </head>
      <body>
        <div id="root"></div>
        <script src="/static/client.js"></script>
      </body>
    </html>
  `);
});

const port = parseInt(process.env.PORT!) || 3000;
console.log(`Running at http://localhost:${port}`);

const release = "v0.1.6";
const path = `https://github.com/lodinukal/cart/releases/download/${release}/cart.wasm`;

// download into ./dist/
// fetch(path).then(async (res) => {
//   if (res.ok === false) {
//     throw new Error(`Failed to fetch wasm form ${path}: ${res.statusText}`);
//   }
//   const file = Bun.file("./dist/cart.wasm");
//   const writer = file.writer();
//   await writer.write(await res.arrayBuffer());
// });

export default {
  port,
  fetch: app.fetch,
};
