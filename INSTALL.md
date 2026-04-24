# Installation

Three options, from most automated to most manual.

## Option 1 - Let Claude Code do it

Paste this bellow prompt into any Claude Code session. It will download the script, install it, and merge the `settings.json` entry without clobbering existing keys.

````text
Install the Claude Code statusline from https://github.com/mivancic/claude-statusline:

1. Download `statusline-command.sh` from that repo's raw URL to `~/.claude/statusline-command.sh` and `chmod +x` it.
2. **Merge** (do not overwrite) this block into `~/.claude/settings.json` at the top level — preserve all existing keys:

   ```json
   "statusLine": {
     "type": "command",
     "command": "~/.claude/statusline-command.sh"
   }
   ```

3. Make sure `jq` is installed. If missing, detect the user's package manager (`brew`, `port`, `apt`, `dnf`, `pacman`, `zypper`, etc.) by checking what's on `PATH` and reading `/etc/os-release` on Linux, then install `jq` using the appropriate command. If you can't determine the right manager, ask the user which one they use before installing.
````

Claude will prompt you to approve the file writes - say yes. Restart any running Claude Code sessions (or open a new cmux/terminal pane) to pick up the new status line.

## Option 2 - One-liner in your terminal

```bash
curl -fsSL https://raw.githubusercontent.com/mivancic/claude-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh && \
chmod +x ~/.claude/statusline-command.sh && \
( [ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json ) && \
jq '. + {statusLine: {type: "command", command: "~/.claude/statusline-command.sh"}}' \
  ~/.claude/settings.json > ~/.claude/settings.json.tmp && \
mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

Requires `jq` on your machine. The `jq '. + {...}'` merge preserves every existing key in `settings.json`.

## Option 3 - Manual

1. Install `jq` if missing: `brew install jq` or `apt install jq`.
2. Copy `statusline-command.sh` to `~/.claude/`:

```bash
 mkdir -p ~/.claude
 cp statusline-command.sh ~/.claude/statusline-command.sh
 chmod +x ~/.claude/statusline-command.sh
```

3. Open `~/.claude/settings.json` in your editor and add the `statusLine` block at the top level. Example with some existing keys preserved:

```json
{
  "model": "sonnet",
  "effortLevel": "medium",
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

4. Restart Claude Code (or open a new pane). The status line appears after your first message.

## Verify it works

Pipe a fake payload through the script to confirm it renders:

```bash
echo '{
  "version":"2.1.117",
  "model":{"display_name":"Sonnet 4.6"},
  "workspace":{"project_dir":"'"$HOME"'"},
  "context_window":{"used_percentage":42,"total_input_tokens":540,"total_output_tokens":17922,"current_usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":300,"cache_read_input_tokens":40000}},
  "rate_limits":{"five_hour":{"used_percentage":28,"resets_at":'"$(($(date +%s)+3600))"'},"seven_day":{"used_percentage":8,"resets_at":'"$(($(date +%s)+7*86400))"'}}
}' | ~/.claude/statusline-command.sh
```

You should see two colored lines. If you see no colors, your terminal may not support 256-color ANSI - check `echo $TERM` (should be `xterm-256color` or similar).

## Troubleshooting

**No status line at all.** Check `~/.claude/settings.json` is valid JSON: `jq . ~/.claude/settings.json`. Restart Claude Code fully.

**Rate-limit sections missing.** They only appear after Claude Code receives its first API response in the session. Send a message and they'll populate.

**All segments yellow/olive.** Your terminal is remapping ANSI green. The script uses 256-color codes that should bypass this, but some very old terminals or strict themes override them. Swap `\033[38;5;46m` for a different green code in `statusline-command.sh`.

**Email not shown or shows `$USER`.** The script reads `.oauthAccount.emailAddress` from `~/.claude.json`. If you've never signed into Claude Code, that file won't have the field and it falls back to the system username.

**Branch not shown.** The script only renders branch when `workspace.project_dir` is a git repo. Verify with `git -C <your-project-dir> branch --show-current`.

**Extra-usage credits not shown.** Credits only render when your account has `overageCreditGrantCache[<org>].info.granted = true`. If you've enabled extra usage but no credits have been granted (e.g. you haven't gone over), the segment stays hidden.

## Uninstall

```bash
jq 'del(.statusLine)' ~/.claude/settings.json > ~/.claude/settings.json.tmp && \
mv ~/.claude/settings.json.tmp ~/.claude/settings.json && \
rm -f ~/.claude/statusline-command.sh
```
