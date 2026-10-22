# nvm's default node (a junction set by `nvmdefault` in bash) ahead of any
# machine-wide install, which Windows otherwise puts first on PATH
$env:Path = "$env:USERPROFILE\.nvm\default\bin;$env:Path"

Set-Location -Path "C:\dev"
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/M365Princess.omp.json" | Invoke-Expression