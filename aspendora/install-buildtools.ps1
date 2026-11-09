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
$args = @('--quiet','--wait','--norestart','--nocache',
  '--add','Microsoft.VisualStudio.Workload.VCTools',
  '--add','Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  '--add','Microsoft.VisualStudio.Component.VC.Tools.ARM64',
  '--add','Microsoft.VisualStudio.Component.Windows11SDK.22621')
$p = Start-Process $bt -ArgumentList $args -Wait -PassThru
"vs_BuildTools exit=$($p.ExitCode)"   # 0 ok, 3010 ok (reboot wanted)
$vsw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
& $vsw -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
& $vsw -products * -property catalog_productDisplayVersion
Test-Path "${env:ProgramFiles(x86)}\Windows Kits\10\Include\10.0.22621.0"
