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
alias bashed="source ~/.bashrc"
alias rc='cat "$BASHRC_DIR"/.bashrc "$BASHRC_DIR"/.bashrc.d/*.sh'
alias bsh='echo "Current Bash Profile saved to Desktop"; rc > "$(cygpath -u "${OneDriveCommercial:-$USERPROFILE}")/Desktop/bashcmds.md"'

# Copy VS Code and PowerShell settings into the editor_settings repo, minus
# anything that looks like a credential, then show what changed. (Bash files
# need no copying: the repo is the live copy.)
function dotsync() {
	local repo="$BASHRC_DIR/.." code ps
	code="$(cygpath -u "$APPDATA")/Code/User"
	ps="$(cygpath -u "${OneDriveCommercial:-$USERPROFILE}")/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
	# Lines holding keys, tokens or passwords, and BrowserStack's login
	local private='"[^"]*(accesskey|apikey|token|password|secret)[^"]*"[[:space:]]*:|"browserstack\.'
	grep -Eiv "$private" "$code/settings.json" > "$repo/vscode/settings.json"
	cp "$code/keybindings.json" "$repo/vscode/keybindings.json"
	cp "$ps" "$repo/powershell/"
	# The repo is public: flag anything that would publish the Windows username
	if grep -il -- "$USERNAME" "$repo"/vscode/* "$repo"/powershell/*; then
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
alias dump="rm -rf"
alias la="lsmod"
alias ld="list_dir"

# ls -al with each entry's permissions as an octal number in front
function lsmod() {
	ls -al "$@" | awk '{k=0;for(i=0;i<=8;i++)k+=((substr($1,i+2,1)~/[rwx]/) \
	*2^(8-i));if(k)printf("%0o ",k);print}'
}

function list_dir() {
	local dir="${1:-.}"
	echo "Directories:"
	find "$dir" -maxdepth 1 -type d | sort
	echo
	echo "Files:"
	find "$dir" -maxdepth 1 -type f | sort
}

# cd into a folder and list it
function cs() { cd "$1" && ls; }
function ca() { cd "$1" && la; }
function cdir() { cd "$1" && ld; }


# Clipboard
################################################################################

# Copy text: pbcopy some text here
function pbcopy() {
	if [ $# -eq 0 ]; then
		echo "Can't copy nothing, need something"
		return 1
	fi
	printf '%s' "$*" | clip
	echo "Copied to clipboard"
}

# Copy a command's output: xclip git status
function xclip() {
	"$@" | clip
	echo "Command contents copied to clipboard"
}

# Copy a file's contents: cb notes.txt
function cb() {
	if [ ! -f "$1" ]; then
		echo "File not found: $1"
		return 1
	fi
	clip < "$1"
	echo "The contents of $1 were sent to the clipboard"
}

# Copy a public key: sshcopy id_rsa
function sshcopy() {
	if [ ! -f ~/.ssh/"$1".pub ]; then
		echo "No public key at ~/.ssh/$1.pub"
		return 1
	fi
	clip < ~/.ssh/"$1".pub
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
