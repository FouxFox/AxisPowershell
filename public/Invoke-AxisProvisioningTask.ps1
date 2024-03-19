function Invoke-AxisProvisioningTask {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String]$MacAddress
    )

    Provision-AxisDevice -Device $Device -MacAddress $MacAddress
}