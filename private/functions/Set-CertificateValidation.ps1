function Set-CertificateValidation {
    [cmdletbinding()]
    Param(
        #[Parameter(Mandatory,ParameterSetName='Enable')]
        #[Switch]$Enable,

        [Parameter(Mandatory,ParameterSetName='Disable')]
        [Switch]$Disable
    )

    $IsEnabled = [System.Net.ServicePointManager]::CertificatePolicy.GetType().Name -ne 'TrustAllCertsPolicy'

    if ($Enable -and !$IsEnabled) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    }
    if ($Disable -and $IsEnabled) {
        # This does not work
        #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$false}
        add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }
}