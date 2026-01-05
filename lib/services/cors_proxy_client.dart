import 'package:http/http.dart' as http;

/// A HTTP client wrapper that routes all requests through a CORS proxy.
/// This is needed for web browsers that block cross-origin requests.
class CorsProxyClient extends http.BaseClient {
  final http.Client _inner;
  final String _proxyBaseUrl;

  /// Creates a CORS proxy client.
  ///
  /// [proxyBaseUrl] should be like `https://corsproxy.io/?` - the target URL
  /// will be appended (URL encoded) to this.
  CorsProxyClient(this._proxyBaseUrl) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Create a new request with the proxied URL
    final originalUrl = request.url.toString();
    final proxiedUrl = '$_proxyBaseUrl${Uri.encodeComponent(originalUrl)}';

    // Create new request with proxied URL
    final proxiedRequest = http.Request(request.method, Uri.parse(proxiedUrl));

    // Copy headers (except host)
    request.headers.forEach((key, value) {
      if (key.toLowerCase() != 'host') {
        proxiedRequest.headers[key] = value;
      }
    });

    // Copy body if it's a Request (not StreamedRequest)
    if (request is http.Request) {
      proxiedRequest.body = request.body;
    }

    return _inner.send(proxiedRequest);
  }

  @override
  void close() {
    _inner.close();
  }
}
