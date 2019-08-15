class Credentials {
  final String accessKeyId;
  final String accessKeySecret;
  final String securityToken;

  Credentials(this.accessKeyId, this.accessKeySecret, [this.securityToken])
      : assert(accessKeyId != null),
        assert(accessKeySecret != null);
}

abstract class CredentialProvider {
  Future<Credentials> getCredentials();
}

class FederationCredentials extends Credentials {
  DateTime expiration;

  FederationCredentials.fromMap(Map<String, dynamic> map)
      : expiration = DateTime.parse(map['expiration']),
        super(map['accessKeyId'], map['accessKeySecret'], map['securityToken']);
}

abstract class FederationCredentialProvider implements CredentialProvider {
  FederationCredentials _ossFederationToken;

  Future<Credentials> getCredentials() async {
    var expire = _ossFederationToken?.expiration?.millisecondsSinceEpoch ?? 0;
    if (expire - DateTime.now().millisecondsSinceEpoch > Duration(minutes: 5).inMilliseconds) {
      return _ossFederationToken;
    }
    _ossFederationToken = await fetchFederationCredentials();
    return _ossFederationToken;
  }

  Future<FederationCredentials> fetchFederationCredentials();
}