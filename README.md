<p align="center">
  <img alt="codex-naked Banner" src="docs/assets/codex-naked-banner.png" width="900">
</p>

<p align="center">
  <a href="https://github.com/AndreRatzenberger/codex-naked/stargazers"><img src="https://img.shields.io/github/stars/AndreRatzenberger/codex-naked?style=flat-square" alt="GitHub stars"></a>
  <a href="https://github.com/AndreRatzenberger/codex-naked/commits/main"><img src="https://img.shields.io/github/last-commit/AndreRatzenberger/codex-naked?style=flat-square" alt="Last commit"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/AndreRatzenberger/codex-naked?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <em>"codex with no baggage"</em>
</p>


You wanna test a Codex skill, but Codex keeps pulling random prior knowledge
out of the walls and bamboozling your eval? Then this is for you.

**codex-naked** starts Codex in a clean little room. It wipes the disposable
Codex home, wipes the disposable user home, copies just enough auth to log in,
and launches Codex without your usual local lore leaking into the run.

Think of it as **fresh socks for Codex**. Same CLI. Less haunted attic.

---

## Quick Strip

**1. Install the little context broom**

```bash
curl -fsSL https://raw.githubusercontent.com/AndreRatzenberger/codex-naked/main/install.sh | sh
```

Or from a clone:

```bash
make install
```

**2. Start clean**

```bash
codex-naked
```

That is the whole trick. No flags to remember.

**What just happened?**

- `~/.codex-naked` got wiped and recreated as the naked `CODEX_HOME`.
- `~/.codex-naked-home` got wiped and recreated as the naked `HOME`.
- `~/.codex/auth.json` got copied in, so login still works.
- Codex started with the clean homes.

Every plain `codex-naked` run is fresh. Yesterday's weird test sludge goes in
the bin.

---

## Keep The Weird Room

Sometimes you do want the naked home to survive. Maybe you are testing a spec
kit across several sessions. Maybe the whole point is "can this thing learn
inside this tiny box?"

Use `--keep`:

```bash
codex-naked --keep
```

Same isolation. No wipe.

---

## Yolo, But Naked

Need the classic Codex yolo mode inside the clean room?

```bash
codex-naked --yolo
```

That forwards:

```text
--dangerously-bypass-approvals-and-sandbox
```

Sharp object warning: this is still yolo. It just happens in the naked homes.
Do not confuse "less context" with "safe."

---

## Skill Test Recipe

Want to test one skill without the rest of your skill zoo barging in?

```bash
tmp="$(mktemp -d)"
cp /path/to/skill/SKILL.md "$tmp/AGENTS.md"
cd "$tmp"

codex-naked exec --skip-git-repo-check --ephemeral "Use the skill."
```

Now the only project instruction is the skill you copied into `AGENTS.md`.
Your normal `~/.agents/skills`, repo rules, memories, plugins, and habit soup
stay outside the room.

For prompt-input inspection without auth:

```bash
codex-naked --auth none debug prompt-input "probe"
```

For a non-interactive clean job:

```bash
codex-naked exec --skip-git-repo-check --ephemeral \
  --ignore-rules -s read-only "say hi"
```

---

## Why Not Just Codex Flags?

Codex already has useful flags:

```text
--ephemeral
--ignore-user-config
--ignore-rules
```

Those are good. Use them.

But they do not solve the whole leak. Codex can also discover personal skills
from:

```text
$HOME/.agents/skills
```

So a clean `CODEX_HOME` removes `~/.codex` context, but your real `HOME` can
still sneak in through the side door.

`codex-naked` isolates both:

```text
CODEX_HOME -> ~/.codex-naked
HOME       -> ~/.codex-naked-home
```

That is the useful bit.

---

## What It Is Not

`codex-naked` is **context isolation**, not a security sandbox.

Use it when you want to answer:

- "Does this skill work without my personal memory helping?"
- "Is this benchmark clean, or did my setup leak the answer?"
- "Does this prompt stand on its own feet?"
- "Which instruction source is actually causing the behavior?"

Do not use it as a substitute for:

- containers
- Bubblewrap
- VM isolation
- Codex sandboxing
- common sense around yolo mode

The tool removes your local bias soup. It does not make arbitrary code safe.

---

## Options

```text
--keep              Reuse existing naked homes instead of wiping them.
--clean             Wipe both naked homes before launch (default).
--clean-codex-home  Wipe only the naked CODEX_HOME before launch.
--clean-user-home   Wipe only the isolated HOME before launch.
--codex-home DIR    Use DIR as the naked CODEX_HOME.
--home DIR          Alias for --codex-home.
--user-home DIR     Use DIR as the isolated HOME.
--real DIR          Source Codex home to read auth from.
--auth MODE         Auth handling: copy, symlink, or none.
--yolo              Start Codex with --dangerously-bypass-approvals-and-sandbox.
--keep-home         Do not isolate HOME. Legacy mode; ~/.agents may leak.
--print-env         Print the resolved homes and exit.
--version           Print version and exit.
```

