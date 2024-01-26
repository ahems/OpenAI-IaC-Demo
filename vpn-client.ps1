$env:RESOURCE_GROUP='OpenAI-Demo'
$env:LOCATION='eastus'
$env:VPN_Gateway_Name='VPN-Gateway'

Connect-AzAccount

# Generate Certificate on Windows 10
# https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#ex2

# 1) Create a self-signed root certificate
$params = @{
    Type = 'Custom'
    Subject = 'CN=P2SRootCert'
    KeySpec = 'Signature'
    KeyExportPolicy = 'Exportable'
    KeyUsage = 'CertSign'
    KeyUsageProperty = 'Sign'
    KeyLength = 2048
    HashAlgorithm = 'sha256'
    NotAfter = (Get-Date).AddMonths(24)
    CertStoreLocation = 'Cert:\CurrentUser\My'
}
$cert = New-SelfSignedCertificate @params


# 2) Generate a client certificate from the root cert created above
$params = @{
    Type = 'Custom'
    Subject = 'CN=P2SChildCert'
    DnsName = 'P2SChildCert'
    KeySpec = 'Signature'
    KeyExportPolicy = 'Exportable'
    KeyLength = 2048
    HashAlgorithm = 'sha256'
    NotAfter = (Get-Date).AddMonths(18)
    CertStoreLocation = 'Cert:\CurrentUser\My'
    Signer = $cert
    TextExtension = @(
     '2.5.29.37={text}1.3.6.1.5.5.7.3.2')
}
New-SelfSignedCertificate @params

# 3) Export the root certificate public key (.cer) to C:\temp\P2SRootCert.cer





# Configure Server
# https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-rm-ps

# Upload Root Certificate using Portal

#  Generate VPN client configuration files
#  https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal#generatevpnclientconfigurationfiles

$env:profile=New-AzVpnClientConfiguration -ResourceGroupName $env:RESOURCE_GROUP -Name $env:VPN_Gateway_Name -AuthenticationMethod "EapTls"
$profile.VPNProfileSASUrl


# Configure Azure VPN Client
# https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-vpn-client-cert-windows#azurevpn