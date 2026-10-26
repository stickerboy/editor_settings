# Git aliases and functions. Sourced by .bashrc.
# Release helpers (version branches, changelog, PRs) are in release.sh.

# Basics
################################################################################

alias init="git init"
alias add="git add"
alias status="git status"
alias fetch="git fetch"
alias pull="git pull"
alias clone="git clone"
alias merge="git merge"
alias tag="git tag"
alias tags="git push --tags"
alias commit="git commit -m"
alias amend="git commit --amend -m"
alias ignore="vim .gitignore"
alias base="git rebase -i"

function clonecd() {
	echo "Cloning repository and entering directory..."
	local dir=${1##*/}
	git clone "$1" && cd "${dir%.git}"
}

function cloneinstall() {
	echo "Cloning repository and running installation..."
	local dir=${1##*/}
	git clone "$1" && cd "${dir%.git}" && npm install
}


# Branches
################################################################################

alias branch="git branch"
alias check="git checkout"
alias checkout="check"
alias checkd="git checkout develop"
alias checkm="git checkout master"
alias merged="git merge develop"
alias mergem="git merge master"
alias br="git checkout -b"
alias db="git branch -d" # delete branch
alias dbl="git branch -D" # delete local branch, even if unmerged
alias whatbranch="git symbolic-ref --short HEAD"
alias whatbr="whatbranch"

# Copy the current branch name to the clipboard
function cbn() {
	local branch
	branch=$(git symbolic-ref --short HEAD) || return
	printf '%s' "$branch" | clip
	echo "Copied branch $branch to the clipboard"
}

# Local branches with no upstream
function lbr() {
	git branch --format "%(refname:short) %(upstream)" | awk '{if ($2 == "" || $2 == "(none)") print $1;}'
}

# Branches by most recent commit
alias gab="git for-each-ref --sort=-committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"


# Pushing
################################################################################

function conf() {
	read -p "Have you built before pushing this code? (y/n) " RESP
	if [ "$RESP" = "y" ]; then
		git push
	else
		return 1
	fi
}
alias push="conf"
alias pish="push"
alias origin="git push -u origin --all"

function upstream() {
	git push --set-upstream origin "$(git symbolic-ref --short HEAD)"
}


# History
################################################################################

# Last n commits, 5 by default: log, log 20, log 10 --all
function log() {
	local n=5
	if [[ $1 =~ ^[0-9]+$ ]]; then
		n=$1
		shift
	fi
	git log -n "$n" --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit "$@"
}

# Last commit message
alias lc="git log -1 --pretty=%B"
alias lcm="cb ./.git/COMMIT_EDITMSG"

# Commits on this branch that aren't on develop
alias gitu='git log develop...HEAD --no-merges --cherry-pick --pretty=format:"%s"'
alias gituh='git log develop...HEAD --no-merges --cherry-pick --pretty=format:"%h %s"'

# Reflog for a branch, the current one by default
function whosyerda() {
	git reflog --date=local "${1:-$(git symbolic-ref --short HEAD)}"
}
alias bhis="git reflog --date=local"

# Your commit stats from last year to last month
function gitstats() {
	git log --stat --author "$(git config --get user.email)" --since="last year" --until="last month" | awk -F',' '/files? changed/ {
		files += $1
		insertions += $2
		deletions += $3
		print
	}
	END {
		print "Files Changed: " files
		print "Insertions: " insertions
		print "Deletions: " deletions
		print "Lines changed: " insertions + deletions
	}'
}


# Stash and cherry-pick
################################################################################

alias stash="git stash"
alias stashes="git stash list --date=local"
alias pop="git stash apply"
alias apply="pop"

function cherry() {
	git cherry-pick "$@"
}
alias cherrypick="cherry"

# Stop tracking local changes to a file, or start again
alias hide="git update-index --assume-unchanged"
alias show="git update-index --no-assume-unchanged"


# Undoing things
################################################################################

function undo() {
	git reset --soft HEAD^
	echo "Previous commit has been reset"
}

# Fetches the branch, shows what a hard reset to origin would lose, then asks
# before doing it. $2 is a message describing the extra damage, if any.
function __confirm_reset_to_origin() {
	local branch=$1 changes ahead
	# Compare against origin as it is now, not as of the last fetch
	git fetch origin "$branch" || return
	changes=$(git status --short)
	ahead=$(git log --oneline "origin/$branch..HEAD" 2> /dev/null)
	if [ -n "$changes" ]; then
		echo "Uncommitted changes that will be lost:"
		echo "$changes"
	fi
	if [ -n "$ahead" ]; then
		echo "Commits not on origin/$branch that will be lost:"
		echo "$ahead"
	fi
	if [ -n "$2" ]; then
		echo "$2"
	fi
	read -p "Reset $branch to origin/$branch? (y/n) " RESP
	[ "$RESP" = "y" ]
}

# Reset the branch to match origin (discards local commits and changes).
# Not called `reset`, which is the command that fixes a garbled terminal.
function greset() {
	local branch
	branch=$(git symbolic-ref --short HEAD) || return
	if ! __confirm_reset_to_origin "$branch"; then
		echo "Reset cancelled"
		return 1
	fi
	git reset --hard "origin/$branch"
	echo "Branch has been reset to origin/$branch"
}

# As greset, and also delete untracked and ignored files (node_modules, .env...)
function gclean() {
	local branch
	branch=$(git symbolic-ref --short HEAD) || return
	if ! __confirm_reset_to_origin "$branch" "Untracked and ignored files that will be deleted:
$(git clean -nxd)"; then
		echo "Clean cancelled"
		return 1
	fi
	git reset --hard "origin/$branch"
	git clean -fxd
	echo "Branch has been cleaned and reset to origin/$branch"
}

# Hard reset to a commit
function back() {
	if [ $# -eq 0 ]; then
		echo "Git or SHA required to roll back commits"
		return 1
	fi
	git reset --hard "$1"
}

# Remove the last n commits locally and force-push
function nuke() {
	if [ $# -eq 0 ]; then
		echo "Number of commits to remove required"
		return 1
	fi
	read -p "This will automatically remove the last $1 commits from the server, are you sure you wish to continue? (y/n) " RESP
	if [ "$RESP" = "y" ]; then
		git reset --hard HEAD~"$1"
		sleep 3s
		# Refuses if someone else pushed since the last fetch, rather than wiping their commits
		git push --force-with-lease
	else
		return 1
	fi
}
