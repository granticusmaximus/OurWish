import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

const svgPath = path.join(repoRoot, 'src', 'assets', 'ourwish-logo.svg');
const buildResourcesDir = path.join(repoRoot, 'build-resources');
const iconsetDir = path.join(buildResourcesDir, 'icon.iconset');
const renderedPngPath = path.join(buildResourcesDir, 'ourwish-logo.svg.png');
const iconPngPath = path.join(buildResourcesDir, 'icon.png');
const iconIcnsPath = path.join(buildResourcesDir, 'icon.icns');

function tryExec(binary, args) {
  try {
    execFileSync(binary, args, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

if (!fs.existsSync(svgPath)) {
  throw new Error(`Missing logo SVG: ${svgPath}`);
}

fs.mkdirSync(buildResourcesDir, { recursive: true });
fs.rmSync(iconsetDir, { recursive: true, force: true });
fs.mkdirSync(iconsetDir, { recursive: true });

const qlRendered = tryExec('/usr/bin/qlmanage', ['-t', '-s', '1024', '-o', buildResourcesDir, svgPath]);
if (qlRendered && fs.existsSync(renderedPngPath)) {
  fs.copyFileSync(renderedPngPath, iconPngPath);
} else {
  const sipsRendered = tryExec('/usr/bin/sips', ['-s', 'format', 'png', svgPath, '--out', iconPngPath]);
  if (!sipsRendered || !fs.existsSync(iconPngPath)) {
    if (!fs.existsSync(iconPngPath)) {
      throw new Error('Failed to rasterize SVG to PNG. Install/allow qlmanage or sips.');
    }
    console.warn('Rasterization blocked; using existing build-resources/icon.png');
  }
}

const sizes = [16, 32, 128, 256, 512];
for (const size of sizes) {
  const out1x = path.join(iconsetDir, `icon_${size}x${size}.png`);
  const out2x = path.join(iconsetDir, `icon_${size}x${size}@2x.png`);
  execFileSync('/usr/bin/sips', ['-z', String(size), String(size), iconPngPath, '--out', out1x], {
    stdio: 'ignore'
  });
  execFileSync('/usr/bin/sips', ['-z', String(size * 2), String(size * 2), iconPngPath, '--out', out2x], {
    stdio: 'ignore'
  });
}

const iconutilSucceeded = tryExec('/usr/bin/iconutil', ['-c', 'icns', iconsetDir, '-o', iconIcnsPath]);
if (!iconutilSucceeded && !fs.existsSync(iconIcnsPath)) {
  throw new Error('Failed to generate icon.icns and no existing icon.icns is available.');
}
if (!iconutilSucceeded) {
  console.warn('iconutil failed; using existing build-resources/icon.icns');
}

console.log('Generated build-resources/icon.png and build-resources/icon.icns');
