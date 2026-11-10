# Builds static OpenSSL 1.1.1w (the last 1.1.1 release, same API as the 1.1.1f headers the agent was written against)
# for x64, x86 and ARM64, replacing the committed prebuilt libs (1.1.1s x86/x64, 1.1.1n ARM64; EOL since 2023-09).
# Usage (build host, as SYSTEM/admin): build-openssl.ps1
# Output: C:\BuildHost\openssl\1.1.1w\<x64|x86|ARM64>\{libcrypto.lib,libssl.lib,include\openssl\*.h,configdata.txt}
#         C:\BuildHost\openssl\1.1.1w\SHA256SUMS.txt, build.log
# build.ps1 -OpenSSL C:\BuildHost\openssl\1.1.1w links these instead of openssl\libstatic.
#
# Feature set: matches the committed openssl\include\openssl\opensslconf.h (and the x86/x64 prebuilt libs): no-asm, no-err,
# legacy ciphers off. Configure generates per-arch headers (the committed one says THIRTY_TWO_BIT for every arch).
# Each arch builds with the toolset its MeshService project uses: x86 = v142 (14.29), x64/ARM64 = v143.
$ErrorActionPreference = 'Stop'
$ver = '1.1.1w'
$tgzSha = 'CF3098950CB4D853AD95C0841F1F9C6D3DC102DCCFCACD521D93925208B76AC8'   # openssl.org .sha256 == GitHub release .sha256
$perlUrl = 'https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54221_64bit/strawberry-perl-5.42.2.1-64bit-portable.zip'
$perlSha = '32D83BE90CF04B807CFB9477482BC36302CDEE6F5B04CF57E81ADECBD8F07898'  # GitHub release asset digest
$root = 'C:\BuildHost\openssl'; $out = "$root\$ver"; $dl = "$root\dl"
New-Item -ItemType Directory -Force $root, $out, $dl | Out-Null
$log = "$out\build.log"; "build-openssl $ver started $(Get-Date -Format o)" | Tee-Object $log

function Get-Pinned($url, $file, $sha) {
  if (-not (Test-Path $file) -or (Get-FileHash $file).Hash -ne $sha) {
    & curl.exe -sSfL --retry 3 -o $file $url; if ($LASTEXITCODE -ne 0) { throw "download failed: $url ($LASTEXITCODE)" }
  }
  $h = (Get-FileHash $file).Hash; if ($h -ne $sha) { Remove-Item $file; throw "hash mismatch for $url : $h" }
  "ok $file $h" | Tee-Object -Append $log
}

# Perl (OpenSSL's Configure needs a native Windows perl; no nasm needed with no-asm). Only perl\bin goes on PATH, not its gcc.
$perlZip = "$dl\strawberry-perl-5.42.2.1-64bit-portable.zip"; Get-Pinned $perlUrl $perlZip $perlSha
$perlDir = "$root\strawberry-5.42.2.1"
if (-not (Test-Path "$perlDir\perl\bin\perl.exe")) { Expand-Archive $perlZip $perlDir -Force }
$env:PATH = "$perlDir\perl\bin;$env:PATH"
& perl -v | Select-Object -Skip 1 -First 1 | Tee-Object -Append $log

$tgz = "$dl\openssl-$ver.tar.gz"; Get-Pinned "https://www.openssl.org/source/openssl-$ver.tar.gz" $tgz $tgzSha

$vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -products * -property installationPath | Select-Object -First 1
$vcvars = "$vs\VC\Auxiliary\Build\vcvarsall.bat"
$opts = 'no-shared no-asm no-err no-bf no-camellia no-cast no-idea no-md2 no-md4 no-mdc2 no-rc5 no-rmd160 no-seed ' +
        'no-heartbeats no-hw no-ssl3 no-ssl3-method no-weak-ssl-ciphers no-dynamic-engine no-sctp no-ssl-trace no-egd no-unit-test no-tests'
$targets = [ordered]@{
  'x64'   = @{ vc = 'x64';       cfg = 'VC-WIN64A' }
  'x86'   = @{ vc = 'x86 -vcvars_ver=14.29'; cfg = 'VC-WIN32' }
  'ARM64' = @{ vc = 'x64_arm64'; cfg = 'VC-WIN64-ARM' }
}
foreach ($a in $targets.Keys) {
  $t = $targets[$a]; $bld = "$root\build-$a"; $dst = "$out\$a"
  if (Test-Path $bld) { Remove-Item -Recurse -Force $bld }
  New-Item -ItemType Directory -Force $bld, $dst | Out-Null
  & tar.exe -xzf $tgz -C $bld; if ($LASTEXITCODE -ne 0) { throw "untar failed" }
  $s = "$bld\openssl-$ver"; $pfx = "$root\inst-$a"
  "=== $a ($($t.cfg)) $(Get-Date -Format T)" | Tee-Object -Append $log
  $cmd = "call `"$vcvars`" $($t.vc) >nul && cd /d `"$s`" && perl Configure $($t.cfg) $opts --prefix=`"$pfx`" --openssldir=`"$pfx`" && nmake /nologo build_libs"
  & cmd.exe /c $cmd *>> $log
  if ($LASTEXITCODE -ne 0) { throw "openssl $a build failed ($LASTEXITCODE), see $log" }
  Copy-Item "$s\libcrypto.lib", "$s\libssl.lib" $dst -Force
  if (Test-Path "$dst\include") { Remove-Item -Recurse -Force "$dst\include" }
  New-Item -ItemType Directory -Force "$dst\include" | Out-Null
  Copy-Item -Recurse "$s\include\openssl" "$dst\include\openssl"
  & perl "$s\configdata.pm" -o -c | Out-File -Encoding ascii "$dst\configdata.txt"   # options + compiler flags, for the record
}
Get-ChildItem $out -Recurse -Filter *.lib | ForEach-Object { "$((Get-FileHash $_.FullName).Hash)  $($_.FullName.Substring($out.Length+1))  $($_.Length)" } | Tee-Object "$out\SHA256SUMS.txt"
"done $(Get-Date -Format o)" | Tee-Object -Append $log
