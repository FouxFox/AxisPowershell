#Pulled from https://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell
#Preforms a deep copy of the config

function Copy-Config {
    $memStream = new-object IO.MemoryStream
    $formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($memStream,$script:Config)
    $memStream.Position=0
    $formatter.Deserialize($memStream)
}