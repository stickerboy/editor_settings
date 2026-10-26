# Squiz Matrix DXP components and page layouts. Sourced by .bashrc.
# The tenant ID is set in ~/.bashrc.local (DXP_TENANT), so it isn't published.

function dxpa() {
	if [ -z "$DXP_TENANT" ]; then
		echo "Set DXP_TENANT in ~/.bashrc.local first (bashme local)"
		return 1
	fi
	dxp-next auth login --tenant="$DXP_TENANT"
}
alias dxpinit="dxp-next cmp init ./components"
alias dxpdev="dxp-next cmp dev"
alias dxpdeploy="deploy"
alias dxpv="get_component_version"
alias dxpl="dxp-next page layouts dev --stylesheet dist/main.css"
alias dxpldeploy="layout_deploy"

# New component: dxpnew <name> <display name> [other init options]
function dxpnew() {
	dxp-next cmp init --ci --name "$1" --displayname "$2" --namespace gcu "${@:3}"
}

function dxpreview() {
	dotenv -- dxp-next cmp dev-ui "${1:-components/}"
}

# Reads displayName and version from <dir>/manifest.json into
# $__manifest_name and $__manifest_version. Prints an error and returns 1 if
# the file or either field is missing.
function __read_manifest() {
	local file="${1:-.}/manifest.json"
	__manifest_name=
	__manifest_version=
	if [ ! -f "$file" ]; then
		echo -e "${RED}Error${NC}: manifest.json not found in '${1:-.}'. Check you are in the correct directory."
		return 1
	fi
	if ! command -v jq > /dev/null 2>&1; then
		echo -e "${RED}Error${NC}: 'jq' is required but not found. Please install jq."
		return 1
	fi
	{
		read -r __manifest_version
		read -r __manifest_name
	} < <(jq -r '.version // "", .displayName // ""' "$file")
	__manifest_version=${__manifest_version%$'\r'}
	__manifest_name=${__manifest_name%$'\r'}
	if [ -z "$__manifest_version" ] || [ -z "$__manifest_name" ]; then
		echo -e "${RED}Error${NC}: Version or Display Name missing in $file."
		return 1
	fi
}

# Show a component's name and version: dxpv components/my-card
function get_component_version() {
	__read_manifest "$1" || return
	echo "$__manifest_name - version $__manifest_version"
}

# Deploy a component, failing if dxp-next exits non-zero or prints an ERROR line
function deploy() {
	if [ -z "$1" ]; then
		echo -e "${RED}Error${NC}: Please specify a component directory to deploy."
		return 1
	fi
	__read_manifest "$1" || return
	local name=$__manifest_name ver=$__manifest_version

	echo -e "Deploying '${GREEN}$name${NC}' - version ${GREEN}$ver${NC}"

	# Stream the output and keep a copy to check for ERROR lines
	local tmpfile status errors=
	tmpfile=$(mktemp)
	dxp-next cmp deploy "$1" 2>&1 | tee "$tmpfile"
	status=${PIPESTATUS[0]}
	if grep -q '^ERROR' "$tmpfile"; then
		errors=1
	fi
	rm -f "$tmpfile"

	if [ -n "$errors" ]; then
		echo -e "${RED}❌ Deployment of '$name' (version $ver) reported an ERROR.${NC}"
		return 1
	fi
	if [ "$status" -ne 0 ]; then
		echo -e "${RED}❌ Deployment of '$name' (version $ver) exited with status $status.${NC}"
		return "$status"
	fi
	echo -e "${GREEN}✨ Deployment of '$name' (version $ver) completed successfully!${NC}"
}

# Deploy page layouts: dxpldeploy [--config=file] [--dry-run] [--verbose]
function layout_deploy() {
	local arg cmd=(dxp-next page layouts deploy)
	for arg in "$@"; do
		case "$arg" in
			--config=*)
				cmd+=(--config "${arg#--config=}")
				;;
			--dry-run|--verbose|-h|--help)
				cmd+=("$arg")
				;;
			*)
				echo "Warning: Unrecognized argument '$arg'"
				;;
		esac
	done
	echo "Running command: ${cmd[*]}"
	"${cmd[@]}"
}
