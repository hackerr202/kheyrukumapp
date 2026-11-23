$jobs = Invoke-RestMethod -Uri 'https://api.github.com/repos/hackerr202/kheyrukumapp/actions/runs/45183411951/jobs' -Headers @{'User-Agent'='PowerShell'}
$jobId = $jobs.jobs[0].id
Write-Host "Job ID: $jobId"
$annotations = Invoke-RestMethod -Uri "https://api.github.com/repos/hackerr202/kheyrukumapp/check-runs/$jobId/annotations" -Headers @{'User-Agent'='PowerShell'}
$annotations | Format-List
