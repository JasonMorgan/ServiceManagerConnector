#requires -module SMLets
#requires -module SevOne
param (
    [string[]]$SevOneServer = @(
        'Pdcd18-sevone01a'
        'Pdcd18-sevone02a'
        'Ndcd18-sevone01a'
        'Ndcd18-sevone02a'
      ),
    [pscredential]$SevOneCred,
    [pscredential]$ServiceManagerCred
  )

#region import modules
Import-Module 'D:\Program Files\Microsoft System Center 2012 R2\Service Manager\PowerShell\System.Center.Service.Manager.psd1'
Import-Module SMLets
Import-Module SevOne
#endregion import modules



#region Open ServiceManager connection
### Maybe something goes here
#endregion Open ServiceManager connection

#region Open SevOne Connection
Connect-SevOne -ComputerName pdcd18-sevone01a -Credential $SevOneCred
#endregion Open SevOne Connection

#region Read existing SevOne alerts in SM
$alerts = Get-SevOneAlert
$class = Get-SCSMClass -Name Microsoft.SystemCenter.WorkItem.SCOMIncident
$incidents = Get-SCClassInstance -Class $class
#Close closed alerts
#endregion Read existing SevOne alerts in SM

#region Write alerts to SM
$alerts = Get-SevOneAlert
foreach ($a in $alerts)
{
  $sev = #Something to set valid
  $impact = Get-SCSMEnumeration -Name System.WorkItem.TroubleTicket.ImpactEnum.Medium
  $urgency = Get-SCSMEnumeration -Name System.WorkItem.TroubleTicket.UrgencyEnum.Medium
  $props = @{
      AlertCustomField1 = 25
      Urgency = $urgency
      Impact = $impact
      Description = 'Test: Please ignore'
      Source = 'IncidentSourceEnum.System'
      Title = 'Test: Please ignore'
    }
}
#Tattoo incidents with SevOne AlertID
#endregion Write alerts to SM



<#
AlertId
Classification

Description
DisplayName

Id

LastModifiedSource

MonitoringObjectId

MonitoringRuleId

Priority

Source
Status
Title
Urgency

#>