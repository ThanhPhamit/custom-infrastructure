// CloudFront Function: Next.js static-export router + canonical-domain redirect
//
// Two things happen on every viewer-request:
//
//   1. If the request's Host header doesn't match the canonical domain
//      (e.g. `www.example.com` reaching a site that lives at `example.com`),
//      return a 301 redirect to `https://<canonical>` preserving URI + query.
//
//   2. Otherwise apply the same per-route HTML rewrite as nextjs_router.js:
//        /              → /index.html
//        /about         → /about/index.html
//        /about/        → /about/index.html
//        /script.js     → /script.js   (extension → untouched)

var CANONICAL_HOST = "${canonical_domain}";

function handler(event) {
    var request = event.request;
    var host = request.headers.host && request.headers.host.value;
    var uri = request.uri;

    // 1. Canonical redirect — only when Host differs from the canonical.
    if (host && host !== CANONICAL_HOST) {
        var query = "";
        if (request.querystring) {
            var parts = [];
            for (var key in request.querystring) {
                var v = request.querystring[key];
                if (v.multiValue) {
                    for (var i = 0; i < v.multiValue.length; i++) {
                        parts.push(key + "=" + v.multiValue[i].value);
                    }
                } else {
                    parts.push(key + "=" + v.value);
                }
            }
            if (parts.length > 0) {
                query = "?" + parts.join("&");
            }
        }

        return {
            statusCode: 301,
            statusDescription: "Moved Permanently",
            headers: {
                "location": { value: "https://" + CANONICAL_HOST + uri + query },
                "cache-control": { value: "max-age=3600" }
            }
        };
    }

    // 2. URI rewrite for Next.js static export.
    if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
    } else if (!uri.includes('.')) {
        request.uri = uri + '/index.html';
    }

    return request;
}
