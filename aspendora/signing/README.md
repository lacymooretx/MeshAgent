# Signing the Windows agents (DigiCert KeyLocker, on the Mac)

Signing runs on the Mac in a linux/amd64 container (`aspendora/agent-signer:bookworm`): jsign 7.1 + DigiCert's `smpkcs11.so`.
The key never leaves the KeyLocker HSM. Plain .exe files never touch the Mac's filesystem (its Defender for Endpoint quarantines
MeshAgent binaries); they move as a zip XORed with 0x5A.

- Keypair `key_1653086292`, cert `cert_1653086292` (CN=Aspendora Technologies, LLC), SHA1 7353645A2DE4AABB1AC2E170ECE7F66538BCEEAD,
  valid 2026-11-10 to 2027-11-09. Renewal: CertCentral order 1653086292.
- Creds (Keeper → ~/.secrets/.env): SM_HOST, SM_API_KEY, SM_CLIENT_CERT_FILE (.p12), SM_CLIENT_CERT_PASSWORD.
- **A new keypair has no signer.** Fix in the UI: DigiCert ONE → KeyLocker → Certificates → the order → Manage signer → Add a signer.
  (`smctl keypair update-access` is enterprise-only and returns 403.)

## Steps
1. Build host: `build.ps1` writes `out\<sha>\unsigned.xor`. Pull it to `$W/in/unsigned.xor` (ControlR spool or device transfer).
2. Once: `docker build --platform linux/amd64 -t aspendora/agent-signer:bookworm .` (put jsign-7.1.jar from Maven Central next to the
   Dockerfile as jsign.jar; the Dockerfile checks its sha256). KeyLocker Linux tools: `Keylockertools-linux-x64.tar.gz` from
   one.digicert.com, extracted to `$W/klt/Keylockertools-linux-x64`. Chain: `smctl cert download --keypair-alias key_1653086292 -c -o $W -n chain -f pem`.
3. Sign:
   ```
   source ~/.secrets/.env; export SM_HOST SM_API_KEY SM_CLIENT_CERT_PASSWORD
   docker run --rm --platform linux/amd64 -e SM_HOST -e SM_API_KEY -e SM_CLIENT_CERT_PASSWORD -e SM_CLIENT_CERT_FILE=/p12/client.p12 \
     -v "$SM_CLIENT_CERT_FILE":/p12/client.p12:ro -v $W/klt/Keylockertools-linux-x64:/klt:ro -v $W:/w aspendora/agent-signer:bookworm sh /w/sign.sh
   ```
   Output `$W/out/signed.xor` + verify.log. Each signature uses one KeyLocker signature credit.
4. Optional: `embed-msh-test.js` (node:22-bookworm, mount the fork's MeshCentral `exeHandler.js` at /e) embeds an .msh the way the server
   does and re-verifies. The msh goes into the certificate table, which Authenticode does not hash, so the signature stays Valid
   (osslsigncode reports a PE checksum mismatch; Windows ignores it).
5. Transfer signed.xor to ASP-DEPLOY01, un-XOR, `Get-AuthenticodeSignature`, canary.
