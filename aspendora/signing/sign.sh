#!/bin/sh
# Runs inside aspendora/agent-signer. /w = work dir, /klt = KeyLocker Linux tools, /p12 = client auth cert (ro).
set -eu
mkdir -p /tmp/work && cp /w/chain /tmp/work/ && cd /tmp/work   # plain exes never touch the bind mount (host AV)
python3 - <<'PY'
import zipfile, io, hashlib
b = bytes(x ^ 0x5A for x in open('/w/in/unsigned.xor','rb').read())
z = zipfile.ZipFile(io.BytesIO(b)); z.extractall('unsigned')
sums = {l.split()[1]: l.split()[0].lower() for l in open('unsigned/SHA256SUMS.txt', encoding='utf-16') if l.strip()}
for n, h in sums.items():
    got = hashlib.sha256(open('unsigned/'+n,'rb').read()).hexdigest()
    assert got == h, (n, got, h); print('unsigned ok', n, h)
PY
# leaf + intermediate only
awk '/BEGIN/{n++} n<=2' chain > certs.pem
mkdir -p signed
printf 'name = smpkcs11\nlibrary = /klt/smpkcs11.so\nslotListIndex = 0\n' > /tmp/work/pkcs11.cfg
for f in MeshService.exe MeshService64.exe MeshServiceARM64.exe; do
  ok=0
  for a in 1 2 3; do
    rm -f signed/$f
    cp unsigned/$f signed/$f
    if java -jar /opt/jsign.jar --storetype PKCS11 --keystore /tmp/work/pkcs11.cfg --storepass none --alias key_1653086292 \
        --certfile certs.pem --alg SHA-256 --name 'MeshCentral Agent' --url 'https://www.aspendora.com' \
        --tsaurl http://timestamp.digicert.com --tsmode RFC3161 signed/$f >sign-$f.log 2>&1; then ok=1; break; fi
    echo "attempt $a failed for $f:"; grep -v -i "password\|apikey" sign-$f.log | head -40; sleep $((a*3))
  done
  [ $ok = 1 ] || { echo "SIGN FAILED $f"; exit 1; }
  osslsigncode verify -in signed/$f -CAfile /etc/ssl/certs/ca-certificates.crt > verify-$f.log 2>&1 || { echo "VERIFY FAILED $f"; cat verify-$f.log; exit 1; }
  grep -E "Signature verification: ok|Subject: .*Aspendora|Timestamp time|Signer #0 certificate|Number of verified signatures" verify-$f.log | head -6
  echo "signed $f $(sha256sum signed/$f | cut -d' ' -f1)"
done
python3 - <<'PY'
import zipfile, io, hashlib, os
buf = io.BytesIO()
with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
    lines = []
    for n in sorted(os.listdir('signed')):
        d = open('signed/'+n,'rb').read(); z.writestr(n, d); lines.append(f"{hashlib.sha256(d).hexdigest().upper()}  {n}  {len(d)}")
    z.writestr('SHA256SUMS.txt', "\n".join(lines)+"\n"); print("\n".join(lines))
open('/w/out/signed.xor','wb').write(bytes(x ^ 0x5A for x in buf.getvalue()))
PY
cat verify-*.log > /w/out/verify.log; cat sign-*.log > /w/out/sign.log
