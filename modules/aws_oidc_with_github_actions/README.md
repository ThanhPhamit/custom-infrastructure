# Generate the Thumbprint

To generate the thumbprint, you can use the following OpenSSL command to get the SHA-1 thumbprint of the OIDC provider's certificate. For example, if you are using GitHub as the OIDC provider:

```sh
echo | openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}'
```

This command will output the SHA-1 thumbprint of the certificate.