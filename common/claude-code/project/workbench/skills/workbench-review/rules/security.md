# Security

Find vulnerabilities the code under review introduces that an attacker could
actually exploit. Not a general review, not a hardening audit: a finding is a
concrete attack path from an untrusted input to a sensitive operation, and
nothing else is one.

The scope is what changed. When the root is on a branch other than the
default one, the diff is the scope — `git diff <default>...HEAD` plus the
files it touches; name the base you used. On the default branch the scope is
the paths or words given, or `src/` when none was. Read the code around the
diff for context — what already validates, escapes, or trusts — and compare
the new code against it: a deviation from an established pattern is where to
look first. Report only what the scope adds; a problem that predates it is a
line under a `pre-existing:` heading, not a finding.

Categories, in the order they are worth the time:

- injection: SQL, command (subprocess, `exec`, shell strings), template,
  NoSQL, XXE, path traversal in file operations
- authentication and authorization: bypass logic, privilege escalation,
  session handling, token validation, a check on the client that the server
  does not repeat
- code execution: deserialization (`pickle`, YAML `load`), `eval` on built
  strings, DOM XSS through `dangerouslySetInnerHTML` or its equivalents
- secrets and crypto: hardcoded keys or tokens, a weak or home-made
  primitive, a non-cryptographic random where one is needed, certificate
  validation switched off
- exposure: a secret, password or personal data written to a log, a
  response, or an error message

Each finding: `path:line`, severity (HIGH — exploitable as written, leading to
code execution, data breach or auth bypass; MEDIUM — needs a specific
condition, significant impact), the attack path as concrete input → effect,
and the fix. Confidence below 8 of 10 is not reported; MEDIUM only when it is
obvious. Better to miss a theoretical issue than to bury the real one.

Not findings, whatever the code looks like:

- denial of service, resource exhaustion, rate limiting, regex DoS
- a missing hardening measure with no attack path through its absence
- an environment variable or CLI flag as the attacker's input: those are
  trusted
- command injection in a shell script, unless untrusted input demonstrably
  reaches it — scripts run on trusted arguments
- a race or timing attack that is theoretical rather than constructible
- an outdated dependency; unit tests and fixtures; documentation
- user input in a log line, a regex, or an AI prompt; a URL in a log
- SSRF that controls only the path, not the host or scheme
- memory safety in a memory-safe language
- XSS in React or Angular without an unsafe sink
- missing checks in client-side code the server repeats
- a UUID as a guessable identifier

Read, grep and run what exists to confirm a path; never write an exploit into
the tree, and never run one against anything but a local, disposable target.
