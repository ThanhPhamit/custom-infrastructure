// CloudFront Function: SPA Router (No Auth)
// Serves index.html for all routes without file extension
// Supports client-side routing (Vue Router, React Router)

function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // SPA Routing: Serve index.html for all routes without file extension
    // Static assets (.js, .css, .png, etc.) are served normally
    if (!uri.includes('.') || uri.endsWith('/')) {
        request.uri = '/index.html';
    }

    return request;
}
