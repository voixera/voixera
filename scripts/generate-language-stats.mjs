import { mkdir, writeFile } from "node:fs/promises";

const username = process.env.GITHUB_USERNAME || "drx347";
const token = process.env.GITHUB_TOKEN || "";
const languageOutput =
  process.env.LANGUAGE_OUTPUT_FILE ||
  process.env.OUTPUT_FILE ||
  "assets/github-languages.svg";
const overviewOutput =
  process.env.OVERVIEW_OUTPUT_FILE || "assets/github-overview.svg";

const headers = {
  Accept: "application/vnd.github+json",
  "User-Agent": "ridmi-github-stats",
  "X-GitHub-Api-Version": "2022-11-28",
};

if (token) {
  headers.Authorization = `Bearer ${token}`;
}

const colors = {
  JavaScript: "#f1e05a",
  TypeScript: "#3178c6",
  HTML: "#e34c26",
  CSS: "#663399",
  Python: "#3572A5",
  Java: "#b07219",
  PHP: "#4F5D95",
  Go: "#00ADD8",
  Rust: "#dea584",
  Vue: "#41b883",
  Lua: "#000080",
  Luau: "#00A2FF",
  MDX: "#fcb32c",
  "C++": "#f34b7d",
  C: "#555555",
  "C#": "#178600",
  Shell: "#89e051",
  PowerShell: "#012456",
  Batchfile: "#C1F12E",
  Dockerfile: "#384d54",
  SCSS: "#c6538c",
  Svelte: "#ff3e00",
  Astro: "#ff5d01",
  Kotlin: "#A97BFF",
  Dart: "#00B4AB",
  Ruby: "#701516",
};

const fallbackColors = [
  "#02731B",
  "#2ea043",
  "#56d364",
  "#238636",
  "#1f6feb",
  "#8957e5",
  "#db6d28",
  "#cf222e",
];

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function formatNumber(value) {
  return new Intl.NumberFormat("en-US").format(value);
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;

  const units = ["KB", "MB", "GB"];
  let value = bytes / 1024;
  let unit = units.shift();

  while (value >= 1024 && units.length) {
    value /= 1024;
    unit = units.shift();
  }

  return `${value >= 10 ? value.toFixed(0) : value.toFixed(1)} ${unit}`;
}

