import { readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const svgDirectory = process.env.SVG_CACHE_DIR || process.argv[2] || "dist";
const cacheKey = sanitizeCacheKey(
  process.env.CACHE_BUST || process.env.GITHUB_RUN_ID || process.env.GITHUB_SHA || Date.now()
);
const markerPattern = /\n?\s*<!-- cache-bust: [\s\S]*? -->\s*(?=<\/svg>)/i;

function sanitizeCacheKey(value) {
  const normalized = String(value).trim().replace(/[^a-zA-Z0-9._:-]/g, "-").slice(0, 160);

  return normalized || String(Date.now());
}

function stampSvg(svg) {
  const marker = `\n  <!-- cache-bust: ${cacheKey} -->\n`;
  const withoutOldMarker = svg.replace(markerPattern, "\n");

  if (withoutOldMarker.includes("</svg>")) {
    return withoutOldMarker.replace(/\s*<\/svg>\s*$/i, `${marker}</svg>\n`);
  }

  return `${withoutOldMarker.trimEnd()}${marker}`;
}

const entries = await readdir(svgDirectory, { withFileTypes: true });
const svgFiles = entries.filter((entry) => entry.isFile() && entry.name.endsWith(".svg"));

await Promise.all(
  svgFiles.map(async (entry) => {
    const filePath = join(svgDirectory, entry.name);
    const svg = await readFile(filePath, "utf8");

    await writeFile(filePath, stampSvg(svg), "utf8");
  })
);

console.log(
  `Stamped ${svgFiles.length} SVG file${svgFiles.length === 1 ? "" : "s"} in ${svgDirectory} with cache-bust: ${cacheKey}.`
);
