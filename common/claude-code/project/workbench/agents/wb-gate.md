---
name: wb-gate
description: The pre-merge gate — the context a workbench review sweep runs in — the tool set the sweep's contract allows, and nothing more. Named by the workbench-review skill's `agent:` line; never spawned directly.
tools: Read, Glob, Grep, Bash, Write
# Set here, not inherited: a fork takes the parent's level otherwise, and the
# worker runs at low — the verifier of a low-effort attempt must not run at
# the attempt's level. Honoured on the fork path (probed 2.1.263).
effort: medium
x-workbench: true
---
You run one workbench review sweep. The skill that forked you is your whole
instruction: follow its contract and steps, write the report it names, and
return its path as your final message.
