Add-Type -AssemblyName System.Speech
$base = Join-Path $PSScriptRoot '..\assets\last_light\audio'
New-Item -ItemType Directory -Force $base | Out-Null
$voice = [System.Speech.Synthesis.SpeechSynthesizer]::new()
$voice.SelectVoice('Microsoft Irina Desktop')
$voice.Rate = -1
$lines = [ordered]@{
    orbit = 'Рейнджер, это Маяк. Последний виток. Готовлю возвращение.'
    fall = 'Разряд в обшивку. Основная тяга пропала. Держись!'
    impact = 'Посадка аварийная. Давление в рубке падает. Перекрой заслонку.'
    air = 'Давление держится. Нам нужна вода, иначе перегреется реактор.'
    water = 'Вода пошла. Подготовь фильтр в шлюзе. Снаружи очень много пыли.'
    threshold = 'Фильтр готов. За люком Керна. Мы идём за рудой, по одному шагу.'
    ravine = 'Я вижу обломки. За ними светится порода. Забери образец.'
    cave = 'Кристаллы проводят заряд. Из них и сплава можно собрать экран для антенны.'
    storm = 'Фронт накрывает хребет. Удержи фазу трижды. Если собьёмся, начнём этот шаг заново.'
    relay = 'Ретранслятор отвечает. Вернись на корабль и свяжись с орбитой.'
    answer = 'Орбита на связи. Маяк, мы видим вас. Коридор для взлёта открыт.'
    home = 'Тяга стабильна. Керна осталась под нами. Теперь домой.'
}
foreach ($key in $lines.Keys) {
    $voice.SetOutputToWaveFile((Join-Path $base "voice_$key.wav"))
    $voice.Speak($lines[$key])
}
$voice.SetOutputToNull()
$voice.SelectVoice('Microsoft Pavel')
$voice.Rate = -2
$ranger = [ordered]@{
    wreck = 'У этих обломков старый номер. Значит, мы не первые, кто упал здесь. Маяк, посмотри, куда вёл их сигнал.'
    seam = 'Кажется, я понял. В пещере они прятали оборудование от грозы. Если уцелел их ретранслятор, у нас есть шанс.'
    epilogue = 'Я думал, мы останемся здесь. А потом ты сказал, что давление держится. Маяк, веди нас домой.'
}
foreach ($key in $ranger.Keys) {
    $voice.SetOutputToWaveFile((Join-Path $base "voice_$key.wav"))
    $voice.Speak($ranger[$key])
}
$voice.Dispose()