async function github(path) {
  const response = await fetch(`https://api.github.com${path}`, { headers });

  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${await response.text()}`);
  }

  return response.json();
}

async function getRepositories() {
  const repos = [];

  for (let page = 1; page <= 10; page += 1) {
    const batch = await github(
      `/users/${username}/repos?per_page=100&page=${page}&type=owner&sort=updated`
    );

    if (!batch.length) break;

    repos.push(...batch.filter((repo) => !repo.fork && !repo.archived));
  }

  return repos;
}

async function getLanguageTotals(repositories) {
  const totals = new Map();

  await Promise.all(
    repositories
      .filter((repo) => repo.size > 0)
      .map(async (repo) => {
        const languages = await github(`/repos/${username}/${repo.name}/languages`);

        for (const [language, bytes] of Object.entries(languages)) {
          totals.set(language, (totals.get(language) || 0) + bytes);
        }
      })
  );

  return [...totals.entries()]
    .map(([language, bytes]) => ({ language, bytes }))
    .sort((a, b) => b.bytes - a.bytes);
}

function animatedShell(width, height, title, desc) {
  return `<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="title desc">
  <title id="title">${escapeXml(title)}</title>
  <desc id="desc">${escapeXml(desc)}</desc>
  <style>
    .title { fill: #24292f; font: 700 18px Segoe UI, Ubuntu, Sans-Serif; }
    .overview-title { fill: #0366d6; font: 700 18px Segoe UI, Ubuntu, Sans-Serif; }
    .subtitle { fill: #57606a; font: 500 12px Segoe UI, Ubuntu, Sans-Serif; }
    .label { fill: #24292f; font: 500 14px Segoe UI, Ubuntu, Sans-Serif; }
    .value { fill: #24292f; font: 500 14px Segoe UI, Ubuntu, Sans-Serif; text-anchor: end; }
    .small { fill: #57606a; font: 600 12px Segoe UI, Ubuntu, Sans-Serif; }
    .icon { fill: #57606a; font: 700 15px Segoe UI, Ubuntu, Sans-Serif; text-anchor: middle; }
    .language-label { fill: #24292f; font: 600 13px Segoe UI, Ubuntu, Sans-Serif; }
    .language-percent { fill: #57606a; font: 500 13px Segoe UI, Ubuntu, Sans-Serif; }
  </style>
  <rect x="0.5" y="0.5" width="${width - 1}" height="${height - 1}" rx="8" fill="#ffffff" stroke="#d0d7de" />
  <g id="loader">
    <rect x="24" y="25" width="180" height="18" rx="9" fill="#eaeef2" />
    <rect x="24" y="60" width="${width - 48}" height="14" rx="7" fill="#eaeef2" />
    <rect x="24" y="92" width="${width - 92}" height="14" rx="7" fill="#eaeef2" />
    <rect x="24" y="124" width="${width - 138}" height="14" rx="7" fill="#eaeef2" />
    <rect x="-120" y="0" width="90" height="${height}" fill="#ffffff" opacity=".55">
      <animate attributeName="x" values="-120;${width + 80}" dur="1.15s" repeatCount="2" />
    </rect>
    <animate attributeName="opacity" values="1;1;0" keyTimes="0;.72;1" dur="1.45s" fill="freeze" />
  </g>
  <g id="content" opacity="0" transform="translate(0 8)">
    <animate attributeName="opacity" values="0;1" begin=".95s" dur=".45s" fill="freeze" />
    <animateTransform attributeName="transform" type="translate" values="0 8;0 0" begin=".95s" dur=".45s" fill="freeze" />`;
}

function closeSvg() {
  return `
  </g>
</svg>
`;
}

function renderOverview(user, repositories, languageTotals) {
  const width = 460;
  const height = 260;
  const totalStars = repositories.reduce((sum, repo) => sum + repo.stargazers_count, 0);
  const totalForks = repositories.reduce((sum, repo) => sum + repo.forks_count, 0);
  const publicRepos = user.public_repos ?? repositories.length;

  const stats = [
    ["☆", "Stars", totalStars],
    ["⑂", "Forks", totalForks],
    ["⇄", "All-time contributions", user.contributions || 0],
    ["±", "Lines of code changed", 0],
    ["◉", "Repository views (past two weeks)", 0],
    ["▣", "Repositories with contributions", publicRepos],
  ];

  const statBlocks = stats
    .map(([icon, label, value], index) => {
      const y = 74 + index * 27;

      return `
    <g transform="translate(24 ${y})">
      <text x="10" y="5" class="icon">${escapeXml(icon)}</text>
      <text x="32" y="5" class="label">${escapeXml(label)}</text>
      <text x="390" y="5" class="value">${formatNumber(value)}</text>
    </g>`;
    })
    .join("");

  return `${animatedShell(
    width,
    height,
    `${username} GitHub overview`,
    "Animated GitHub overview card."
  )}
    <text x="24" y="42" class="overview-title">${escapeXml(username)}'s GitHub Statistics</text>
    ${statBlocks}
${closeSvg()}`;
}

function renderLanguages(languageTotals) {
  const topLanguages = languageTotals.slice(0, 12);
  const totalBytes = languageTotals.reduce((sum, item) => sum + item.bytes, 0);
  const width = 460;
  const height = 260;
  const contentX = 24;
  const progressY = 64;
  const progressWidth = width - contentX * 2;
  const listY = 104;
  const columnWidth = 136;
  const rowHeight = 28;

  let nextSegmentX = 0;

  const progressSegments = topLanguages
    .map((item, index) => {
      const percent = totalBytes ? (item.bytes / totalBytes) * 100 : 0;
      const color = colors[item.language] || fallbackColors[index % fallbackColors.length];
      const segmentWidth =
        index === topLanguages.length - 1
          ? Math.max(0, progressWidth - nextSegmentX)
          : Math.max(1, Math.round((percent / 100) * progressWidth));
      const x = nextSegmentX;

      nextSegmentX += segmentWidth;

      return `<rect x="${contentX + x}" y="${progressY}" width="${segmentWidth}" height="12" fill="${color}">
        <animate attributeName="width" values="0;${segmentWidth}" begin="${(1.05 + index * 0.04).toFixed(2)}s" dur=".65s" fill="freeze" />
      </rect>`;
    })
    .join("");

  const rows = topLanguages
    .map((item, index) => {
      const percent = totalBytes ? (item.bytes / totalBytes) * 100 : 0;
      const x = contentX + (index % 3) * columnWidth;
      const y = listY + Math.floor(index / 3) * rowHeight;
      const color = colors[item.language] || fallbackColors[index % fallbackColors.length];

      return `
    <g transform="translate(${x} ${y})" opacity="0">
      <animate attributeName="opacity" values="0;1" begin="${(1.2 + index * 0.08).toFixed(2)}s" dur=".35s" fill="freeze" />
      <circle cx="5" cy="7" r="4.5" fill="${color}" />
      <text x="18" y="12" class="language-label">${escapeXml(item.language)}</text>
      <text x="18" y="12" dx="${Math.min(78, Math.max(44, item.language.length * 7))}" class="language-percent">${percent.toFixed(2)}%</text>
    </g>`;
    })
    .join("");

  const emptyState = '<text x="24" y="92" class="label">No language data found yet.</text>';

  return `${animatedShell(
    width,
    height,
    `${username} language statistics`,
    "Animated language card calculated from repository file sizes."
  )}
    <text x="24" y="42" class="title">Languages Used (By File Size)</text>
    <clipPath id="language-progress-clip">
      <rect x="${contentX}" y="${progressY}" width="${progressWidth}" height="12" rx="6" />
    </clipPath>
    <rect x="${contentX}" y="${progressY}" width="${progressWidth}" height="12" rx="6" fill="#eaeef2" />
    <g clip-path="url(#language-progress-clip)">
      ${progressSegments}
    </g>
    ${topLanguages.length ? rows : emptyState}
${closeSvg()}`;
}

async function writeSvg(path, svg) {
  const outputDirectory = path.split("/").slice(0, -1).join("/") || ".";

  await mkdir(outputDirectory, { recursive: true });
  await writeFile(path, svg, "utf8");
}

const [user, repositories] = await Promise.all([
  github(`/users/${username}`),
  getRepositories(),
]);
const languageTotals = await getLanguageTotals(repositories);

await writeSvg(overviewOutput, renderOverview(user, repositories, languageTotals));
await writeSvg(languageOutput, renderLanguages(languageTotals));

if (languageOutput !== "assets/github-language-stats.svg") {
  await writeSvg("assets/github-language-stats.svg", renderLanguages(languageTotals));
}

console.log(
  `Generated ${overviewOutput} and ${languageOutput} for ${username} from ${repositories.length} repositories.`
);
