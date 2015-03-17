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

###### Still need filters

#region Draw Sources
$alerts = Get-SevOneAlert | Where-Object {$_.message -notmatch '\[dev\]'}
$class = Get-SCClass -Name SevOne.PAS.WorkIten.SevOneIncident
$Inc_Hash = @{}
$incidents = Get-SCClassInstance -Class $class # add filter to only include open incidents
$incidents | foreach {$Inc_Hash.Add($_.id,$_)}
$Incidentstobeclosed = Get-SCClassInstance -Class $class #add filter where status = resolved and AlertStatus = open
$Dev_hash =@{}
Get-SevOneDevice | foreach {$Dev_hash.Add($_.id,$_.name)}

#endregion Draw Sources

#region Write alerts to SM
$NewAlerts = $alerts.where{$_.id -notin $incidents.SevOneAlertID}
foreach ($a in $NewAlerts)
{
  $impact = Get-SCSMEnumeration -Name System.WorkItem.TroubleTicket.ImpactEnum.Medium # might set this on the basis of the object
  $dev = $Dev_hash.item($a.deviceId)
  # I think we'll be ok for now just defaulting to medium
  # Alertnatively we could do it based on alert.message
  switch ($a.severity)
    {
      {$_ -le 3} { $urgency = Get-SCSMEnumeration -Name System.WorkItem.TroubleTicket.UrgencyEnum.High }
      {$_ -gt 3 -and $_ -le 5} { $urgency = Get-SCSMEnumeration -Name System.WorkItem.TroubleTicket.UrgencyEnum.Medium }
      {$_ -gt 5} { $urgency = Get-SCSMEnumeration -Name System.WorkItem.TroubleTicket.UrgencyEnum.Low }
    }
  
  $props = @{
      ID = "VzISDIR{0}"
      AlertID = $a.id
      Urgency = $urgency
      Impact = $impact
      Description =  $a.message
      Source = (Get-SCSMEnumeration -Name "IncidentSourceEnum.System")
      Title = "SevOne: " + $a.message.split('-')[0]
      DeviceName = $dev
      SevOneDeviceId = $a.deviceId
      Severity = $a.severity
      AlertStatus = 'Open'
    }
  $incident = New-SCClassInstance -Class $class -Property $props -PassThru
  #return IncidentID

}
#endregion Write alerts to SM

#region Close Incidents with nIo Alerts
$incidents = $incidents.where{$_.SevOneAlertid -notin $alerts.id}
foreach ($i in $incidents)
  {
    
    #Resolve incident
  }
#endregion Close Incidents with no Alerts

#region Close Alerts for resolved incidents
foreach ($i in $Incidentstobeclosed)
  {
    Close-SevOneAlert -Alert $Inc_Hash.item($i.SevOneAlertID)
  }
#endregion Close Alerts for resolved incidents
<#

[int]AlertId
[string]DeviceName
[string]DeviceID
[int]SevOneSeverity
[string]SevOneAlertStatus #this should have been a duh moment, SevOne's API doesn't allow us to tatoo the alert
but that doesn't matter if we add this property.  On creation we set the value to open and we only change it 
after we have successfully sent a close message to SevOne.  I may actually be a genuis because all of my solutions
involve someone other than me doing the hard work ;)

#>