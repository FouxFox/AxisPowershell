<#
.SYNOPSIS
Converts a PSCustomObject to a hashtable.

.DESCRIPTION
The ConvertTo-HashTable function takes a PSCustomObject as input and converts it into a hashtable. 
It recursively traverses the object's properties and creates nested hashtables for any properties that are also PSCustomObjects.
This is primarily used when parsing JSON via ConvertFrom-JSON.

.PARAMETER root
The root PSCustomObject to be converted to a hashtable.

.EXAMPLE
$object = [PSCustomObject]@{
    Name = "John"
    Age = 30
    Address = [PSCustomObject]@{
        Street = "123 Main St"
        City = "New York"
        Country = "USA"
    }
}

$hashTable = ConvertTo-HashTable -root $object

# $hashTable will contain the following hashtable:
# @{
#     Name = "John"
#     Age = 30
#     Address = @{
#         Street = "123 Main St"
#         City = "New York"
#         Country = "USA"
#     }
# }
#>

function ConvertTo-HashTable {
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [PSCustomObject]$root
    )

    $HashTable = @{}

    $Keys = [array]$root.psobject.Members | Where-Object { $_.MemberType -eq 'NoteProperty' }

    $Keys | ForEach-Object {
        $Key = $_.Name
        $Value = $_.Value
        if($Value.GetType().Name -eq 'PSCustomObject') {
            $NestedHashTable = ConvertTo-HashTable $Value
            $HashTable.add($Key,$NestedHashTable)
        }
        else {
           $HashTable.add($Key,$Value)
        }
    }
    return $HashTable
}