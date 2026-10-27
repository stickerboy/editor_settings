# Shell, files, clipboard and network helpers. Sourced by .bashrc.

# This profile
################################################################################

# Edit or show the profile (in the editor_settings repo). `bashme` opens
# .bashrc, `bashme git` opens .bashrc.d/git.sh, `bashme local` ~/.bashrc.local
function __profile_file() {
	if [ "$1" = "local" ]; then
		echo ~/.bashrc.local
	else
		echo "$BASHRC_DIR/.bashrc${1:+.d/$1.sh}"
	fi
}
function bashme() {
	vim "$(__profile_file "$1")"
}
function npbash() {
	np "$(__profile_file "$1")"
}
# An alias, not a function: sourcing inside a function would make any
# `declare` in the profile local to it
alias bashed='source ~/.bashrc && echo "Profile reloaded"'
alias rc='cat "$BASHRC_DIR"/.bashrc "$BASHRC_DIR"/.bashrc.d/*.sh'
# shellcheck disable=SC2154 # OneDriveCommercial is set by Windows
alias bsh='echo "Current Bash Profile saved to Desktop"; rc > "$(cygpath -u "${OneDriveCommercial:-$USERPROFILE}")/Desktop/bashcmds.md"'

# Copy VS Code, PowerShell and git settings into the editor_settings repo,
# minus anything that looks like a credential, then show what changed. (Bash
# files need no copying: the repo is the live copy.)
function dotsync() {
	local repo="$BASHRC_DIR/.." code ps
	code="$(cygpath -u "$APPDATA")/Code/User"
	ps="$(cygpath -u "${OneDriveCommercial:-$USERPROFILE}")/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
	# Lines holding keys, tokens or passwords, and BrowserStack's login
	local private='"[^"]*(accesskey|apikey|token|password|secret)[^"]*"[[:space:]]*:|"browserstack\.'
	# Also cSpell's word lists, which "Add to dictionary" keeps adding to. They
	# can span lines, so skip from the key to the closing ]
	grep -Eiv "$private" "$code/settings.json" | awk '
		/"cSpell\.(userWords|words)"[[:space:]]*:/ { skipping = 1 }
		skipping { if (/\]/) skipping = 0; next }
		{ print }
	' > "$repo/vscode/settings.json"
	cp "$code/keybindings.json" "$repo/vscode/keybindings.json"
	# Reinstall with: xargs -n 1 code --install-extension < vscode/extensions.txt
	code --list-extensions | sed 's/\r$//' > "$repo/vscode/extensions.txt"
	cp "$ps" "$repo/powershell/"

	# ~/.gitconfig without the sections that are personal, point at work hosts
	# or differ per machine: [user] (name, email, signing key), [includeIf ...]
	# (the work identity), [credential "https://..."] and [gpg] (which gpg.exe
	# signs, e.g. Git's own or Gpg4win's). Comments go with the line after
	# them, so a section's comments are dropped with it. The OneDrive and
	# profile folders are replaced by <OneDriveCommercial> and <USERPROFILE>,
	# in each of the ways git config writes a Windows path.
	local gitconfig name dir
	gitconfig=$(awk '
		/^[[:space:]]*([#;]|$)/ { held = held $0 "\n"; next }
		/^\[/ { skip = tolower($0) ~ /^\[(user\]|gpg\]|includeif |credential "https?:)/ }
		!skip { printf "%s%s\n", held, $0 }
		{ held = "" }
	' ~/.gitconfig)
	# OneDrive first: it's inside the profile folder
	for name in OneDriveCommercial USERPROFILE; do
		dir=${!name}
		if [ -z "$dir" ]; then
			continue
		fi
		gitconfig=${gitconfig//"$dir"/"<$name>"}
		gitconfig=${gitconfig//"${dir//\\//}"/"<$name>"}
		gitconfig=${gitconfig//"${dir//\\/\\\\}"/"<$name>"}
	done
	mkdir -p "$repo/git"
	printf '%s\n' "$gitconfig" > "$repo/git/.gitconfig"

	# The repo is public: flag anything that would publish the Windows username
	if grep -il -- "$USERNAME" "$repo"/vscode/* "$repo"/powershell/* "$repo"/git/.gitconfig; then
		echo "⚠ The files above contain your username ($USERNAME). Edit them before committing."
	fi
	git -C "$repo" status --short
}


# Apps
################################################################################

# NOTEPADPP in ~/.bashrc.local overrides the install path
alias np='"${NOTEPADPP:-/c/Program Files/Notepad++/notepad++.exe}"'
alias v="vim"
alias e="explorer ."


# Files and folders
################################################################################

alias ..="cd .."
alias cls="clear"
alias md5="md5sum"
alias stats="stat -c %a"
alias la="lsmod"
alias ldir="list_dir"

# rm -rf, after listing what will go and asking: dump node_modules dist
function dump() {
	if [ $# -eq 0 ]; then
		echo "Nothing to delete: dump <path>..."
		return 1
	fi
	local p
	for p in "$@"; do
		if [ ! -e "$p" ] && [ ! -L "$p" ]; then
			echo "Not found: $p"
			return 1
		fi
	done
	echo "This will delete:"
	for p in "$@"; do
		if [ -d "$p" ] && [ ! -L "$p" ]; then
			echo "  ${p%/}/ (and everything in it)"
		else
			echo "  $p"
		fi
	done
	read -rp "Delete? (y/n) " RESP
	if [ "$RESP" != "y" ]; then
		echo "Nothing deleted"
		return 1
	fi
	rm -rf -- "$@"
}

# ls -al with each entry's permissions as an octal number in front, and
# without the owner, group, links and size: 755 drwxr-xr-x Oct 26 12:47 .bashrc.d
# Keeps ls colours when writing to the terminal.
function lsmod() {
	local color=never
	if [ -t 1 ]; then
		color=always
	fi
	# -g and -o leave out the owner and group. The point is ls's own listing,
	# so find isn't a substitute
	# shellcheck disable=SC2012
	ls -algo --color="$color" "$@" | awk '
		# The block count is meaningless without sizes
		/^total [0-9]+$/ { next }
		# Only entries start with a mode (drwxr-xr-x); pass folder headers through
		!match($0, /^[-a-z][-rwxsStT]{9}[^ ]* +[0-9]+ +[0-9,]+( +[0-9]+)? /) { print; next }
		{
			mode = 0
			for (i = 2; i <= 10; i++) {
				mode = mode * 2 + (substr($1, i, 1) ~ /[rwxst]/)
			}
			# Drop the links and size columns, keeping the date and name as ls aligned them
			printf "%03o %s %s\n", mode, $1, substr($0, RLENGTH + 1)
		}'
}

# Folders, then files, in a folder (the current one by default)
function list_dir() {
	local dir=${1:-.}
	echo "Directories:"
	find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '  %f/\n' | sort
	echo
	echo "Files:"
	find "$dir" -mindepth 1 -maxdepth 1 ! -type d -printf '  %f\n' | sort
}

# cd into a folder and list it
function cs() { cd "$1" && ls; }
function ca() { cd "$1" && la; }
function cdir() { cd "$1" && ldir; }


# Clipboard
################################################################################

# These write to MSYS's /dev/clipboard rather than piping to clip.exe, which
# mangles anything that isn't ASCII (café -> caf├⌐).

# Copy text, or whatever is piped in: pbcopy some text, git diff | pbcopy
function pbcopy() {
	local text
	if [ $# -gt 0 ]; then
		text=$*
	elif [ ! -t 0 ]; then
		# The x stops $(...) dropping trailing newlines
		text=$(cat; printf x)
		text=${text%x}
	fi
	if [ -z "$text" ]; then
		echo "Nothing to copy: pbcopy <text>, or pipe into it"
		return 1
	fi
	printf '%s' "$text" > /dev/clipboard
	echo "Copied to clipboard"
}

# Print the clipboard, with Windows line endings removed: pbpaste > notes.txt
function pbpaste() {
	sed 's/\r$//' /dev/clipboard
}

# Copy a command's output: xclip git status (same as git status | pbcopy)
function xclip() {
	"$@" > /dev/clipboard
	echo "Command contents copied to clipboard"
}

# Copy a file's contents: cb notes.txt
function cb() {
	if [ ! -f "$1" ]; then
		echo "File not found: $1"
		return 1
	fi
	cat "$1" > /dev/clipboard
	echo "The contents of $1 were sent to the clipboard"
}

# Copy a public key: sshcopy id_rsa
function sshcopy() {
	if [ ! -f ~/.ssh/"$1".pub ]; then
		echo "No public key at ~/.ssh/$1.pub"
		return 1
	fi
	cat ~/.ssh/"$1".pub > /dev/clipboard
	echo "SSH Key copied to clipboard"
}


# Network
################################################################################

alias ping="ping -n 10"
alias flush="ipconfig //flushdns"
alias dns="ipconfig //displaydns"
alias hosts="vim /c/windows/system32/drivers/etc/hosts"
alias hostsc="cat /c/windows/system32/drivers/etc/hosts > /c/hosts"
alias dt="devtunnel host -p 8080 -e 12h --allow-anonymous"

# Kill whatever is listening on a port, after asking: killport 8080
function killport() {
	if [[ ! $1 =~ ^[0-9]+$ ]]; then
		echo "Usage: killport <port>"
		return 1
	fi
	local pids pid name
	# IPv4 and IPv6 listeners whose local address ends in :<port>
	pids=$(netstat -ano | awk -v port="$1" '
		{ sub(/\r$/, "") }
		$1 == "TCP" && $4 == "LISTENING" && $2 ~ (":" port "$") { print $5 }
	' | sort -u)
	if [ -z "$pids" ]; then
		echo "Nothing is listening on port $1"
		return 1
	fi
	echo "Listening on port $1:"
	for pid in $pids; do
		# First CSV field is the image name: "node.exe","1234",...
		name=$(tasklist //FI "PID eq $pid" //FO CSV //NH)
		name=${name%%,*}
		echo "  ${name//\"/} (PID $pid)"
	done
	read -rp "Kill? (y/n) " RESP
	if [ "$RESP" != "y" ]; then
		echo "Nothing killed"
		return 1
	fi
	for pid in $pids; do
		taskkill //F //PID "$pid" > /dev/null && echo "Killed PID $pid"
	done
}
