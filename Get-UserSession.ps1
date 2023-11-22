function Get-UserSession {
    <#
    .SYNOPSIS
    Gets all user sessions on local machine or remote machine to be returned as ps objects
    
    .DESCRIPTION
    Script will accept an array of computer names, or ips and then run up to 8 simultaneous 'query user' commands at a time against array. 
        
    .PARAMETER Computers
    Can be a single computer, or a group of computers passed as an array
    
    .EXAMPLE
    run below to query just the computer you are on.
    Get-UserSession

    run below to target a single remote computer:
    Get-UserSession -Computers ComputerNameOrIpHere

    run below to target multiple computers:
    Get-UserSession -Computers 'Computer1', 'Computer2', 'IpAddress1'
    Get-UserSession -Computers $ComputersArrayVariable
    
    .NOTES
    @Author: cbtboss
    @Initial Date: 1/15/2021
    @blog: TBD If I will Update this with that yet
    #>
    param (
        # Single remote computer or an array of computers to be checked
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [string[]]
        $Computers
    )
    begin { 
        $report = @() 
        #if nothing passed to computers parameter, default to the local machine being run from
        if(!($computers)){
            $Computers = $env:COMPUTERNAME
        }
    }
    process {
        $index = 0
        foreach ($computer in $Computers) {
            $index ++
            Write-Progress -Activity 'Deploying jobs to query servers' -Status "on $computer which is $index of $($computers.count)" -PercentComplete (($index/$Computers.Count)*100)
            while ((Get-Job -State Running | Where-Object Name -In $Computers).count -gt 8) {
            }
            Start-Job -Name $computer -ScriptBlock {
                if (Test-Connection $using:computer -Count 1 -Quiet) {
                    $JobReturn = query user /server:$using:computer
                }
                else {
                    $JobReturn = $null
                }
                return $JobReturn
            } | out-null
        }
        while ((Get-Job -State Running | Where-Object Name -In $Computers).count -gt 0) {
            Write-Progress -Status 'Waiting on running jobs' -Activity "There are currently $((get-job -state running).count) jobs running"
        }
        $allJobs = Get-Job | Where-Object Name -In $Computers
        foreach ($job in $allJobs) {
            $sessions = Receive-Job $job
            Remove-Job $job
            if ($sessions) {
                for ($i = 1; $i -le ($sessions.count - 1); $i++) {
                    $temp = "" | Select-Object Server, Username, SessionName, ID, State, IdleTime, LogonTime
                    $temp.Server = $job.Name
                    $temp.Username = $sessions[$i].Substring(1, 22).Trim()
                    $temp.SessionName = $sessions[$i].Substring(23, 15).Trim()
                    $temp.ID = [int]($sessions[$i].Substring(39, 9).Trim())
                    $temp.State = $sessions[$i].Substring(46, 8).Trim()
                    $temp.IdleTime = $sessions[$i].Substring(54, 11).Trim()
                    $temp.LogonTime = [datetime]::Parse($sessions[$i].Substring(65).Trim())
                    $report += $temp
                }
            }
        }
    }
    end {
        $report
    }
}
