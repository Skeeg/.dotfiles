#Add ZScaler certs
CERTIFICATE_BUNDLE="$HOME/.ssl/zscaler_bundle.pem"
REQUESTS_CA_BUNDLE=$CERTIFICATE_BUNDLE
CURL_CA_BUNDLE=$CERTIFICATE_BUNDLE
NODE_EXTRA_CA_CERTS=$CERTIFICATE_BUNDLE
AWS_CA_BUNDLE=$CERTIFICATE_BUNDLE
SSL_CERT_FILE=$CERTIFICATE_BUNDLE
HEX_CACERTS_PATH=$ZSCALER_CERTIFICATE_BUNDLE
export CERTIFICATE_BUNDLE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE NODE_EXTRA_CA_CERTS AWS_CA_BUNDLE SSL_CERT_FILE HEX_CACERTS_PATH
