# Version branches, changelogs and pull requests for package.json projects.
# Sourced by .bashrc. The work is done by node/release.mjs; these are wrappers.

# `command node` skips cmder's `node` alias (winpty), which breaks prompts here
function __release() {
	command node "$BASHRC_DIR/.bashrc.d/node/release.mjs" "$@"
}

function ver() { __release version; }
function setver() { __release set "$@"; }
function nver() { __release bump "$@"; }
function brs() { __release branch "$@"; }

# Open a PR to main using the changelog. `pr --dry-run` shows the gh command
function pr() { __release pr "$@"; }

# Check the branch name is v-<package.json version>, without pushing
function vcheck() { __release check-branch --report; }

# Push, after checking the branch name matches the package.json version.
# Pass a command to run instead of `git push`: compare_and_push upstream
function compare_and_push() {
	__release check-branch || return
	if [ -n "$1" ]; then
		eval "$1"
	else
		git push
	fi
}
alias cpush="compare_and_push"
alias cpish="cpush"
alias cupstream="compare_and_push upstream"

# Old names
alias get_version="ver"
alias set_version="setver"
alias increment_version="nver"
alias create_new_branch="brs"
alias pull_request="pr"
