<#
.SYNOPSIS
Creates a dynamic parameter dictionary.

.DESCRIPTION
The New-DynamicParameterDictionary function creates a dynamic parameter dictionary using the specified parameters.

.PARAMETER Parameters
Specifies an array of RuntimeDefinedParameter objects that define the parameters for the dynamic parameter dictionary.

.EXAMPLE
function New-AnimalDirection {
    [cmdletbinding()]
    Param()
    DynamicParam {
        $parameters = @()
        $parameters += New-DynamicParameter -Name "Animal" -Mandatory $true -Position 1 -ValidateSet "Cat", "Dog"
        $parameters += New-DynamicParameter -Name "Direction" -Mandatory $true -Position 1 -ValidateSet "Left", "Right"
        New-DynamicParameterDictionary -Parameters $parameters
    }
}

.OUTPUTS
System.Management.Automation.RuntimeDefinedParameterDictionary
#>

function New-DynamicParameterDictionary {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.RuntimeDefinedParameter[]]$Parameters
    )

    $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    ForEach ($Parameter in $Parameters) {
        $RuntimeParameterDictionary.Add($Parameter.Name, $Parameter)
    }

    return $RuntimeParameterDictionary
}