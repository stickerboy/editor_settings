# npm, node and Eleventy. Sourced by .bashrc.

# Installing
################################################################################

alias ni="npm install"
alias ng="npm install -g"
alias nis="npm install --save"
alias nsd="npm install --save-dev"
alias nlpd="npm install --legacy-peer-deps"
alias nlpdsd="npm install --save-dev --legacy-peer-deps"
alias nun="npm uninstall --save"
alias nunsd="npm uninstall --save-dev"
alias nu="npm update --save"
alias no="npm outdated"
alias nau="npm audit"
alias dxpu="npm i -g @squiz/dxp-cli-next"

# Install the latest version of a package: nil vite
function nil() {
	npm install "${1}@latest"
}

# HTML audit report (needs audit-export installed for the current node)
function nae() {
	npm audit --json | audit-export --path "./audit.html" --title "${AUDIT_TITLE:-npm audit report}"
}

# Pin the current node version for this folder
function nvmrc() {
	node -v > .nvmrc
	# Make the prompt hook re-read .nvmrc
	__nvmrc_pwd=
	echo "Wrote $(< .nvmrc) to .nvmrc"
}

# Set nvm's default node (nvmdefault 26), and point ~/.nvm/default at it.
# Windows tools get node from ~/.nvm/default/bin on PATH, so this changes
# the node they use too. ~/.nvm/default is a junction, which needs no admin.
function nvmdefault() {
	if [ -z "$1" ]; then
		echo "Usage: nvmdefault <version>"
		return 1
	fi
	if ! __nvm_resolve "$1"; then
		echo "Node $1 isn't installed (nvm install $1)"
		return 1
	fi
	# shellcheck disable=SC2154 # set by __nvm_resolve in .bashrc
	local version=$__nvm_resolved link target
	echo "${version#v}" > "$NVM_DIR/alias/default"
	link=$(cygpath -w "$NVM_DIR/default")
	target=$(cygpath -w "$NVM_DIR/versions/node/$version")
	# rmdir on a junction removes only the link, never the folder it points at.
	# Separate arguments, not one quoted string: MSYS escapes inner quotes as
	# \", which cmd doesn't understand.
	if [ -e "$NVM_DIR/default" ]; then
		MSYS2_ARG_CONV_EXCL='*' cmd /c rmdir "$link" > /dev/null
	fi
	MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$link" "$target" > /dev/null
	# Re-check .nvmrc on the next prompt, as "default" now means something else
	__nvmrc_pwd=
	__nvmrc_want=
	echo "Default node is now $version"
}


# Scripts
################################################################################

alias nr="npm run"
alias ns="npm start"
alias na="npm run add-module"
alias dev="npm run dev"
alias nb="npm run build"
alias build="nb"
alias watch="npm run watch"
alias sync="npm run sync"
alias ws="npm run watchsync"
alias debug="npm run build:debug"
alias serve="npm run preview"
alias preview="serve"
alias gcu="npm run preview:live"
alias live="gcu"
alias debug-p="npm run debug:preview"
alias debug-l="npm run debug:live"
alias debug-r="npm run debug:request"


# Eleventy
################################################################################

function 11typrod() {
	echo "🚀 Starting Eleventy server on port 8088..."
	npx @11ty/eleventy --serve --port=8088
}

function 11ty() {
	echo "🚀 Starting Eleventy server on port 8008..."
	ENV_11TY=development npx @11ty/eleventy --serve --port=8008
}
