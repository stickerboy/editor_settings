#################################################################################
# bash/.bashrc in https://github.com/stickerboy/editor_settings
#
# ~/.bashrc is one line that sources this file, so edits here are live. The
# aliases and functions are in .bashrc.d/ next to it. Machine-specific settings
# that shouldn't be published go in ~/.bashrc.local (see .bashrc.local.example).
#
# Performance note: starting a process costs ~50-100ms on this machine, so
# anything that runs at startup, on every prompt or on every cd sticks to bash
# builtins. Don't add $(...), pipes or external commands to those paths.
#
################################################################################

# In a login shell, cmder's /etc/profile.d/cmder.sh sources this file, then
# ~/.bash_profile sources it again. Skip the cmder.sh load: it runs before
# profile.d/git-prompt.sh, which would replace PS1 with cmder's prompt.
# Checks the whole chain, as H:\.bashrc sources this file when HOME isn't set.
if [[ " ${BASH_SOURCE[*]} " == *"/profile.d/cmder.sh "* ]]; then
	return
fi

# The folder this file is in, wherever the repo is cloned
BASHRC_DIR=${BASH_SOURCE[0]%/*}


# EXPORTS
################################################################################

# Use the local profile folder even when Windows points HOME at a network drive.
# C:\Users\name -> /c/Users/name, without starting cygpath.
if [ -n "$USERPROFILE" ]; then
	__home=${USERPROFILE//\\//}
	__drive=${__home%%:*}
	export HOME="/${__drive,,}${__home#*:}"
	unset __home __drive
fi

# Define colors
RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color


# Hooks run before every prompt
################################################################################

# Sets $__git_branch to "(branch)" by reading .git/HEAD directly, instead of
# running git on every prompt.
__git_branch_hook() {
	local dir=$PWD head
	__git_branch=
	while [ -n "$dir" ]; do
		if [ -f "$dir/.git/HEAD" ]; then
			head="$dir/.git/HEAD"
			break
		fi
		# Worktrees and submodules have a .git file pointing at the real git dir
		if [ -f "$dir/.git" ]; then
			read -r head < "$dir/.git"
			head=${head%$'\r'}
			head=${head#gitdir: }
			if [[ $head != /* && $head != ?:* ]]; then
				head="$dir/$head"
			fi
			head="$head/HEAD"
			break
		fi
		dir=${dir%/*}
	done
	if [ -z "$head" ] || [ ! -f "$head" ]; then
		return
	fi
	read -r head < "$head"
	case $head in
		"ref: refs/heads/"*)
			__git_branch="(${head#ref: refs/heads/})"
			;;
		*)
			# Detached HEAD: show the short SHA
			__git_branch="(${head:0:7})"
			;;
	esac
}

__prompt_hook() {
	# Write each command to the history file as it runs (see History below)
	history -a
	__nvmrc_hook
	__git_branch_hook
}

case $PROMPT_COMMAND in
	*__prompt_hook*)
		;;
	*)
		PROMPT_COMMAND="__prompt_hook${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
		;;
esac

# PROMPT_NAME is set in ~/.bashrc.local, which loads after this, so it's read
# when the prompt is drawn. Defaults to user@host.
export PS1="\n[\@ :: \[\e[32m\]\w] \n[\${PROMPT_NAME:-\u@\h}] \[\e[91m\]\${__git_branch}\[\e[00m\] $ "


# History
################################################################################
# Each Cmder tab appends to the history file as commands run (history -a in
# __prompt_hook), instead of the last tab to close overwriting the others. New
# tabs start with every tab's commands; open tabs keep their own until reopened.

shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000
# Skip commands starting with a space, and repeats of the previous command
HISTCONTROL=ignoreboth


# nvm
################################################################################
# Sourcing nvm.sh takes ~10s here and `nvm use` ~7s, so neither runs at
# startup or on cd. Node is put on PATH directly, following .nvmrc, and the
# real nvm only loads the first time you type `nvm`.

export NVM_DIR="$HOME/.nvm"

nvm() {
	unset -f nvm
	# --no-use stops nvm switching back to default over the .nvmrc version
	. "$NVM_DIR/nvm.sh" --no-use
	if [ -s "$NVM_DIR/bash_completion" ]; then
		. "$NVM_DIR/bash_completion"
	fi
	nvm "$@"
}

# True if version $1 is newer than $2 (both like 24.17.0)
__ver_gt() {
	local IFS=. i
	local -a a=($1) b=($2)
	for i in 0 1 2; do
		if (( ${a[i]:-0} != ${b[i]:-0} )); then
			(( ${a[i]:-0} > ${b[i]:-0} ))
			return
		fi
	done
	return 1
}

# Resolves an .nvmrc value (24.17.0, v24, 22, gcu, default, lts/iron) to an
# installed version folder such as v24.17.0, stored in $__nvm_resolved.
# Returns 1 if it isn't installed or is something only nvm understands.
__nvm_resolve() {
	local want=$1 hops=0 d v best=
	__nvm_resolved=
	while (( hops++ < 10 )); do
		want=${want#v}
		if [ -d "$NVM_DIR/versions/node/v$want" ]; then
			__nvm_resolved="v$want"
			return 0
		fi
		if [ -f "$NVM_DIR/alias/$want" ]; then
			read -r want < "$NVM_DIR/alias/$want"
			want=${want%$'\r'}
			continue
		fi
		break
	done
	# Partial version (24 or 24.1): pick the newest installed match
	if [[ $want =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
		for d in "$NVM_DIR/versions/node/v$want".*; do
			if [ ! -d "$d" ]; then
				continue
			fi
			v=${d##*/v}
			if [ -z "$best" ] || __ver_gt "$v" "$best"; then
				best=$v
			fi
		done
		if [ -n "$best" ]; then
			__nvm_resolved="v$best"
			return 0
		fi
	fi
	return 1
}

