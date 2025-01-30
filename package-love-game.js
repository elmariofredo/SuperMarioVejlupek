// package-love-game.js

const fs = require('fs');
const path = require('path');
const { Worker } = require('worker_threads');
const archiver = require('archiver');

// Configuration
const config = {
  mode: 'double_progress', // Options: single, double_progress, double_local
  filename: 'game',
  title: 'My LÖVE Game',
  description: 'A fun game built with LÖVE',
  author: 'Your Name',
  res_x: 800,
  res_y: 600,
  memory: 20, // In MB
  stack: 20,   // In MB
  files: ['main.lua', 'conf.lua', 'assets/'] // Add your game files here
};

// Output directory
const outputDir = path.resolve(__dirname, 'dist');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir);
}

// Function to create a ZIP archive
function createZip() {
  return new Promise((resolve, reject) => {
    const output = fs.createWriteStream(path.join(outputDir, `${config.filename}.zip`));
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', () => {
      console.log(`ZIP created: ${archive.pointer()} total bytes`);
      resolve();
    });

    archive.on('error', (err) => {
      reject(err);
    });

    archive.pipe(output);

    // Append files
    config.files.forEach(file => {
      const filePath = path.resolve(__dirname, file);
      if (fs.existsSync(filePath)) {
        const stats = fs.statSync(filePath);
        if (stats.isFile()) {
          archive.file(filePath, { name: path.basename(file) });
        } else if (stats.isDirectory()) {
          archive.directory(filePath, path.basename(file));
        }
      } else {
        console.warn(`Warning: File or directory not found - ${filePath}`);
      }
    });

    archive.finalize();
  });
}

// Function to build HTML file
async function buildHTML() {
  // Here you can integrate your existing JavaScript packaging logic.
  // For simplicity, we'll assume that the ZIP file is embedded into the HTML.

  const zipPath = path.join(outputDir, `${config.filename}.zip`);
  if (!fs.existsSync(zipPath)) {
    throw new Error('ZIP file not found. Run the packaging process first.');
  }

  const zipData = fs.readFileSync(zipPath, 'base64');

  const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${config.title}</title>
  <style>
    /* Add your styles here */
    body { background-color: #e0f4fc; margin: 0; font-family: sans-serif; }
    #gameCanvas { display: block; margin: 0 auto; background: #000; }
  </style>
</head>
<body>
  <h1 style="text-align:center;">${config.title}</h1>
  <canvas id="gameCanvas" width="${config.res_x}" height="${config.res_y}"></canvas>
  <script src="love.js"></script>
  <script>
    // Initialize the game using the embedded ZIP data
    const zipData = atob('${zipData}');
    const byteArray = new Uint8Array(zipData.length);
    for (let i = 0; i < zipData.length; i++) {
      byteArray[i] = zipData.charCodeAt(i);
    }

    // Here you can integrate the love.js initialization with the ZIP data
    // This is a placeholder for your actual initialization code
    console.log('Initializing LÖVE game with embedded ZIP data...');
  </script>
</body>
</html>
`;

  fs.writeFileSync(path.join(outputDir, `${config.filename}.html`), htmlContent, 'utf-8');
  console.log('HTML file created.');
}

// Main function to orchestrate packaging
async function main() {
  try {
    await createZip();
    await buildHTML();
    console.log('Packaging completed successfully.');
  } catch (error) {
    console.error('Error during packaging:', error);
    process.exit(1);
  }
}

main();
