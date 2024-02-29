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