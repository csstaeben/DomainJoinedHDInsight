$LogFilePath = "$PSScriptRoot\..\HDInsightSecureHadoopEnvironmentSetupTool.log"

$TestResultFilePath = "$PSScriptRoot\..\HDInsightTestResults.log"

Write-Output  "============Log Started============" | Out-File -FilePath $LogFilePath 

function LogError {
    param
    (        
        [String] $message
    )
    Write-Error $message 

    PrvWriteLog "Error" $message
}

function LogInfo {
    param
    (
        [String] $message
    )
   
    Write-Host "$(GetTimeStamp)`t$message"
    

    PrvWriteLog "Info" $message
}

function LogVerbose {
    param
    (
        [String] $message
    )
    Write-Verbose "$(GetTimeStamp)`t$message"

    PrvWriteLog "Verbose" $message
}

function LogWarning {
    param
    (
        [string] $message
    )

    Write-Warning "$(GetTimeStamp)`t$message"

    PrvWriteLog "Warning" $message
}

function LogTestResult {
    param
    (
        [String] $testName,
        [bool] $result

    )
    
    if ($result) {
        $message = "Test " + $testName + " Passed"
    }
    else {
        $message = "Test " + $testName + " Failed"
    }

    Write-Host $message
    
    PrvWriteLog "TestResult" $message

    PrvWriteLog "TestResult" $message $TestResultFilePath
}

function LogTestSuiteResult {
    param
    (
        [String] $testSuiteName,
        [int] $FailedTestCount,
        [int] $PassTestCount,
        [int] $SkipTestCount,
        [int] $TotalTestCount

    )    
    
    $message = "$testSuiteName:: $PassTestCount (Passed) $FailedTestCount (Failed) $SkipTestCount (Skipped) in $TotalTestCount Test(s)"

    Write-Host $message
    
    PrvWriteLog "TestSuiteResult" $message

    PrvWriteLog "TestSuiteResult" $message $TestResultFilePath
}


function PrvWriteLog {
    param (
        [string] $level,
        [string] $message,
        [string] $logFilePath = $LogFilePath
    )
    
    $callstack = (Get-PSCallStack)[2]
    $location = $callstack.Location
    $function = $callstack.FunctionName
    $log = "$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')`t$function`t$level`t$location`t$message"
    Write-Output  $log | Out-File -FilePath $logFilePath -Append
}

function GetTimeStamp {
    return (Get-Date -Format 'yyyy-MM-dd hh:mm:ss')
}