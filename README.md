# editor_settings

Some of my settings between bash, PowerShell and VS Code, on Windows with Git for Windows.

## Folders

| Folder | What's in it | How it's used |
|---|---|---|
| `bash/` | `.bashrc`, `.bash_profile`, and `.bashrc.d/` with the aliases and functions | Live: `~/.bashrc` sources `bash/.bashrc` from this repo |
| `vscode/` | `settings.json`, `keybindings.json` | Copied in by `dotsync` |
| `powershell/` | `Microsoft.PowerShell_profile.ps1` | Copied in by `dotsync` |

### `bash/.bashrc.d/`

| File | Contents |
|---|---|
| `utils.sh` | Profile editing, files and folders, clipboard, network, `dotsync` |
| `git.sh` | Git aliases and functions (`reset` and `clean` ask before discarding anything) |
| `npm.sh` | npm, node and Eleventy |
| `release.sh` | Version bumps, release branches, changelogs and PRs (`ver`, `nver`, `brs`, `pr`, `vcheck`...), run by `node/release.mjs` |
| `dxp.sh` | Squiz DXP components and page layouts |

## Setup

1. Clone this repo, for example to `C:\dev\editor_settings`.
2. Make `~/.bashrc` load it:
   ```bash
   echo '. /c/dev/editor_settings/bash/.bashrc' > ~/.bashrc
   ```
   `~/.bash_profile` should source `~/.bashrc`; `bash/.bash_profile` does.
3. Copy `bash/.bashrc.local.example` to `~/.bashrc.local` and fill it in. It holds machine- and work-specific settings, and isn't committed.

## Keeping it up to date

- **Bash:** edit the files here (`bashme`, `bashme git`, `bashme local`), then `bashed` to reload.
- **VS Code and PowerShell:** run `dotsync` to copy the current files in. It leaves out lines that look like credentials (access keys, tokens, passwords, BrowserStack settings), so check `git diff` before committing.

## Speed

Starting a process takes 50–100 ms on Windows, so anything that runs at startup, at every prompt or on `cd` uses bash builtins only. nvm isn't loaded until you type `nvm`: a prompt hook reads the nearest `.nvmrc` and puts that node version on `PATH` directly. The git branch in the prompt is read from `.git/HEAD`. Opening a terminal takes about a second.
