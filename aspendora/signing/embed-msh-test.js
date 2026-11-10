const fs=require('fs'),cp=require('child_process'),eh=require('/e/exeHandler.js');
fs.mkdirSync('/tmp/x',{recursive:true});
const b=fs.readFileSync('/w/out/signed.xor'); for(let i=0;i<b.length;i++) b[i]^=0x5A; fs.writeFileSync('/tmp/x/s.zip',b);
cp.execSync('cd /tmp/x && unzip -q s.zip');
const msh='MeshName=embedtest\r\nMeshType=2\r\nMeshID=0x'+'AB'.repeat(48)+'\r\nServerID='+'CD'.repeat(48)+'\r\nMeshServer=wss://central.aspendora.com:443/agent.ashx\r\n';
const files=['MeshService64.exe','MeshService.exe','MeshServiceARM64.exe']; let n=0;
for(const f of files){
  const out=fs.createWriteStream('/tmp/x/emb-'+f);
  out.on('finish',()=>{ if(++n==files.length){
    for(const g of files){ let r; try{r=cp.execSync('osslsigncode verify -in /tmp/x/emb-'+g+' -CAfile /etc/ssl/certs/ca-certificates.crt 2>&1').toString()}catch(e){r=e.stdout.toString()}
      console.log(g, r.split('\n').filter(l=>/verification:|Number of verified|Calculated|Current message digest/.test(l)).join(' | ')); }
    cp.execSync('cd /tmp/x && zip -q emb.zip emb-*.exe');
    const z=fs.readFileSync('/tmp/x/emb.zip'); for(let i=0;i<z.length;i++) z[i]^=0x5A; fs.mkdirSync('/w/embed/out',{recursive:true}); fs.writeFileSync('/w/embed/out/embedded.xor',z);
  }});
  eh.streamExeWithMeshPolicy({platform:'win32',sourceFileName:'/tmp/x/'+f,destinationStream:out,msh});
}
