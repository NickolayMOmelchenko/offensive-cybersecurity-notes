# tmux

Terminal multiplexer. Two reasons it matters on an engagement: anything started inside tmux **survives a dropped VPN or SSH**, and one screen can hold scan + shell + listener + notes.

`prefix` is **`Ctrl-b`** by default. `prefix X` = press and release `Ctrl-b`, then press `X`.

## Essential

### Sessions — survive a dropped connection

| Goal | Command |
| --- | --- |
| New named session | `tmux new -s acme-ept` |
| New, detached (don't attach) | `tmux new -s scan -d` |
| List sessions | `tmux ls` |
| Attach | `tmux a -t acme-ept` |
| **Detach, leave everything running** | `prefix d` |
| Kill a session | `tmux kill-session -t scan` |

Start every long scan this way: `tmux new -s scan` → run `nmap -p-` → `prefix d`. The VPN can die; the scan won't.

### Panes — 2 and 4

| Want | Do this |
| --- | --- |
| **2 side by side** | `prefix %` |
| **2 stacked** | `prefix "` |
| **4 in a grid** | `prefix %` → `prefix "` → `prefix ;` → `prefix "` → `prefix M-5` |
| 4, don't care how it gets there | `prefix %` `prefix "` `prefix "` then `prefix M-5` to tidy |
| Split to an exact size | `tmux split-window -h -l 30%` |
| Split in the same directory | `tmux split-window -v -c "#{pane_current_path}"` |
| 4 panes in one command | `tmux new -d -s q \; split-window -h \; split-window -v \; select-pane -t 0 \; split-window -v \; select-layout tiled \; attach` |

> ⚠️ tmux calls `%` the *horizontal* split and it gives **left/right**; `"` is *vertical* and gives **top/bottom**. The flag names how panes are arranged, not the divider. Most people rebind to `|` and `-` — see [Config](#config).

### Layouts

| Key | Layout |
| --- | --- |
| `prefix M-1` | all side by side (`even-horizontal`) |
| `prefix M-2` | all stacked (`even-vertical`) |
| `prefix M-3` | one big on top (`main-horizontal`) |
| `prefix M-4` | one big on left (`main-vertical`) |
| **`prefix M-5`** | **even grid (`tiled`) — the 2x2** |
| `prefix Space` | cycle layouts |
| `prefix E` | spread current panes evenly |

`M-` is Alt. On macOS enable *Option as Meta* in iTerm/Terminal, or use `prefix :` then `select-layout tiled`.

### Naming

| Level | Key | CLI |
| --- | --- | --- |
| Session | `prefix $` | `tmux rename-session -t old new` |
| Window | `prefix ,` | `tmux rename-window recon` |
| Pane | `prefix T` | `tmux select-pane -T nmap` |
| Name at creation | — | `tmux new -s acme -n recon` / `tmux new-window -n ad` |

Two gotchas:

| Problem | Fix |
| --- | --- |
| Pane names don't show at all | `tmux setw -g pane-border-status top` + `tmux setw -g pane-border-format ' #{pane_index}: #{pane_title} '` |
| Window renames itself to the running command | `prefix ,` pins that window; `tmux set -g automatic-rename off` for all |

### Moving around

| Key | Does |
| --- | --- |
| `prefix ←↑↓→` | select pane in that direction |
| `prefix o` | next pane |
| **`prefix ;`** | **previously active pane (toggle)** |
| `prefix q` then a number | jump to that pane |
| `prefix n` / `prefix p` | next / previous window |
| `prefix 0`…`9` | window by number |
| `prefix w` / `prefix s` | pick a window / session from a list |

### Zoom, resize, close

| Key | Does |
| --- | --- |
| **`prefix z`** | **zoom active pane fullscreen (toggle) — the most useful binding** |
| `prefix C-←↑↓→` | resize by 1 |
| `prefix M-←↑↓→` | resize by 5 |
| `prefix x` / `prefix &` | kill pane / kill window |

A grid is for watching. To *read* 200 lines of nmap output, zoom.

### Scrollback and logging

| Goal | Do this |
| --- | --- |
| Scroll back | `prefix [`, then arrows / PgUp — `q` to leave |
| Search the scrollback | in `prefix [`: `/text` forward, `?text` back, `n`/`N` to step |
| Paste | `prefix ]` |
| Bigger buffer | `tmux set -g history-limit 50000` |
| **Log a pane to a file** | `tmux pipe-pane -o 'cat >> logs/tmux-#W-#P.log'` (`-o` toggles) |

`pipe-pane` feeds the `logs/` convention in the engagement scaffold from `scripts/new-engagement.sh`.

## Occasional — niche, but there's a use case

| Feature | How | Use case |
| --- | --- | --- |
| Sync panes | `tmux setw synchronize-panes on` (no default binding) | Type once into 4 SSH panes. Also a way to break 4 hosts at once — turn it off immediately |
| Break pane out | `prefix !` | The scan you split off now deserves a whole window |
| Swap / rotate panes | `prefix {` `prefix }` / `prefix C-o` | Rearrange without re-splitting |
| Pull a pane in | `tmux join-pane -s acme:scan.0 -t acme:recon` | Consolidate windows |
| Drive a pane from outside | `tmux send-keys -t acme:recon.0 'nmap ...' C-m` | Scripted workspaces; `session:window.pane` targeting |
| Mouse mode | `tmux set -g mouse on` | Click panes, drag borders. Hold **Shift** to select text normally |
| Shared session | `tmux -S /tmp/pair new -s pair` + `chgrp`/`chmod 770`; attach with `-r` for read-only | Hand a live foothold to a teammate. Socket perms *are* the access control |
| Nested tmux | `C-b C-b` passes the prefix inward | You tmux'd into a box already running tmux |
| Survive a reboot | tpm plugins `tmux-resurrect` / `tmux-continuum` | Long-lived engagement box; overkill for HTB |

## Config

```tmux
# ~/.tmux.conf
set  -g history-limit 50000
set  -g base-index 1              # windows start at 1, matching the number keys
setw -g pane-base-index 1
set  -g renumber-windows on
set  -g mouse on
setw -g pane-border-status top
setw -g pane-border-format ' #{pane_index}: #{pane_title} '

bind | split-window -h            # splits that match their glyph
bind - split-window -v
bind S setw synchronize-panes     # no default binding exists
bind r source-file ~/.tmux.conf \; display "reloaded"
```

Reload live: `prefix :` then `source-file ~/.tmux.conf`. List every binding on any box: `prefix ?`.

## Blue team note

A stray tmux/screen server is how a long job outlives its shell, and a triage signal: check `ps -ef | grep -E '[t]mux|[s]creen'` and `/tmp/tmux-<uid>/`. A tmux server owned by a **service account that should never have an interactive session** is worth investigating. tmux is not reboot persistence by itself. See [Host-based logging on Linux](../../Defense/Logging/Host-based/Linux.md).

## Related

[vim](vim.md) · [Metasploit](Metasploit.md) · [folder README](README.md) · [Remote Access & Getting a Shell](../Networking/Remote%20Access%20%26%20Getting%20a%20Shell.md) · [Pivoting & Tunneling](../Networking/Pivoting%20%26%20Tunneling.md) · engagement scaffold: `scripts/new-engagement.sh`
