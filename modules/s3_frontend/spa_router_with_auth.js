// CloudFront Function: SPA Router with Basic Auth
// Combines basic authentication + SPA routing
// Serves index.html for all routes without file extension

function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var uri = request.uri;
    var authString = "Basic ${authString}";

    // Basic Auth check
    if (
        typeof headers.authorization === "undefined" ||
        headers.authorization.value !== authString
    ) {
        return {
            statusCode: 401,
            statusDescription: "Unauthorized",
            headers: { "www-authenticate": { value: "Basic" } }
        };
    }

    // SPA Routing: Serve index.html for all routes without file extension
    // Static assets (.js, .css, .png, etc.) are served normally
    if (!uri.includes('.') || uri.endsWith('/')) {
        request.uri = '/index.html';
    }

    return request;
}
