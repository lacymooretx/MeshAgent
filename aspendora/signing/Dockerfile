FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends osslsigncode default-jre-headless ca-certificates python3 && rm -rf /var/lib/apt/lists/*
# jsign 7.1 from Maven Central, sha1 348919dd… (Maven .sha1), sha256 cfb48b07…
COPY jsign.jar /opt/jsign.jar
RUN echo "cfb48b07fdd2ee199bfc9e71d8dccdde67a799c4793602e446c7a101be62b3c4  /opt/jsign.jar" | sha256sum -c -
