param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$voice = [System.Speech.Synthesis.SpeechSynthesizer]::new()
try {
    foreach ($line in (Get-Content -LiteralPath $Request -Encoding UTF8 -Raw | ConvertFrom-Json)) {
        $voice.SetOutputToNull()
        $voice.SelectVoice($line.voice)
        $voice.Rate = 0
        $voice.SetOutputToWaveFile($line.file)
        $voice.Speak($line.text)
    }
} finally {
    $voice.Dispose()
}
