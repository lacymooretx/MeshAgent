# Builds MeshService.exe / MeshService64.exe / MeshServiceARM64.exe from a pinned commit of this fork.
# Usage (build host, as SYSTEM/admin): build.ps1 -Commit <40-char sha> [-Repo lacymooretx/MeshAgent]
# Output: C:\BuildHost\meshagent\out\<sha>\{MeshService.exe,MeshService64.exe,MeshServiceARM64.exe,SHA256SUMS.txt,build.log}
param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit, [string]$Repo = 'lacymooretx/MeshAgent')
$ErrorActionPreference = 'Stop'
$root = 'C:\BuildHost\meshagent'; $src = "$root\src\$Commit"; $out = "$root\out\$Commit"
New-Item -ItemType Directory -Force "$root\src", $out | Out-Null
$zip = "$root\src\$Commit.zip"
Invoke-WebRequest -UseBasicParsing "https://github.com/$Repo/archive/$Commit.zip" -OutFile $zip
"source zip sha256=$((Get-FileHash $zip).Hash)" | Tee-Object "$out\build.log"
if (Test-Path $src) { Remove-Item -Recurse -Force $src }
Expand-Archive $zip "$root\src\x-$Commit" -Force
Move-Item (Get-ChildItem "$root\src\x-$Commit")[0].FullName $src; Remove-Item "$root\src\x-$Commit"
$vsw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vsw -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
"msbuild=$msb" | Tee-Object -Append "$out\build.log"
$map = @{ 'x86' = 'MeshService.exe'; 'x64' = 'MeshService64.exe'; 'ARM64' = 'MeshServiceARM64.exe' }
foreach ($plat in 'x64','x86','ARM64') {
  & $msb "$src\MeshAgent-2022.sln" /t:MeshService-2022 /p:Configuration=Release /p:Platform=$plat /m /nologo /v:minimal 2>&1 | Tee-Object -Append "$out\build.log" | Select-Object -Last 3
  if ($LASTEXITCODE -ne 0) { throw "build $plat failed ($LASTEXITCODE), see $out\build.log" }
}
# Collect: the project writes MeshService*.exe next to the solution or under meshservice\<plat>\Release; find newest per name.
foreach ($n in $map.Values) {
  $f = Get-ChildItem $src -Recurse -Filter $n | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { throw "missing $n" }
  Copy-Item $f.FullName "$out\$n" -Force
}
Get-ChildItem $out -Filter *.exe | ForEach-Object { "$((Get-FileHash $_.FullName).Hash)  $($_.Name)  $($_.Length)" } | Tee-Object "$out\SHA256SUMS.txt"
