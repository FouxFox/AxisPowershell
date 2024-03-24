function Invoke-AxisProvisioningTask {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$MacAddress
    )

    Provision-AxisDevice -Device $Device -MacAddress $MacAddress
}