# Installs the toolchain for building the Windows MeshAgent on the build host (ASP-DEPLOY01).
# VS 2022 Build Tools: MSVC v143 x86/x64 + ARM64, Windows 11 SDK 10.0.22621 (what meshservice/MeshService-2022.vcxproj targets).
# Idempotent: re-running adds missing components. Run as SYSTEM or admin (ControlR run_script, timeout 3600).
$ErrorActionPreference = 'Stop'
$root = 'C:\BuildHost\meshagent'
New-Item -ItemType Directory -Force $root, "$root\dl" | Out-Null
# Local Defender flags MeshAgent as PUA; keep it off the build tree only (this VM is not MDE-onboarded).
Add-MpPreference -ExclusionPath $root
$bt = "$root\dl\vs_BuildTools.exe"
Invoke-WebRequest -UseBasicParsing 'https://aka.ms/vs/17/release/vs_BuildTools.exe' -OutFile $bt
$sig = Get-AuthenticodeSignature $bt
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') { throw "vs_BuildTools.exe signature: $($sig.Status) $($sig.SignerCertificate.Subject)" }
# ATLMFC: MeshService.rc includes afxres.h
$add = @('Microsoft.VisualStudio.Workload.VCTools','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','Microsoft.VisualStudio.Component.VC.Tools.ARM64',
         'Microsoft.VisualStudio.Component.Windows11SDK.22621','Microsoft.VisualStudio.Component.VC.ATLMFC','Microsoft.VisualStudio.Component.VC.MFC.ARM64',
         # Release|Win32 (MeshService.exe) is pinned to toolset v142 in MeshService-2022.vcxproj; keep upstream's toolchain
         'Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64','Microsoft.VisualStudio.Component.VC.v142.ATL','Microsoft.VisualStudio.Component.VC.v142.MFC')
$vsw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$existing = if (Test-Path $vsw) { & $vsw -products * -property installationPath | Select-Object -First 1 }
$args = @()
if ($existing) { $args += @('modify','--installPath',"`"$existing`"") }   # already installed: add what's missing
$args += @('--quiet','--wait','--norestart','--nocache'); foreach ($a in $add) { $args += @('--add',$a) }
$p = Start-Process $bt -ArgumentList $args -Wait -PassThru
"vs_BuildTools exit=$($p.ExitCode)"   # 0 ok, 3010 ok (reboot wanted)
& $vsw -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
& $vsw -products * -property catalog_productDisplayVersion
Test-Path "${env:ProgramFiles(x86)}\Windows Kits\10\Include\10.0.22621.0"
Test-Path ((& $vsw -products * -property installationPath) + "\VC\Tools\MSVC\*\atlmfc\include\afxres.h")
