#Requires -Version 7.4
<#
.SYNOPSIS
Installs the repository's pinned Lua development tools on Windows x64.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Shared.psm1') -Force
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw 'This bootstrap currently supports Windows x64 only.'
}
$bin = Join-Path (Split-Path $PSScriptRoot -Parent) '.bin'
$null = New-Item -ItemType Directory -Path $bin -Force
Install-ArchiveTool `
    -Uri 'https://sourceforge.net/projects/luabinaries/files/5.1.5/Tools%20Executables/lua-5.1.5_Win64_bin.zip/download' `
    -Destination (Join-Path $bin 'luac.exe') -ExecutablePattern 'luac*.exe' -InstalledExecutable (Join-Path $bin 'luac.exe')
Install-ArchiveTool `
    -Uri 'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.1.0/stylua-windows-x86_64.zip' `
    -Destination (Join-Path $bin 'stylua.exe') -ExecutablePattern 'stylua.exe' -InstalledExecutable (Join-Path $bin 'stylua.exe')
Install-ArchiveTool `
    -Uri 'https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip' `
    -Destination (Join-Path $bin 'lua-language-server') -ExecutablePattern 'lua-language-server.exe' `
    -InstalledExecutable (Join-Path $bin 'lua-language-server\bin\lua-language-server.exe') -CopyDirectory
Write-Host 'Lua development tools are ready in .bin.'
