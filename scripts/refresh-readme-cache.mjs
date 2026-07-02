import { readFile, writeFile } from "node:fs/promises";

const readmePath = process.env.README_FILE || "README.md";
const cacheParam = process.env.CACHE_PARAM || "cache_bust";
const cacheKey = sanitizeCacheKey(
  process.env.CACHE_BUST || process.env.GITHUB_RUN_ID || process.env.GITHUB_SHA || Date.now()
);

const cacheTargets = [
  (src) => stripQuery(src) === "./assets/github-overview.svg",
  (src) => stripQuery(src) === "./assets/github-languages.svg",
  (src) => stripQuery(src) === "./assets/github-language-stats.svg",
  (src) => src.includes("github-readme-activity-graph.vercel.app/graph"),
  (src) =>
    src.includes("raw.githubusercontent.com/") &&
    src.includes("github-contribution-grid-snake.svg"),
];

function sanitizeCacheKey(value) {
  const normalized = String(value).trim().replace(/[^a-zA-Z0-9._:-]/g, "-").slice(0, 160);

  return normalized || String(Date.now());
}

function stripQuery(src) {
  return src.split("#", 1)[0].split("?", 1)[0];
}

function splitUrl(src) {
  const hashIndex = src.indexOf("#");
  const beforeHash = hashIndex === -1 ? src : src.slice(0, hashIndex);
  const hash = hashIndex === -1 ? "" : src.slice(hashIndex);
  const queryIndex = beforeHash.indexOf("?");

  if (queryIndex === -1) {
    return { base: beforeHash, query: "", hash };
  }

  return {
    base: beforeHash.slice(0, queryIndex),
    query: beforeHash.slice(queryIndex + 1),
    hash,
  };
}

function upsertQueryParam(src, key, value) {
  const { base, query, hash } = splitUrl(src);
  const separator = query.includes("&amp;") ? "&amp;" : "&";
  const nextParam = `${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
  const params = query
    ? query
        .split(/&amp;|&/)
        .filter(Boolean)
        .filter((param) => decodeURIComponent(param.split("=", 1)[0]) !== key)
    : [];

  params.push(nextParam);

  return `${base}?${params.join(separator)}${hash}`;
}

function shouldRefresh(src) {
  return cacheTargets.some((matches) => matches(src));
}

function refreshHtmlImages(readme) {
  let updates = 0;
  const nextReadme = readme.replace(
    /(<img\b[^>]*\bsrc=["'])([^"']+)(["'][^>]*>)/gi,
    (match, prefix, src, suffix) => {
      if (!shouldRefresh(src)) return match;

      updates += 1;
      return `${prefix}${upsertQueryParam(src, cacheParam, cacheKey)}${suffix}`;
    }
  );

  return { readme: nextReadme, updates };
}

function refreshMarkdownImages(readme) {
  let updates = 0;
  const nextReadme = readme.replace(/(!\[[^\]]*\]\()([^)]+)(\))/g, (match, prefix, src, suffix) => {
    if (!shouldRefresh(src)) return match;

    updates += 1;
    return `${prefix}${upsertQueryParam(src, cacheParam, cacheKey)}${suffix}`;
  });

  return { readme: nextReadme, updates };
}

const originalReadme = await readFile(readmePath, "utf8");
const htmlResult = refreshHtmlImages(originalReadme);
const markdownResult = refreshMarkdownImages(htmlResult.readme);
const totalUpdates = htmlResult.updates + markdownResult.updates;

if (totalUpdates === 0) {
  throw new Error(`No cacheable README image targets were found in ${readmePath}.`);
}

await writeFile(readmePath, markdownResult.readme, "utf8");

console.log(
  `Refreshed ${totalUpdates} README image URL${totalUpdates === 1 ? "" : "s"} with ${cacheParam}=${cacheKey}.`
);
