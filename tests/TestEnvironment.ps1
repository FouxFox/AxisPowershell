Function InitTestEnvironment {
	#Credential Object for Testing
    $TestPassword = ConvertTo-SecureString -Force -AsPlainText -String "password"
	$Param = @{
		Name = 'TestCredential'
		Option = 'ReadOnly'
		Scope = 'Global'
		Value = New-Object System.Management.Automation.PSCredential ("u@example.onmicrosoft.com",$TestPassword)
	}
	Set-Variable @Param

    $Param = @{
		Name = 'TestDevice_IP'
		Option = 'ReadOnly'
		Scope = 'Global'
		Value = '1.1.1.1'
	}
	Set-Variable @Param

    #Config Object for Testing
	$Param = @{
		Name = 'TestConfig'
		Option = 'ReadOnly'
		Scope = 'Global'
		Value = @{
            Credential = ''
            CurrentDevice = $false
            Headers = @{
                'Content-Type' = 'application/json'
            }
            DisableCameraViews = @{
                "P3719-PLE" = @("Image.I4.Enabled")
                "P4707-PLVE" = @("Image.I2.Enabled")
            }
            RecordingParams = "videocodec=h265&fps=30&compression=30&videozstrength=20&videozgopmode=dynamic&videozmaxgoplength=1023&videozprofile=storage"
            FirmwareFolder = "C:\"
			SchemaVersion = 1
        }
	}
	Set-Variable @Param

	$Param = @{
		Name = 'Test_BeforeAll'
		Option = 'ReadOnly'
		Scope = 'Global'
		Value = {
			#Setup Variables
			$Script:Config = Copy-Object $TestConfig
			$Script:Config.Credential = $TestCredential
			$Script:Cache = @{"192.168.0.100"=@{Type="https"}}
		}
	}
	Set-Variable @Param

	$Param = @{
		Name = 'm'
		Option = 'ReadOnly'
		Scope = 'Global'
		Value = @{
			ModuleName = 'AxisPowerShell'
		}
	}
	Set-Variable @Param
	
	#Pulled from https://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell
	function Global:Copy-Object {
		param($DeepCopyObject)
		$memStream = new-object IO.MemoryStream
		$formatter = new-object Runtime.Serialization.Formatters.Binary.BinaryFormatter
		$formatter.Serialize($memStream,$DeepCopyObject)
		$memStream.Position=0
		$formatter.Deserialize($memStream)
	}

	function Global:reload { 
		Remove-Module AxisPowershell -Force -Confirm:$false -ErrorAction SilentlyContinue
		Import-Module C:\Users\msmall\Source\powershell\modules\AxisPowershell 
	}

    # Test Mode must be set before testing
    $Env:ModuleTools_TestMode = 1

    #Import Module
    $Script:ModulePath = "$PSScriptRoot\..\..\AxisPowershell"
    Import-Module -DisableNameChecking $Script:ModulePath
}

Function TerminateTestEnvironment {
	$Vars = @(
		'TestCredential'
		'TestConfig'
        'TestDevice_IP'
		'Test_BeforeAll'
		'm'
	)
	$vars | ForEach-Object {
		Remove-Variable $_ -Force -Scope Global
	}

	Remove-Item -Path Function:\Copy-Object
	Remove-Item -Path Function:\reload

	#Cleanup
    $Env:ModuleTools_TestMode = 0
    Remove-Module AxisPowershell
}

InitTestEnvironment