# Agent Status

See every open Claude Code and Codex session at a glance, directly in the
Omarchy bar. Each session gets its own chip with the agent mark, session name
and live working or ready state.

![Claude Code ready, Codex working, and Codex ready](chip-states.png)

**Supported agents:** Claude Code and Codex. No other coding agents are
detected.

## Install

Agent Status requires Omarchy 4 (Quattro) and a horizontal bar.

```bash
omarchy plugin add https://github.com/mae240/omarchy-agent-status.git --enable
```

The widget is added to the left side of the bar, next to the workspaces. Move
it to another section at any time:

```bash
omarchy bar move io.github.mae240.agent-status --section right
```

### Configure Codex

Claude Code works immediately. Codex needs its terminal title configured so
the chip remains visible after a run finishes. Add this to
`~/.codex/config.toml`:

```toml
[tui]
terminal_title = ["run-state", "thread-title", "project-name"]
```

Restart any Codex sessions that were already open. Without this setting, a
Codex chip is visible only while the session is working and disappears when it
becomes idle.

## Using the widget

| State | Appearance |
|-------|------------|
| Working | Spinning arc with a dimmed mark and session name |
| Ready | Closed ring and checkmark, with a short green pulse when the run finishes |
| Attention | Breathing ring and exclamation mark in the theme's urgent color |

- Click a chip to focus its terminal window.
- Hover a chip to see the agent, full session name, project and state.
- Open sessions beyond `maxSessions` collapse into a `+n` chip; its tooltip
  lists the hidden sessions.
- Labels shrink and elide automatically so the widget cannot overlap the
  centered clock.
- The widget hides itself when no supported session is open and on vertical
  bars.

## Settings

Change settings from the widget settings panel, with `omarchy bar set`, or in
the widget entry inside `~/.config/omarchy/shell.json`.

| Key | Default | Description |
|-----|---------|-------------|
| `maxWidth` | `180` | Maximum session-label width in pixels (60–480) |
| `maxSessions` | `4` | Maximum visible session chips before `+n` (1–12) |
| `doneColor` | `#4ade80` | Ring, checkmark and pulse when ready |
| `attentionColor` | theme | Ring and exclamation mark when attention is needed |
| `claudeColor` | `#d97757` | Claude mark color |
| `codexColor` | bar text | Codex mark color |
| `extraAppIds` | empty | Additional comma-separated terminal app IDs |

Colors accept `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)` and theme roles
such as `accent`, `urgent` or `foreground`. Invalid colors fall back to their
defaults; numeric values are clamped to the documented ranges.

## How detection works

Agent Status does not run commands, poll processes or contact either agent. It
reads the titles of open terminal windows from Quickshell's toplevel list.

### Claude Code

Claude Code places a state glyph and session name in its terminal title:

| Terminal title | State |
|----------------|-------|
| `◐ my-session` | Working |
| `✳ my-session` | Ready |

These glyphs are input signals only. The widget renders the Claude mark and
status ring shown in the preview instead of displaying the title glyph.

Claude Code does not expose approval prompts separately, so a session waiting
for approval can still look like it is working. Inside tmux, screen or zellij,
Claude Code uses a static ready glyph and therefore always appears ready.

### Codex

With the configuration shown above, Codex titles follow this pattern:

```text
<run state> | <thread title> | <project>
```

`Working` appears as working; `Ready`, `Idle` and `Done` appear as ready;
`Waiting`, `Blocked` and `Approval` appear as attention. Until Codex names a
thread, the chip is labeled `Codex`.

Codex currently reports `Working` while an approval prompt is open. Its
attention state is therefore most commonly seen while it waits for a
background terminal.

### Terminal filtering

The widget reads terminals launched by `omarchy-launch-tui`, the terminals
shipped with Omarchy (foot, Alacritty, Ghostty, kitty and WezTerm), and windows
with the app IDs `claude` or `codex`. Other applications are ignored even when
their titles resemble an agent session. Add a custom terminal app ID with the
`extraAppIds` setting.

## Limitations

- Only Claude Code and Codex are supported.
- Approval prompts are not reliably distinguishable from active work.
- Terminal multiplexers must pass pane titles through to the window title;
  Claude Code sessions inside a multiplexer always appear ready.
- The widget shows session state, not usage or rate limits. Use the built-in
  `omarchy.agents` widget for account usage.

## Remove

```bash
omarchy plugin remove io.github.mae240.agent-status
```

This disables the widget, removes its entry from
`~/.config/omarchy/shell.json` and deletes the plugin directory. The plugin
writes nothing else to the system.

## Upgrade from `mae.agent-status`

Versions before 2.1.0 used the ID `mae.agent-status`. Replace the old plugin
with the current one:

```bash
omarchy plugin remove mae.agent-status
omarchy plugin add https://github.com/mae240/omarchy-agent-status.git --enable
```

## Development

```bash
git clone https://github.com/mae240/omarchy-agent-status.git \
  ~/.config/omarchy/plugins/io.github.mae240.agent-status
omarchy plugin validate ~/.config/omarchy/plugins/io.github.mae240.agent-status
omarchy plugin enable io.github.mae240.agent-status
```

Detection lives in `sessionFor(title, appId)` in `AgentStatus.qml`. It returns
either a Claude Code or Codex session with a `busy`, `ready` or `attention`
state. Supporting another agent requires a new detection branch and a mark in
`AgentMark.qml`; contributions are welcome.

After changing QML, run `omarchy restart shell`. Plugin-file hot reload is not
reliable in every shell version.

## License

[MIT](LICENSE). The Claude and OpenAI marks in `AgentMark.qml` are the vendors'
own trademarks and are used only to identify their products.
