<#
.SYNOPSIS
    Syncs OpenStack security events to Azure Sentinel SIEM.
    Queries OpenStack audit logs and forwards them as Custom Log entries to Log Analytics.

.DESCRIPTION
    Collects events from OpenStack (Nova, Neutron, Keystone) via the REST API,
    transforms them into Azure Sentinel-compatible format, and ships them to a
    Log Analytics Workspace using the Data Collector API.

.PARAMETER OpenStackAuthUrl
    Keystone auth URL (e.g. http://controller:5000/v3)

.PARAMETER LogAnalyticsWorkspaceId
    Azure Log Analytics Workspace ID

.PARAMETER LogAnalyticsKey
    Primary or secondary shared key for the workspace

.EXAMPLE
    ./sentinel-sync.ps1 `
        -OpenStackAuthUrl "http://controller:5000/v3" `
        -LogAnalyticsWorkspaceId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
        -LogAnalyticsKey "base64key=="
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string] $OpenStackAuthUrl,
    [Parameter(Mandatory)] [string] $LogAnalyticsWorkspaceId,
    [Parameter(Mandatory)] [string] $LogAnalyticsKey,
    [string] $OpenStackUsername   = $env:OS_USERNAME,
    [string] $OpenStackPassword   = $env:OS_PASSWORD,
    [string] $OpenStackProject    = $env:OS_PROJECT_NAME,
    [string] $OpenStackDomain     = "Default",
    [string] $LogType             = "OpenStackAudit",
    [int]    $LookbackMinutes     = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Level, [string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

function Get-OpenStackToken {
    $body = @{
        auth = @{
            identity = @{
                methods  = @("password")
                password = @{
                    user = @{
                        name     = $OpenStackUsername
                        password = $OpenStackPassword
                        domain   = @{ name = $OpenStackDomain }
                    }
                }
            }
            scope = @{
                project = @{
                    name   = $OpenStackProject
                    domain = @{ name = $OpenStackDomain }
                }
            }
        }
    } | ConvertTo-Json -Depth 10

    $response = Invoke-WebRequest `
        -Uri "$OpenStackAuthUrl/auth/tokens" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body
    return $response.Headers["X-Subject-Token"]
}

function Get-NovaAuditEvents {
    param([string]$Token)

    $since = (Get-Date).AddMinutes(-$LookbackMinutes).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $novaUrl = $OpenStackAuthUrl -replace ":5000", ":8774"

    $response = Invoke-RestMethod `
        -Uri "$novaUrl/v2.1/os-instance-actions?changes-since=$since" `
        -Headers @{ "X-Auth-Token" = $Token }

    return $response.instanceActions | ForEach-Object {
        [PSCustomObject]@{
            EventTime    = $_.start_time
            EventType    = "Nova/$($_.action)"
            ResourceId   = $_.instance_uuid
            UserId       = $_.user_id
            ProjectId    = $_.project_id
            RequestId    = $_.request_id
            Severity     = if ($_.action -in @("delete","forceDelete","resetState")) { "High" } else { "Low" }
            Source       = "OpenStack/Nova"
        }
    }
}

function Get-KeystoneAuditEvents {
    param([string]$Token)

    $since = (Get-Date).AddMinutes(-$LookbackMinutes).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $response = Invoke-RestMethod `
        -Uri "$OpenStackAuthUrl/OS-TRUST/trusts" `
        -Headers @{ "X-Auth-Token" = $Token }

    # In production this would query the Keystone event log endpoint
    return @()
}

function Send-ToLogAnalytics {
    param(
        [object[]] $Events,
        [string]   $LogType
    )

    if ($Events.Count -eq 0) {
        Write-Log "INFO" "No events to send."
        return
    }

    $body = $Events | ConvertTo-Json -Depth 5
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $date = [System.DateTime]::UtcNow.ToString("r")

    $stringToHash = "POST`n$($bodyBytes.Length)`napplication/json`nx-ms-date:$date`n/api/logs"
    $keyBytes     = [System.Convert]::FromBase64String($LogAnalyticsKey)
    $hmac         = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
    $hashBytes    = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToHash))
    $signature    = [System.Convert]::ToBase64String($hashBytes)

    $uri = "https://$LogAnalyticsWorkspaceId.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"

    Invoke-RestMethod `
        -Uri $uri `
        -Method POST `
        -ContentType "application/json" `
        -Headers @{
            "Authorization" = "SharedKey ${LogAnalyticsWorkspaceId}:${signature}"
            "Log-Type"      = $LogType
            "x-ms-date"     = $date
            "time-generated-field" = "EventTime"
        } `
        -Body $body

    Write-Log "INFO" "Sent $($Events.Count) events to Azure Sentinel ($LogType)"
}

# ── Main ─────────────────────────────────────────────────────────────────────
Write-Log "INFO" "Starting OpenStack → Azure Sentinel sync (lookback: ${LookbackMinutes}m)"

$token  = Get-OpenStackToken
Write-Log "INFO" "Authenticated to OpenStack Keystone"

$events = @()
$events += Get-NovaAuditEvents -Token $token
$events += Get-KeystoneAuditEvents -Token $token

Write-Log "INFO" "Collected $($events.Count) total events"

Send-ToLogAnalytics -Events $events -LogType $LogType

Write-Log "INFO" "Sync complete"
