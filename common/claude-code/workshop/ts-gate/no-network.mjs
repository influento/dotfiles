// vitest setup file (installed as `test.setupFiles` in the project's vitest
// config): a test never reaches the network. Every outbound TCP connect and
// every fetch to a host other than loopback throws, naming the test and the
// host. Loopback stays open, so a test may listen on 127.0.0.1 and talk to
// itself; a unix socket path is local too. No opt-out inside a test: a test
// that needs a live endpoint is a recording, run once outside vitest, its
// response committed as a fixture. Only vitest loads this file; scripts, the
// CLI and the app keep the network.
import net from "node:net";
import { expect } from "vitest";

const loopback = (h) => {
  const host = h?.replace(/^\[|\]$/g, ""); // URL.hostname keeps the brackets of an IPv6 literal
  return !host || host === "localhost" || host.endsWith(".localhost") || host === "::1" || host === "0.0.0.0" || host.startsWith("127.");
};

function refuse(target) {
  const test = expect.getState().currentTestName ?? "test setup";
  throw new Error(
    `no-network: "${test}" tried to reach ${target}. Tests never touch the network: record the response once as a fixture and read that, or fake the boundary (a Layer, a stub fetch). Loopback is allowed.`,
  );
}

// net.Socket.prototype.connect is the one door: net.connect, http, https,
// tls, undici (Node's fetch and WebSocket) all go through it.
const connect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function (...args) {
  // net.connect / http hand the prototype a normalized [options, cb] array;
  // a direct call gives (options), (port, host) or (path).
  const [first, second] = Array.isArray(args[0]) ? args[0] : args;
  let host;
  let port;
  if (typeof first === "object" && first !== null) {
    if (!first.path) ({ host = "localhost", port } = first);
  } else if (typeof first === "number") {
    host = typeof second === "string" ? second : "localhost";
    port = first;
  }
  if (!loopback(host)) refuse(`${host}:${port}`);
  return connect.apply(this, args);
};

// fetch is caught above too, but through undici the error surfaces as
// "fetch failed" with the cause buried; checking the URL first names it.
const fetch = globalThis.fetch;
globalThis.fetch = async (input, init) => {
  const url = input instanceof Request ? input.url : String(input);
  let host;
  try {
    host = new URL(url).hostname;
  } catch {
    host = undefined; // relative or invalid: let fetch produce its own error
  }
  if (!loopback(host)) refuse(url);
  return fetch(input, init);
};
