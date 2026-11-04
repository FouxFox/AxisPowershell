Describe "Get-AxisAction" {
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }

    BeforeEach {
        Mock @m Invoke-AxisSoapRequest {
            $Xml = [xml]@"
<Body xmlns:aa="http://www.axis.com/vapix/ws/action1">
  <aa:GetActionConfigurationsResponse>
    <aa:ActionConfigurations>
      <aa:ActionConfiguration>
        <aa:ConfigurationID>3</aa:ConfigurationID>
        <aa:Name>Record to SD</aa:Name>
        <aa:TemplateToken>com.axis.action.unlimited.recording.storage</aa:TemplateToken>
        <aa:Parameters>
          <aa:Parameter Name="stream_options" Value="streamprofile=EdgeRecording"/>
          <aa:Parameter Name="storage_id" Value="SD_DISK"/>
        </aa:Parameters>
      </aa:ActionConfiguration>
    </aa:ActionConfigurations>
  </aa:GetActionConfigurationsResponse>
  <aa:GetActionRulesResponse>
    <aa:ActionRules>
      <aa:ActionRule>
        <aa:RuleID>7</aa:RuleID>
        <aa:Name>Continuous</aa:Name>
        <aa:Enabled>true</aa:Enabled>
        <aa:PrimaryAction>3</aa:PrimaryAction>
      </aa:ActionRule>
      <aa:ActionRule>
        <aa:RuleID>8</aa:RuleID>
        <aa:Name>Orphan</aa:Name>
        <aa:Enabled>false</aa:Enabled>
        <aa:PrimaryAction>99</aa:PrimaryAction>
      </aa:ActionRule>
    </aa:ActionRules>
  </aa:GetActionRulesResponse>
</Body>
"@
            return $Xml.DocumentElement
        }
    }

    Context "Action rule retrieval" {
        It "Calls GetActionConfigurations and GetActionRules over SOAP with the action1 namespace" {
            $null = Get-AxisAction -Device "192.168.0.100"
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*GetActionConfigurations*" -and $Namespaces.aa -eq "http://www.axis.com/vapix/ws/action1" } -Times 1
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*GetActionRules*" } -Times 1
        }

        It "Joins the rules with their action configurations" {
            $Result = @(Get-AxisAction -Device "192.168.0.100")
            $Result.Count | Should -Be 2
            $Result[0].ID | Should -Be "7"
            $Result[0].Name | Should -Be "Continuous"
            $Result[0].Enabled | Should -BeTrue
            $Result[0].TemplateToken | Should -Be "com.axis.action.unlimited.recording.storage"
            $Result[0].StreamOptions | Should -Be "streamprofile=EdgeRecording"
            $Result[0].StorageLocation | Should -Be "SD_DISK"
            $Result[0].PrimaryAction | Should -Be "3"
            $Result[1].Enabled | Should -BeFalse
            $Result[1].TemplateToken | Should -BeNullOrEmpty
        }

        It "Throws when the device cannot be reached" {
            Mock @m Invoke-AxisSoapRequest { Throw "SOAP Fault: nope" }
            { Get-AxisAction -Device "192.168.0.100" } | Should -Throw "*Unable to retrieve action rules*"
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
