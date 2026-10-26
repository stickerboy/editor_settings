# Editor settings

Some of my settings between bash, PowerShell and VS Code, on Windows with Git for Windows. Bash runs inside [Cmder](https://cmder.app/), and the setup is built around it (see [Cmder](#cmder)).

## Folders

| Folder | What's in it | How it's used |
|---|---|---|
| `bash/` | `.bashrc`, `.bash_profile`, and `.bashrc.d/` with the aliases and functions | Live: `~/.bashrc` sources `bash/.bashrc` from this repo |
| `vscode/` | `settings.json`, `keybindings.json` | Copied in by `dotsync` |
| `powershell/` | `Microsoft.PowerShell_profile.ps1` | Copied in by `dotsync` |

### `bash/.bashrc.d/`

| File | Contents |
|---|---|
| `utils.sh` | Profile editing, files and folders (`lsmod`, `ldir`, `dump`), clipboard (`pbcopy`, `pbpaste`, `cb`), network (`killport`), `dotsync` |
| `git.sh` | Git aliases and functions (`greset` and `gclean` fetch, then ask before discarding anything), and [tab completion](#git-completion) for the aliases |
| `npm.sh` | npm, node and Eleventy |
| `release.sh` | Version bumps, release branches, changelogs and PRs (`ver`, `nver`, `brs`, `pr`, `vcheck`...), run by `node/release.mjs` |
| `dxp.sh` | Squiz DXP components and page layouts |

## Requirements

### Core

The bash setup assumes these. Without them, startup or the prompt doesn't work properly.

| Tool | Version | Why |
|---|---|---|
| [Git for Windows](https://gitforwindows.org/) | Any recent (2.13+) | Supplies bash, `ssh-agent`, `vim`, `cygpath`, and MSYS's `/proc` and `/dev/clipboard`. Not WSL or plain MSYS2: `cygpath`, `MSYS2_ARG_CONV_EXCL`, `/proc/<pid>/exename` and `/dev/clipboard` are relied on. |
| Bash | 4+ (Git for Windows ships 5) | `${var,,}` and `[[ =~ ]]` in `.bashrc` |
| [Cmder](https://cmder.app/) | Any | The terminal this is set up for; see [Cmder](#cmder) |
| [nvm](https://github.com/nvm-sh/nvm) (nvm-sh, **not** nvm-windows) | Any | Installed at `~/.nvm`. The prompt hook reads `~/.nvm/versions/node/` and `~/.nvm/alias/` directly. |
| Node | 24+ | Recommended minimum. `node/release.mjs` has no dependencies, so it runs on whichever version `.nvmrc` picks. |

### Per command

These are only needed for the commands that use them.

| Commands | Needs |
|---|---|
| `pr` | [GitHub CLI](https://cli.github.com/) (`gh`), logged in with `gh auth login` |
| `ver`, `nver`, `brs`, `pr`, `vcheck`, `cpush` | A `package.json` with a `version`, and, for `brs` and `pr`, a `_templates/0.0.0.md` changelog template. Changelogs go in `changelog/<major>/<major>.<minor>/`, and PRs target `main`.<br>_This functionality was built for my [Convrtr project](https://github.com/convrtrjs)_|
| `dxpa`, `dxpinit`, `dxpdev`, `dxpnew`, `dxpl`, `deploy`, `dxpldeploy` | `dxp-next` from `@squiz/dxp-cli-next` (`dxpu` installs it). In `~/.bashrc.local`, `dxpa` needs `DXP_TENANT`, `dxpnew` needs `DXP_NAMESPACE`, and `dxpldeploy` needs `ENABLE_PAGE_LAYOUTS` (`dxp-next` requires it to deploy page layouts to Squiz Cloud). |
| `dxpreview` | `dxp-next`, plus [`dotenv-cli`](https://www.npmjs.com/package/dotenv-cli) installed globally (`ng dotenv-cli`) |
| `dxpv`, `deploy` | [`jq`](https://jqlang.org/) |
| `nae` | `audit-export`, installed globally for the current node |
| `11ty`, `11typrod` | Nothing global; `npx` fetches `@11ty/eleventy` |
| `dt` | [Microsoft Dev Tunnels CLI](https://learn.microsoft.com/azure/developer/dev-tunnels/get-started) (`devtunnel`) |
| `np`, `npbash` | Notepad++, in `C:\Program Files\Notepad++` or wherever `NOTEPADPP` in `~/.bashrc.local` points |
| `sshkeys` / key loading | Keys named `~/.ssh/*_rsa`. Set `AddKeysToAgent yes` in `~/.ssh/config` so keys load on first use. |
| PowerShell profile | PowerShell 7 (`Documents/PowerShell`, not `WindowsPowerShell`) and [Oh My Posh](https://ohmyposh.dev/) with `POSH_THEMES_PATH` set |

## Setup

1. Clone this repo, for example to `C:\dev\editor_settings`.
2. Make `~/.bashrc` load it:
   ```bash
   echo '. /c/dev/editor_settings/bash/.bashrc' > ~/.bashrc
   ```
   Git for Windows' default `~/.bash_profile` already sources `~/.bashrc`, so it needs no changes. (`bash/.bash_profile` is a copy, for reference.)
3. Copy `bash/.bashrc.local.example` to `~/.bashrc.local` and fill it in. It holds machine- and work-specific settings, and isn't committed.

## Cmder

The bash setup expects to run in Cmder's bash, and works around two things Cmder does:

- **Double loading:** in a login shell, Cmder's `/etc/profile.d/cmder.sh` sources `~/.bashrc`, and then `~/.bash_profile` sources it again. `bash/.bashrc` returns early when `cmder.sh` loads it. Otherwise it would run before Git's `profile.d/git-prompt.sh`, which would then replace the prompt.
- **`node` alias:** Cmder aliases `node` to run through winpty, which breaks interactive prompts. Scripts call `command node` to skip the alias.

Cmder's own config (tasks, ConEmu settings, `user_aliases`) isn't kept in this repo.

## Prompt

```
[12:47 PM :: /c/dev/editor_settings]
[digital@wizzard] (master) ✘ 1 $
```

- **Name:** `PROMPT_NAME` in `~/.bashrc.local`, or `user@host` if it isn't set.
- **Branch:** read from `.git/HEAD`, and a short SHA when HEAD is detached. Works in worktrees and submodules.
- **`✘ <code>`:** shown in red after a command fails. Not every non-zero code is an error. `grep` with no match, `diff` with differences, and answering `n` to `greset` or `dump` all return 1, and stopping a dev server with Ctrl-C returns 130. Others you might see: 127 (command not found) and 128 (git fatal error). Pressing Enter on an empty line keeps the last code.

## History

Bash normally writes history only when a shell exits, so with several Cmder tabs open, the last tab to close overwrites the others. Here, each command is appended to `~/.bash_history` as soon as it runs (`history -a` in the prompt hook), so nothing is lost.

- New tabs start with every tab's commands. Tabs that are already open keep their own history until they're reopened.
- Keeps 10,000 commands per session and 20,000 in the file.
- Commands starting with a space aren't saved, so you can keep a one-off command (or one with a secret in it) out of history. Neither are repeats of the previous command.

## Git completion

The git aliases tab-complete like the git commands they stand for, so `check feat<Tab>` offers `feature/login feature/menu`, and `log --onel<Tab>` gives `--oneline`.

| Aliases | Complete like |
|---|---|
| `check`, `checkout` | `git checkout` |
| `branch`, `db`, `dbl` | `git branch` |
| `merge`, `base`, `cherry`, `cherrypick`, `back` | `git merge`, `rebase`, `cherry-pick`, `reset` |
| `add`, `status`, `fetch`, `pull`, `tag`, `log`, `reflog`, `stash` | The matching git command |

This uses `__git_complete` from `git-completion.bash`, which Git for Windows' `/etc/profile.d/git-prompt.sh` already loads in login shells before `.bashrc`. So it adds about 9 ms to startup and loads nothing extra. It's skipped in shells where git completion isn't loaded, such as a non-login `bash -i`.

To add another alias, add a line to the Completion section at the end of `bash/.bashrc.d/git.sh`, for example `__git_complete sw _git_switch`.

## Keeping it up to date

- **Bash:** edit the files here (`bashme`, `bashme git`, `bashme local`), then `bashed` to reload.
- **Checking:** run [ShellCheck](https://www.shellcheck.net/) from the repo root (`winget install koalaman.shellcheck`). `.shellcheckrc` holds the settings, and a GitHub Action runs the same check on every push that changes `bash/`.
  ```bash
  shellcheck bash/.bashrc bash/.bash_profile bash/.bashrc.d/*.sh bash/.bashrc.local.example
  ```
- **VS Code and PowerShell:** run `dotsync` to copy the current files in. It leaves out lines that look like credentials (access keys, tokens, passwords, BrowserStack settings), and warns if any copied file contains your Windows username. The repo is public, so check `git diff` before committing.

## Speed

Starting a process takes 50–100 ms on Windows, so anything that runs at startup, at every prompt or on `cd` uses bash builtins only. nvm isn't loaded until you type `nvm`: a prompt hook reads the nearest `.nvmrc` and puts that node version on `PATH` directly. The git branch in the prompt is read from `.git/HEAD`. Opening a terminal takes about a second.
