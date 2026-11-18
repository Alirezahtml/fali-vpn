# Builds the TUN service (core\cmd\fati-vpn-tun) into -Out as
# fati-vpn-tun.exe, beside the core, from where the app installs it.
# scripts\build-windows.ps1 and scripts\update-installed-windows.ps1 run it.
#
# Updates of an installed service must be signed (Ed25519): with a signing
# key (scripts\signing-key.ps1; -PublicKey when the caller read it already),
# the service accepts updates signed with it, and fati-vpn-tun.exe.sig is
# written beside the executable. Without a key the service takes no
# updates: a newer one is installed again, with the administrator prompt.
#Requires -Version 7
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Out,
    [string]$PublicKey
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$public = if ($PSBoundParameters.ContainsKey('PublicKey')) { $PublicKey } else { & "$PSScriptRoot\signing-key.ps1" }
Push-Location "$root\core"
try {
    $env:APP_VERSION = $Version
    go generate ./cmd/fati-vpn-tun
    if ($LASTEXITCODE -ne 0) { throw 'go generate failed (fati-vpn-tun)' }

    # windowsgui: no console window when the app or Setup starts it.
    $ldflags = "-s -w -H windowsgui -X github.com/Alirezahtml/fati-vpn/core/internal/version.Current=$Version"
    if ($public) { $ldflags += " -X github.com/Alirezahtml/fati-vpn/core/internal/signing.Key=$public" }
    $exe = Join-Path $Out 'fati-vpn-tun.exe'
    go build -tags with_gvisor -trimpath -ldflags $ldflags -o $exe ./cmd/fati-vpn-tun
    if ($LASTEXITCODE -ne 0) { throw 'go build failed (fati-vpn-tun)' }
    if ($public) {
        go run ./tools/sign $exe
        if ($LASTEXITCODE -ne 0) { throw 'signing the TUN service failed' }
    } else {
        Remove-Item "$exe.sig" -ErrorAction SilentlyContinue
    }
} finally {
    Remove-Item Env:APP_VERSION -ErrorAction SilentlyContinue
    Pop-Location
}
