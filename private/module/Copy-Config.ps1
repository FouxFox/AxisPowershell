#Pulled from https://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell
#Preforms a deep copy of the config
#Binaryfomatter is now deprecated: https://learn.microsoft.com/en-us/dotnet/standard/serialization/binaryformatter-security-guide

function Copy-Config {
    return ($script:Config | ConvertTo-Json -Depth 100 | ConvertFrom-Json | ConvertTo-HashTable)
}