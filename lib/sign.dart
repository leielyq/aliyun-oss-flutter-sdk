import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'common.dart';

enum SignType {
  signHeader, signUrl
}

class SignedInfo {
  final String dateString;
  final String accessKeyId;
  final String signature;
  final String securityToken;

  SignedInfo({
    @required this.dateString,
    @required this.accessKeyId,
    @required this.signature,
    this.securityToken,
  }): assert(dateString != null),
      assert(accessKeyId != null),
      assert(signature != null);

  static const headerSecurityToken = 'x-oss-security-token';

  Map<String, String> toHeaders() => {
    'Date': dateString,
    'Authorization': 'OSS $accessKeyId:$signature',
    if (securityToken != null) headerSecurityToken: securityToken,
  };

  static const keySecurityToken = 'security-token';

  /// [signature] need [Uri.encodeQueryComponent]
  Map<String, String> toQueryParams() => {
    'OSSAccessKeyId': accessKeyId,
    'Expires': dateString,
    'Signature': signature,
    if (securityToken != null) keySecurityToken: securityToken,
  };
}

class Signer {
  final Credentials credentials;

  Signer(this.credentials): assert(credentials != null);

  /// [dateString]  `Date` in [HttpDate] or `Expires` in [DateTime.secondsSinceEpoch]
  SignedInfo sign({
    @required String httpMethod,
    @required String resourcePath,
    Map<String, String> parameters,
    Map<String, Object> headers,
    String contentMd5,
    String dateString,
    SignType signType = SignType.signHeader,
  }) {
    assert(httpMethod != null);
    assert(resourcePath != null);

    var securityHeaders = {
      if (headers != null) ...headers,
      if (credentials.securityToken != null && signType == SignType.signHeader)
        SignedInfo.headerSecurityToken: credentials.securityToken,
    };
    var sortedPairs = securityHeaders.entries
        .map((e) => MapEntry(e.key.toLowerCase().trim(), e.value.toString().trim()))
        .toList()..sort((a, b) => a.key.compareTo(b.key));
    var contentType = sortedPairs.firstWhere(
      (e) => e.key == HttpHeaders.contentTypeHeader,
      orElse: () => MapEntry('', ''),
    ).value;
    var canonicalizedOSSHeaders = sortedPairs
        .where((e) => e.key.startsWith('x-oss-'))
        .map((e) => '${e.key}:${e.value}')
        .join('\n');

    var securityParameters = {
      if (parameters != null) ...parameters,
      if (credentials.securityToken != null && signType == SignType.signUrl)
        SignedInfo.keySecurityToken: credentials.securityToken,
    };
    var canonicalizedResource = _buildCanonicalizedResource(resourcePath, securityParameters);

    var date = dateString ?? HttpDate.format(DateTime.now());
    var canonicalString = [
      httpMethod,
      contentMd5 ?? '',
      contentType,
      date,
      if (canonicalizedOSSHeaders.isNotEmpty) canonicalizedOSSHeaders,
      canonicalizedResource,
    ].join('\n');

    var signature = _computeHmacSha1(canonicalString);
    return SignedInfo(
      dateString: date,
      accessKeyId: credentials.accessKeyId,
      signature: signature,
      securityToken: credentials.securityToken,
    );
  }

  String _buildCanonicalizedResource(String resourcePath, Map<String, String> parameters) {
    if (parameters?.isNotEmpty == true) {
      var queryString = parameters.entries.map((e) => '${e.key}=${e.value}').join('&');
      return '$resourcePath?$queryString';
    }
    return resourcePath;
  }

  String _computeHmacSha1(String plaintext) {
    var digest = Hmac(sha1, utf8.encode(credentials.accessKeySecret)).convert(utf8.encode(plaintext));
    return base64.encode(digest.bytes);
  }
}