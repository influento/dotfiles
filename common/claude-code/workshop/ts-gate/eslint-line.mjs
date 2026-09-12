// One line per problem, no colour: what the Stop hook feeds back. ESLint 10
// has no core `unix` formatter; this is that format, relative paths.
import { relative } from "node:path";
export default (results) =>
  results
    .flatMap((r) => r.messages.map((m) => `${relative("", r.filePath)}:${m.line}:${m.column}: ${m.message} [${m.severity === 2 ? "Error" : "Warning"}/${m.ruleId}]`))
    .join("\n");
