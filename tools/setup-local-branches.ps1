# Run in the actual checkout after the captain's initial commit.
# Creates local branches only. No commits, switching, pushes or remote changes.
[CmdletBinding()]
param([string]$BaseBranch = 'main')
$ErrorActionPreference = 'Stop'

$taskRepoRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Run this in the actual GamejamCyberhand Git checkout.' }
$taskRemote = & git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or $taskRemote -notmatch 'github\.com[:/]shertwg/GamejamCyberhand(?:\.git)?/?$') {
    throw 'Origin does not match shertwg/GamejamCyberhand. No branches created.'
}
& git check-ref-format --branch $BaseBranch > $null
if ($LASTEXITCODE -ne 0) { throw 'Invalid base branch.' }
$taskBaseCommit = & git rev-parse --verify "refs/heads/${BaseBranch}^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Base branch has no commit. Captain must create or fetch it first.' }

$taskBranches = @('feat/avgust-core', 'feat/anton-ui', 'feat/dima-gameplay', 'content/arina', 'qa/alisa')
foreach ($taskBranch in $taskBranches) {
    & git show-ref --verify --quiet "refs/heads/$taskBranch"
    if ($LASTEXITCODE -eq 0) {
        Write-Output "Already exists: $taskBranch"
        continue
    }
    if ($LASTEXITCODE -ne 1) { throw "Cannot inspect branch $taskBranch" }
    & git branch $taskBranch $taskBaseCommit
    if ($LASTEXITCODE -ne 0) { throw "Cannot create branch $taskBranch" }
    Write-Output "Created locally: $taskBranch"
}
Write-Output 'Done. No commits or pushes made; working branch unchanged.'
