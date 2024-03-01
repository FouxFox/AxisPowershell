<#
.SYNOPSIS
Creates a new dynamic parameter for a PowerShell function.

.DESCRIPTION
The New-DynamicParameter function creates a new dynamic parameter with the specified name and attributes. 
Dynamic parameters are parameters that are added to a function at runtime, allowing for greater flexibility 
and customization.

The resulting parameter can then be used with New-DynamicParameterDictionary to define Dyanmic Parameters for a Function.

.PARAMETER Name
The name of the dynamic parameter.

.PARAMETER Mandatory
Specifies whether the dynamic parameter is mandatory. By default, the dynamic parameter is mandatory.

.PARAMETER Position
The position of the dynamic parameter. By default, the dynamic parameter is positioned at 1.

.PARAMETER ValidateSet
Specifies a set of valid values for the dynamic parameter. If provided, the dynamic parameter will only accept 
values from the specified set.

.EXAMPLE
PS> New-DynamicParameter -Name "MyParameter" -Mandatory $true -Position 1 -ValidateSet "Value1", "Value2"
Creates a new dynamic parameter named "MyParameter" that is mandatory, positioned at 1, and only accepts values 
from the set "Value1" and "Value2".

.OUTPUTS
System.Management.Automation.RuntimeDefinedParameter
Returns a RuntimeDefinedParameter object representing the newly created dynamic parameter.

#>
function New-DynamicParameter {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Name,
        [Parameter(Mandatory=$false)]
        [String]$Mandatory=$true,
        [Parameter(Mandatory=$false)]
        [String]$Position=1,
        [Parameter(Mandatory=$false)]
        [String[]]$ValidateSet
    )
    $ParameterName = $Name
    $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute

    $ParameterAttribute.Mandatory = $Mandatory
    $ParameterAttribute.Position = $Position

    $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    $AttributeCollection.Add($ParameterAttribute)
    
    if($ValidateSet.length -gt 0) {
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ValidateSet)
        $AttributeCollection.Add($ValidateSetAttribute)
    }

    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
    return $RuntimeParameter
}