# Puts node version $1 (e.g. v24.17.0) first on PATH, removing any other.
__nvm_set_path() {
	local bin="$NVM_DIR/versions/node/$1/bin" rest="$PATH:" p out=
	while [ -n "$rest" ]; do
		p=${rest%%:*}
		rest=${rest#*:}
		case $p in
			"$NVM_DIR"/versions/node/*)
				;;
			*)
				out+=${out:+:}$p
				;;
		esac
	done
	export PATH="$bin${out:+:$out}"
	export NVM_BIN=$bin
	__nvm_active=$1
}

# On directory change, use the nearest .nvmrc (this folder or a parent), or
# the nvm default outside any project.
__nvmrc_hook() {
	if [ "$PWD" = "$__nvmrc_pwd" ]; then
		return
	fi
	__nvmrc_pwd=$PWD

	local dir=$PWD want=default previous=$__nvm_active
	# Stops before / itself: the Git for Windows root has a stray .nvmrc
	while [ -n "$dir" ]; do
		if [ -f "$dir/.nvmrc" ]; then
			read -r want < "$dir/.nvmrc"
			want=${want//[[:space:]]/}
			break
		fi
		dir=${dir%/*}
	done

	if [ "$want" = "$__nvmrc_want" ]; then
		return
	fi
	__nvmrc_want=$want

	if __nvm_resolve "$want"; then
		__nvm_set_path "$__nvm_resolved"
		if [ -n "$previous" ] && [ "$previous" != "$__nvm_active" ]; then
			echo "Switched to node $__nvm_active"
		fi
	elif [[ ${want#v} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && __nvm_resolve "${want%%.*}"; then
		# Exact version missing: use the newest installed one with the same major
		__nvm_set_path "$__nvm_resolved"
		echo "Node $want from .nvmrc isn't installed, using $__nvm_active (nvm install $want to get it)"
	elif __nvm_resolve default; then
		# Nothing installed matches: use the default rather than load nvm
		__nvm_set_path "$__nvm_resolved"
		echo "Node '$want' from .nvmrc isn't installed, using default $__nvm_active (nvm install $want to get it)"
	else
		echo "Node '$want' from $dir/.nvmrc isn't installed, loading nvm..."
		nvm use "$want"
	fi
}

# Run once now so node is on PATH in non-interactive shells too
__nvmrc_hook


# SSH stuff
################################################################################
# Reuses the running agent, or starts one. Keys aren't added at startup:
# AddKeysToAgent in ~/.ssh/config adds them the first time ssh or git needs
# one, asking for the passphrase once, so opening a terminal never waits on it.

SSH_ENV="$HOME/.ssh/environment"

# Checks the PID really is ssh-agent: after a reboot the saved PID can belong
# to some other process. (exename has no trailing newline, so read "fails".)
__ssh_agent_alive() {
	local exe=
	if [ -z "$SSH_AGENT_PID" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
		return 1
	fi
	# 2> first: a failed < redirect is reported before later redirects apply
	read -r exe 2> /dev/null < "/proc/$SSH_AGENT_PID/exename"
	[[ $exe == */ssh-agent ]]
}

start_agent() {
	echo "Initializing new SSH agent..."
	ssh-agent -s > "$SSH_ENV"
	. "$SSH_ENV" > /dev/null
}

if ! __ssh_agent_alive; then
	if [ -f "$SSH_ENV" ]; then
		. "$SSH_ENV" > /dev/null
	fi
	if ! __ssh_agent_alive; then
		start_agent
	fi
fi

# Add keys up front, the way the old startup did
function sshkeys() {
	ssh-add ~/.ssh/*_rsa
}


# Aliases and functions
################################################################################
# utils.sh, git.sh, npm.sh, release.sh and dxp.sh. Each file costs about 1ms.
# ~/.bashrc.local comes first, as the other files can use its settings.

if [ -f ~/.bashrc.local ]; then
	. ~/.bashrc.local
fi
for __f in "$BASHRC_DIR"/.bashrc.d/*.sh; do
	. "$__f"
done
unset __f
