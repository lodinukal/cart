import { Hono } from "hono";
import { serveStatic } from "hono/bun";

import { build } from "bun";

const app = new Hono();

const build_result = await build({
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

export default {
  port,
  fetch: app.fetch,
};
