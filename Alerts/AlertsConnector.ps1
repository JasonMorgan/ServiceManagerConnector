#requires -module SevOne
param (
    [string]$SevOneServer = 'Pdcd18-sevone01a',
    [string]$ServiceManagerServer = $env:COMPUTERNAME,
    [Parameter(Mandatory)]
    [pscredential]$SevOneCred,
    [pscredential]$ServiceManCred
  )
  
 
#region import modules
Import-Module 'D:\Program Files\Microsoft System Center 2012 R2\Service Manager\PowerShell\System.Center.Service.Manager.psd1'
#Import-Module Microsoft.EnterpriseManagement.Core.Cmdlets -Force
Import-Module SMLets
Import-Module SevOne
#endregion import modules

#region Open SCSM Connection
Try {New-SCManagementGroupConnection -ComputerName $ServiceManagerServer -Credential $ServiceManCred }
catch {
    $Error | fl * -Force
    #$Error | Export-Clixml C:\ISDps\Connectors\errors.xml
    Throw "Unable to connect to Service Manager Instance @ $ServiceManagerServer"} #>
#endregion Open SCSM Connection

#region Open SevOne Connection
try {Connect-SevOne -ComputerName $SevOneServer -Credential $SevOneCred -ErrorAction Stop}
catch {
    # create incident
    throw "Failed to connect ot SevOne server @ $SevOneServer"
  }
#endregion Open SevOne Connection

#region Draw Sources
Write-Verbose "Building Variables"
$alerts = Get-SevOneAlert | Where-Object {$_.message -notmatch '\[dev\]'}
$alerts_Hash = @{}
$alerts | foreach {$alerts_Hash.Add($_.id,$_)}
Write-Verbose 'Creating Class object'
$class = Get-SCClass -Name SevOne.PAS.WorkIten.SevOneIncident
Write-Debug "ClassName = $($class.Name)"
$Inc_Hash = @{}
Write-Verbose 'Collecting open incidents'
$incidents = Get-SCClassInstance -Class $class -Filter "Status -eq Active"
Write-Verbose "$($incidents.Count) open incidents found"
Write-Debug 'Finished collecting open incidents'
$incidents | foreach {$Inc_Hash.Add($_.id,$_)}
Write-Verbose 'Collecting Incidents to be closed in SevOne'
Write-Verbose "Building filter for alerts to be closed"
$res = Get-SCSMEnumeration -Name 'IncidentStatusEnum.Resolved'
$closed = Get-SCSMEnumeration -Name 'IncidentStatusEnum.Closed'
$string = "(Status = '$($res.Id.Guid)' OR Status = '$($closed.id.guid)') AND AlertStatus='Open'"
$criteria =New-Object -TypeName Microsoft.EnterpriseManagement.Common.EnterpriseManagementObjectCriteria -ArgumentList $string,$class
Write-Verbose "$($Incidentstobeclosed.Count) INcidents waiting to be closed in SevOne"
Write-Debug 'Finished Collecting incidents'
$Incidentstobeclosed = Get-SCClassInstance -Criteria $criteria
Write-Verbose 'Building Device HashTable'
$Dev_hash =@{}
Get-SevOneDevice | foreach {$Dev_hash.Add($_.id,$_.name)}
Write-Debug 'Finished building Device HashTable $Dev_hash'
#endregion Draw Sources

#region Write alerts to SM
$NewAlerts = $alerts.where{$_.id -notin $incidents.AlertID}
foreach ($a in $NewAlerts)
{
  $impact = 'System.WorkItem.TroubleTicket.ImpactEnum.Medium' # might set this on the basis of the object
  $dev = $Dev_hash.item($a.deviceId)
  # I think we'll be ok for now just defaulting to medium
  # Alertnatively we could do it based on alert.message
  switch ($a.severity)
    {
      {$_ -le 3} { $urgency = 'System.WorkItem.TroubleTicket.UrgencyEnum.High' }
      {$_ -gt 3 -and $_ -le 5} { $urgency = 'System.WorkItem.TroubleTicket.UrgencyEnum.Medium' }
      {$_ -gt 5} { $urgency = 'System.WorkItem.TroubleTicket.UrgencyEnum.Low' }
    }
  

  # These properties are Case Sensitive!!!!
  $props = @{
      Id = "VzISDIR{0}"
      AlertID = [int]($a.id)
      Urgency = $urgency
      Impact = $impact
      Description =  $a.message
      #Source = 'Enum.c82f352a6ec04f539e7b6174bce07b8b'
      Title = 'SevOne: ' + $a.message.split('-')[0]
      DeviceName = $dev
      SevOneDeviceID = [int]($a.deviceId)
      Severity = [int]($a.severity)
      AlertStatus = 'Open'
      Status = 'IncidentStatusEnum.Active'
    }
  #Write-Debug "Finished creating properties for alert Id $($a.id)"
  $incident = New-SCClassInstance -Class $class -Property $props -PassThru -Verbose
  #return IncidentID
  Write-Verbose "New incident created: $($incident.Id)"
  Write-Debug "Finished creating incident for alert Id $($a.id)"
}
#endregion Write alerts to SM

#region Close Incidents with no Alerts
$incidents = $incidents | where {$_.Alertid -notin $alerts.id}
foreach ($i in $incidents)
  {
    Write-Verbose "Resolving incident for $($i.Id)"
    Write-Debug "About to resolve Incident"
    $i.status = 'IncidentStatusEnum.Resolved'
    $i.AlertStatus = 'Closed'
    $i.overwrite()
  }
#endregion Close Incidents with no Alerts

#region Close Alerts for resolved incidents
foreach ($i in $Incidentstobeclosed)
  {
    Write-Verbose "Closing SevOne Alert for $($i.Id)"
    Close-SevOneAlert -Alert $alerts_Hash.item($i.AlertID) -Message "Closed by Service Manager: $(Get-Date -Format MMddyyy_hhmmss)"
    $i.AlertStatus = 'Closed'
    $i.overwrite()
  }
#endregion Close Alerts for resolved incidents

exit $LASTEXITCODE