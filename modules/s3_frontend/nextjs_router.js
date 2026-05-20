// CloudFront Function: Next.js Static Export router
// Rewrites URIs so per-route HTML files (one per route, produced by
// `next build` with `output: "export"`) resolve correctly out of S3:
//
//   /login/        →  /login/index.html        (trailing-slash directory route)
//   /tenants       →  /tenants/index.html      (extensionless route)
//   /script.js     →  /script.js               (extension → untouched, static asset)
//   /              →  /index.html              (root)
//
// Without this rewrite S3 returns 404 for `/foo/` because there is no
// `foo/` object key, and the distribution's custom_error_response fallback
// would serve the global SPA root for every multi-page route — defeating
// pre-rendering and breaking redirects that target the current URL.

function handler(event) {
    var request = event.request;
    var uri = request.uri;

    if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
    } else if (!uri.includes('.')) {
        request.uri = uri + '/index.html';
    }

    return request;
}
