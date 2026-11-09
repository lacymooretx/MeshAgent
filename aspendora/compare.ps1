# Compare our build with upstream's pinned binaries (MeshAgent release legacy-1.2.6, the ones MeshCentral serves).
# Usage (build host): compare.ps1 -Commit <sha of our build>
# Not a byte comparison (different toolchain, timestamps, version stamp); it checks the build is the same program.
param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit)
$ErrorActionPreference = 'Stop'
$root = 'C:\BuildHost\meshagent'; $up = "$root\upstream\legacy-1.2.6"; $ours = "$root\out\$Commit"
New-Item -ItemType Directory -Force $up | Out-Null
# sha384 pins from MeshCentral agents/agent-defaults.json
$pins = @{ 'MeshService.exe'='7abe621c6e9f8e1b11c842e052d890c942f285febb1a31897fd30ebccd1f2a12873b3a6e14689fdc7e646352b903d0ca';
           'MeshService64.exe'='319d3ad514173be85838bf7ba5995e11671d8f8e6df8e51b74c8304c3caf70e754e69db74b1baec1a6430ece213ab293';
           'MeshServiceARM64.exe'='08a3372068b5f636c89b909d0dac1d4fafac7ff8bbe55a78b27593dae1606ceef69bfa5078ece112915272b96f8c46bb' }
$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -products * -property installationPath
$dumpbin = Get-ChildItem "$vs\VC\Tools\MSVC" -Recurse -Filter dumpbin.exe | Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -First 1
function Strs($f) { $t = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($f)); [regex]::Matches($t, '[\x20-\x7e]{6,}') | ForEach-Object Value }
function Info($f) {
  $v = (Get-Item $f).VersionInfo
  $imp = & $dumpbin.FullName /nologo /imports $f | Where-Object { $_ -match '^\s+\S+\.(dll|DLL)\s*$' } | ForEach-Object { $_.Trim().ToLower() } | Sort-Object -Unique
  $sec = & $dumpbin.FullName /nologo /headers $f | Where-Object { $_ -match 'SECTION HEADER #\d+' -or $_ -match '^\s+\.\w+ name$' } | Where-Object { $_ -match 'name$' } | ForEach-Object { ($_.Trim() -split ' ')[0] }
  $s = Strs $f
  [pscustomobject]@{ size=(Get-Item $f).Length; file=$v.FileVersion; product=$v.ProductVersion; desc=$v.FileDescription;
    imports=($imp -join ','); sections=($sec -join ','); openssl=($s | Where-Object { $_ -match '^OpenSSL \d' } | Select-Object -First 1);
    commit=($s | Where-Object { $_ -match '^\d{4}-[A-Z][a-z]{2}-\d{2} \d\d:\d\d:\d\d[+-]\d{4}$' } | Select-Object -First 1);
    signed=(Get-AuthenticodeSignature $f).Status }
}
foreach ($n in $pins.Keys | Sort-Object) {
  $u = "$up\$n"
  if (-not (Test-Path $u)) { & curl.exe -sSfL --retry 3 -o $u "https://github.com/Ylianst/MeshAgent/releases/download/legacy-1.2.6/$n"; if ($LASTEXITCODE -ne 0) { throw "download $n failed" } }
  $h = (Get-FileHash $u -Algorithm SHA384).Hash.ToLower()
  "== $n  upstream sha384 pin " + $(if ($h -eq $pins[$n]) { 'MATCH' } else { "MISMATCH $h" })
  $a = Info $u; $b = Info "$ours\$n"
  foreach ($p in 'size','file','product','desc','openssl','commit','signed','sections','imports') {
    $same = if ("$($a.$p)" -eq "$($b.$p)") { '=' } else { '≠' }
    "  $same $p`n      upstream: $($a.$p)`n      ours:     $($b.$p)"
  }
}
