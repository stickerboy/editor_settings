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
	npm audit --json | audit-export --path "./audit.html" --title "GCU NPM Audit Report"
}

# Pin the current node version for this folder
function nvmrc() {
	node -v > .nvmrc
	# Make the prompt hook re-read .nvmrc
	__nvmrc_pwd=
	echo "Wrote $(< .nvmrc) to .nvmrc"
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
