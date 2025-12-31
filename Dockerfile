FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=10000

RUN apt-get update && apt-get install -y \
  curl \
  nodejs \
  npm \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---------------- server.js ----------------
RUN cat << 'EOF' > server.js
const http = require("http");
const fs = require("fs");

const PORT = process.env.PORT || 10000;
const SUID_FILE = "/tmp/sshx_link.txt";

function getSuid() {
  try {
    return fs.readFileSync(SUID_FILE, "utf8").trim();
  } catch {
    return "not-ready";
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ message: "welcome" }));
  }

  if (req.url === "/halth") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({
      timestamp: new Date().toISOString(),
      suid: getSuid()
    }));
  }

  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log("HTTP server running on", PORT);
});
EOF

# ---------------- start.sh ----------------
RUN cat << 'EOF' > start.sh
#!/bin/sh
set -e

echo "[+] Starting sshx..."

# Start sshx and capture output
curl -sSf https://sshx.io/get | sh -s -- --shell bash > /tmp/sshx.log 2>&1 &

# Extract sshx link once it appears
(
  while true; do
    LINK=$(grep -o 'https://sshx.io/[a-zA-Z0-9_-]*' /tmp/sshx.log | head -n 1)
    if [ -n "$LINK" ]; then
      echo "$LINK" > /tmp/sshx_link.txt
      echo "[+] sshx link captured: $LINK"
      break
    fi
    sleep 1
  done
) &

echo "[+] Launching Node server"
exec node server.js
EOF

RUN chmod +x start.sh

EXPOSE 10000
CMD ["./start.sh"]