Inspect the resolved setup:

```bash
codex-naked --print-env
```

---

## Auth Modes

`copy` is the default:

```bash
codex-naked --auth copy
```

It copies `auth.json` from your real Codex home into the naked `CODEX_HOME` on
every run. Simple, disposable, works for normal use.

`symlink` tracks token refreshes:

```bash
codex-naked --auth symlink
```

It links naked `auth.json` to the real file. This avoids stale copied auth, but
the naked Codex process shares the real auth file.

`none` provides no auth:

```bash
codex-naked --auth none debug prompt-input "probe"
```

It removes any stale naked `auth.json`. Use it with `CODEX_API_KEY`,
`CODEX_ACCESS_TOKEN`, or for sterile prompt-input inspection that should not be
able to authenticate.

---

## Defaults

```text
Real Codex home:    ~/.codex
Naked Codex home:   ~/.codex-naked
Naked user home:    ~/.codex-naked-home
Auth mode:          copy
HOME isolation:     on
Cleanup:            on
```

Environment overrides:

```text
CODEX_HOME_REAL
CODEX_NAKED_CODEX_HOME
CODEX_NAKED_HOME
CODEX_NAKED_USER_HOME
CODEX_NAKED_AUTH
```

---

## Claude Too: `claude-naked`

Same trick, different agent. Ships in this repo as a sibling binary.

```bash
claude-naked
```

- `~/.claude-naked` got wiped and recreated as the naked `CLAUDE_CONFIG_DIR`.
- `~/.claude-naked-home` got wiped and recreated as the naked `HOME`.
- `~/.claude/.credentials.json` got copied in, so login still works.
- Claude Code started with the clean homes, **in bypass mode**.

The nice surprise: `CLAUDE_CONFIG_DIR` relocates both `.claude/` **and**
`.claude.json`, so one variable takes the whole config with it. HOME isolation
is the second layer — it also catches XDG caches, MCP server state, and shell
snapshots.

**Bypass is on by default here.** That is the one deliberate difference from
`codex-naked`, where `--yolo` is opt-in. A naked home has no settings, no
hooks and no allowlists, so every single action would otherwise prompt, and a
disposable room you have to babysit is not a disposable room. It forwards:

```text
--dangerously-skip-permissions
```

Same sharp-object warning as before: less context is not the same as safe.

Want the prompts back — for example to test the permission flow itself?

```bash
claude-naked --no-yolo
```

### Skill test recipe

```bash
tmp="$(mktemp -d)"
mkdir -p "$tmp/.claude/skills/thing"
cp /path/to/skill/SKILL.md "$tmp/.claude/skills/thing/SKILL.md"
cd "$tmp"

claude-naked -p "Use the thing skill."
```

The only skill in the room is the one you put there. Your real skills,
plugins, hooks, memories, `CLAUDE.md` files and MCP servers stay outside.

### Options

```text
--keep              Reuse existing naked homes instead of wiping them.
--clean             Wipe both naked homes before launch (default).
--clean-config-dir  Wipe only the naked CLAUDE_CONFIG_DIR before launch.
--clean-user-home   Wipe only the isolated HOME before launch.
--config-dir DIR    Use DIR as the naked CLAUDE_CONFIG_DIR.
--home DIR          Alias for --config-dir.
--user-home DIR     Use DIR as the isolated HOME.
--real DIR          Source Claude home to read auth from.
--auth MODE         Auth handling: copy, symlink, or none.
--yolo              Start Claude with --dangerously-skip-permissions (default).
--no-yolo           Do not pass --dangerously-skip-permissions.
--keep-home         Do not isolate HOME. Config is still isolated.
--print-env         Print the resolved homes and exit.
--version           Print version and exit.
```

### Defaults

```text
Real Claude home:   ~/.claude
Naked config dir:   ~/.claude-naked
Naked user home:    ~/.claude-naked-home
Auth mode:          copy
HOME isolation:     on
Cleanup:            on
Bypass mode:        on
```

Environment overrides:

```text
CLAUDE_HOME_REAL
CLAUDE_NAKED_CONFIG_DIR
CLAUDE_NAKED_HOME
CLAUDE_NAKED_USER_HOME
CLAUDE_NAKED_AUTH
```

Auth modes work exactly as they do for Codex, except the file is
`.credentials.json` instead of `auth.json`, and `none` pairs with
`ANTHROPIC_API_KEY`.

---

## Development

Run the quality gate:

```bash
make check
```

That lints and tests both binaries. Individual suites:

```bash
make test-codex
make test-claude
```

The tests use fake `codex` and `claude` executables and verify the environment
contract without making live model calls.
