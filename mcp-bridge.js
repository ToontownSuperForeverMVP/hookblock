const net = require('net');

const HOST = '127.0.0.1';
const PORT = 7111;

const client = new net.Socket();

// Pipe stdin to socket IMMEDIATELY to catch early data
process.stdin.pipe(client);
// Pipe socket to stdout
client.pipe(process.stdout);

client.connect(PORT, HOST, () => {
    // optional debug logging to stderr if needed
});


client.on('error', (err) => {
    console.error(`[Bridge Error] ${err.message}`);
    process.exit(1);
});

client.on('close', () => {
    process.exit(0);
});
