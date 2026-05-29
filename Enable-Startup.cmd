param(
    [switch]$SelfTest,
    [switch]$BuildTest,
    [datetime]$Date = (Get-Date)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($SelfTest -or $BuildTest) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}

$script:AppDir = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
$script:ConfigPath = Join-Path $script:AppDir 'DesktopCalendarFloat.config.json'
$script:TargetDate = Get-Date -Year 2027 -Month 6 -Day 1 -Hour 0 -Minute 0 -Second 0
$script:CountdownTitle = '毕业倒计时'
$script:ThemeKey = 'porcelain'

function Load-AppConfig {
    if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
        return
    }

    try {
        $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
        if ($null -ne $config.targetDate) {
            $parsedDate = [datetime]::MinValue
            if ([datetime]::TryParse([string]$config.targetDate, [ref]$parsedDate)) {
                $script:TargetDate = $parsedDate
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$config.countdownTitle)) {
            $script:CountdownTitle = [string]$config.countdownTitle
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$config.themeKey)) {
            $script:ThemeKey = [string]$config.themeKey
        }
    }
    catch {
        $script:TargetDate = Get-Date -Year 2027 -Month 6 -Day 1 -Hour 0 -Minute 0 -Second 0
        $script:CountdownTitle = '毕业倒计时'
        $script:ThemeKey = 'porcelain'
    }
}

function Save-AppConfig {
    $config = [pscustomobject]@{
        targetDate = $script:TargetDate.ToString('yyyy-MM-dd HH:mm:ss')
        countdownTitle = $script:CountdownTitle
        themeKey = $script:ThemeKey
    }

    $json = $config | ConvertTo-Json -Depth 3
    $encoding = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($script:ConfigPath, $json, $encoding)
}

Load-AppConfig

$script:Holidays = @(
    [pscustomobject]@{ Name = '元旦'; Start = [datetime]'2026-01-01'; End = [datetime]'2026-01-03' },
    [pscustomobject]@{ Name = '春节'; Start = [datetime]'2026-02-15'; End = [datetime]'2026-02-23' },
    [pscustomobject]@{ Name = '清明节'; Start = [datetime]'2026-04-04'; End = [datetime]'2026-04-06' },
    [pscustomobject]@{ Name = '劳动节'; Start = [datetime]'2026-05-01'; End = [datetime]'2026-05-05' },
    [pscustomobject]@{ Name = '端午节'; Start = [datetime]'2026-06-19'; End = [datetime]'2026-06-21' },
    [pscustomobject]@{ Name = '中秋节'; Start = [datetime]'2026-09-25'; End = [datetime]'2026-09-27' },
    [pscustomobject]@{ Name = '国庆节'; Start = [datetime]'2026-10-01'; End = [datetime]'2026-10-07' }
)

function Get-HolidayForDate {
    param([datetime]$Value)

    $dateOnly = $Value.Date
    foreach ($holiday in $script:Holidays) {
        if ($dateOnly -ge $holiday.Start.Date -and $dateOnly -le $holiday.End.Date) {
            return $holiday
        }
    }

    $null
}

function Get-HolidayNotice {
    param([datetime]$Value)

    $dateOnly = $Value.Date
    $activeHoliday = Get-HolidayForDate -Value $dateOnly

    if ($null -ne $activeHoliday) {
        $currentDay = [int]($dateOnly - $activeHoliday.Start.Date).TotalDays + 1
        $totalDays = [int]($activeHoliday.End.Date - $activeHoliday.Start.Date).TotalDays + 1
        return '{0} 第 {1}/{2} 天' -f $activeHoliday.Name, $currentDay, $totalDays
    }

    foreach ($holiday in ($script:Holidays | Sort-Object Start)) {
        if ($holiday.Start.Date -gt $dateOnly) {
            $daysLeft = [int]($holiday.Start.Date - $dateOnly).TotalDays
            if ($daysLeft -le 3) {
                return '{0}还有 {1} 天' -f $holiday.Name, $daysLeft
            }
            break
        }
    }

    $null
}

function Get-ChineseWeekday {
    param([datetime]$Value)

    switch ($Value.DayOfWeek) {
        'Monday' { '星期一' }
        'Tuesday' { '星期二' }
        'Wednesday' { '星期三' }
        'Thursday' { '星期四' }
        'Friday' { '星期五' }
        'Saturday' { '星期六' }
        'Sunday' { '星期日' }
    }
}

function Get-CountdownParts {
    param([datetime]$Now)

    $remaining = $script:TargetDate - $Now
    if ($remaining.TotalMilliseconds -le 0) {
        return [pscustomobject]@{
            IsDone = $true
            RemainingDaysNumber = 0
            Days = '0天'
            HourMinute = ''
            Seconds = '00'
            Milliseconds = '.000'
        }
    }

    [pscustomobject]@{
        IsDone = $false
        RemainingDaysNumber = [math]::Floor($remaining.TotalDays)
        Days = '{0}天' -f [math]::Floor($remaining.TotalDays)
        HourMinute = '{0:00}:{1:00}:' -f $remaining.Hours, $remaining.Minutes
        Seconds = '{0:00}' -f $remaining.Seconds
        Milliseconds = '.{0:000}' -f $remaining.Milliseconds
    }
}

function Get-AppSummary {
    param([datetime]$Value)

    [pscustomobject]@{
        YearText = $Value.ToString('yyyy')
        MonthNumber = $Value.Month.ToString()
        TodayDay = $Value.Day.ToString()
        WeekdayPrefix = '星期'
        WeekdayNumber = (Get-ChineseWeekday -Value $Value).Replace('星期', '')
        HolidayText = Get-HolidayNotice -Value $Value
        CountdownTitle = $script:CountdownTitle
        Countdown = Get-CountdownParts -Now $Value
    }
}

if ($SelfTest) {
    $summary = Get-AppSummary -Value $Date
    $holiday = if ([string]::IsNullOrWhiteSpace($summary.HolidayText)) { '隐藏' } else { $summary.HolidayText }
    Write-Output ("今天：{0}月 {1}日 星期{2}" -f @($summary.MonthNumber, $summary.TodayDay, $summary.WeekdayNumber))
    Write-Output ("节假日：{0}" -f $holiday)
    Write-Output ("{0}：{1} {2}{3}{4}" -f $summary.CountdownTitle, $summary.Countdown.Days, $summary.Countdown.HourMinute, $summary.Countdown.Seconds, $summary.Countdown.Milliseconds)
    exit 0
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-STA',
        '-File',
        "`"$PSCommandPath`""
    )
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function New-Brush {
    param([string]$Hex)

    New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex))
}

function New-GradientBrush {
    param(
        [string]$StartHex,
        [string]$EndHex
    )

    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
    $brush.EndPoint = New-Object System.Windows.Point -ArgumentList 1, 1
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($StartHex)), 0))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString($EndHex)), 1))
    $brush
}

function New-Thickness {
    param(
        [double]$Left,
        [double]$Top,
        [double]$Right,
        [double]$Bottom
    )

    New-Object System.Windows.Thickness -ArgumentList $Left, $Top, $Right, $Bottom
}

function New-TextBlock {
    param(
        [string]$Text,
        [double]$FontSize,
        [string]$Color = '#111827',
        [System.Windows.FontWeight]$Weight = [System.Windows.FontWeights]::Normal
    )

    $textBlock = New-Object System.Windows.Controls.TextBlock
    $textBlock.Text = $Text
    $textBlock.FontFamily = 'Microsoft YaHei UI'
    $textBlock.FontSize = $FontSize
    $textBlock.FontWeight = $Weight
    $textBlock.Foreground = New-Brush -Hex $Color
    $textBlock.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $textBlock
}

function Set-DateInlineText {
    param(
        [System.Windows.Controls.TextBlock]$TextBlock,
        [string]$Primary,
        [string]$Suffix,
        [double]$PrimarySize,
        [double]$SuffixSize,
        [string]$PrimaryColor,
        [string]$SuffixColor
    )

    $TextBlock.Inlines.Clear()

    $primaryRun = New-Object System.Windows.Documents.Run
    $primaryRun.Text = $Primary
    $primaryRun.FontSize = $PrimarySize
    $primaryRun.FontWeight = [System.Windows.FontWeights]::Bold
    $primaryRun.Foreground = New-Brush -Hex $PrimaryColor

    $suffixRun = New-Object System.Windows.Documents.Run
    $suffixRun.Text = $Suffix
    $suffixRun.FontSize = $SuffixSize
    $suffixRun.FontWeight = [System.Windows.FontWeights]::SemiBold
    $suffixRun.Foreground = New-Brush -Hex $SuffixColor

    [void]$TextBlock.Inlines.Add($primaryRun)
    [void]$TextBlock.Inlines.Add($suffixRun)
}

function New-MiniButton {
    param([string]$Text)

    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Text
    $button.Width = 14
    $button.Height = 14
    $button.FontFamily = 'Microsoft YaHei UI'
    $button.FontSize = 9
    $button.Foreground = New-Brush -Hex '#6B7280'
    $button.Background = [System.Windows.Media.Brushes]::Transparent
    $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
    $button.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
    $button.Padding = New-Object System.Windows.Thickness -ArgumentList 0
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    $button
}

function Set-CanvasBounds {
    param(
        [System.Windows.UIElement]$Element,
        [double]$Left,
        [double]$Top,
        [double]$Width,
        [double]$Height
    )

    [System.Windows.Controls.Canvas]::SetLeft($Element, $Left)
    [System.Windows.Controls.Canvas]::SetTop($Element, $Top)
    if ($Element -is [System.Windows.FrameworkElement]) {
        $Element.Width = $Width
        $Element.Height = $Height
    }
}

function Test-IsInteractiveSource {
    param([object]$Source)

    $current = $Source
    while ($null -ne $current) {
        if ($current -is [System.Windows.Controls.Button] -or $current -is [System.Windows.Controls.MenuItem]) {
            return $true
        }

        try {
            $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
        }
        catch {
            return $false
        }
    }

    $false
}

function Clamp-Number {
    param(
        [double]$Value,
        [double]$Minimum,
        [double]$Maximum
    )

    [math]::Min([math]::Max($Value, $Minimum), $Maximum)
}

function Set-WeatherLayer {
    param([string]$Mode)

    $script:WeatherMode = $Mode
    if ($null -eq $weatherCanvas) {
        return
    }

    $weatherCanvas.Children.Clear()
    if ([string]::IsNullOrWhiteSpace($Mode)) {
        $weatherCanvas.Visibility = [System.Windows.Visibility]::Collapsed
        return
    }

    $weatherCanvas.Visibility = [System.Windows.Visibility]::Visible

    switch ($Mode) {
        'sunny' {
            $sun = New-Object System.Windows.Shapes.Ellipse
            $sun.Width = 14
            $sun.Height = 14
            $sun.Fill = New-Brush -Hex '#F59E0B'
            $sun.Opacity = 0.62
            [System.Windows.Controls.Canvas]::SetLeft($sun, 142)
            [System.Windows.Controls.Canvas]::SetTop($sun, 8)
            [void]$weatherCanvas.Children.Add($sun)

            for ($i = 0; $i -lt 7; $i++) {
                $ray = New-Object System.Windows.Shapes.Line
                $ray.X1 = 110 + ($i * 8)
                $ray.Y1 = -2
                $ray.X2 = 136 + ($i * 8)
                $ray.Y2 = 33
                $ray.Stroke = New-Brush -Hex '#FBBF24'
                $ray.StrokeThickness = 1.2
                $ray.Opacity = 0.22
                [void]$weatherCanvas.Children.Add($ray)
            }
        }
        'rain' {
            for ($i = 0; $i -lt 13; $i++) {
                $drop = New-Object System.Windows.Shapes.Line
                $drop.X1 = 12 + (($i * 17) % 168)
                $drop.Y1 = (($i * 11) % 88) - 18
                $drop.X2 = $drop.X1 - 4
                $drop.Y2 = $drop.Y1 + 13
                $drop.Stroke = New-Brush -Hex '#38BDF8'
                $drop.StrokeThickness = 1
                $drop.Opacity = 0.32
                [void]$weatherCanvas.Children.Add($drop)
            }
        }
        'snow' {
            for ($i = 0; $i -lt 18; $i++) {
                $flake = New-Object System.Windows.Shapes.Ellipse
                $flake.Width = 2.2 + (($i % 3) * 0.7)
                $flake.Height = $flake.Width
                $flake.Fill = New-Brush -Hex '#FFFFFF'
                $flake.Opacity = 0.72
                [System.Windows.Controls.Canvas]::SetLeft($flake, 8 + (($i * 23) % 174))
                [System.Windows.Controls.Canvas]::SetTop($flake, (($i * 13) % 92) - 10)
                [void]$weatherCanvas.Children.Add($flake)
            }
        }
        'cloudy' {
            foreach ($spec in @(@(124, 18, 28, 11), @(144, 14, 34, 13), @(158, 22, 24, 10))) {
                $cloud = New-Object System.Windows.Shapes.Ellipse
                $cloud.Width = $spec[2]
                $cloud.Height = $spec[3]
                $cloud.Fill = New-Brush -Hex '#FFFFFF'
                $cloud.Opacity = 0.34
                [System.Windows.Controls.Canvas]::SetLeft($cloud, $spec[0])
                [System.Windows.Controls.Canvas]::SetTop($cloud, $spec[1])
                [void]$weatherCanvas.Children.Add($cloud)
            }
        }
        'sunset' {
            for ($i = 0; $i -lt 5; $i++) {
                $line = New-Object System.Windows.Shapes.Line
                $line.X1 = 110
                $line.Y1 = 18 + ($i * 7)
                $line.X2 = 184
                $line.Y2 = 10 + ($i * 9)
                $line.Stroke = New-Brush -Hex '#FB7185'
                $line.StrokeThickness = 1.4
                $line.Opacity = 0.22
                [void]$weatherCanvas.Children.Add($line)
            }
        }
        'nightSky' {
            for ($i = 0; $i -lt 15; $i++) {
                $star = New-Object System.Windows.Shapes.Ellipse
                $star.Width = 1.5 + (($i % 2) * 0.8)
                $star.Height = $star.Width
                $star.Fill = New-Brush -Hex '#FFFFFF'
                $star.Opacity = 0.62
                [System.Windows.Controls.Canvas]::SetLeft($star, 12 + (($i * 19) % 168))
                [System.Windows.Controls.Canvas]::SetTop($star, 8 + (($i * 17) % 52))
                [void]$weatherCanvas.Children.Add($star)
            }
        }
    }
}

function Update-WeatherAnimation {
    if ([string]::IsNullOrWhiteSpace($script:WeatherMode) -or $null -eq $weatherCanvas) {
        return
    }

    $t = (Get-Date).TimeOfDay.TotalSeconds
    $index = 0
    foreach ($child in $weatherCanvas.Children) {
        switch ($script:WeatherMode) {
            'sunny' {
                $child.Opacity = 0.18 + (0.18 * (1 + [math]::Sin($t * 1.7 + $index)) / 2)
                if ($child -is [System.Windows.Shapes.Ellipse]) {
                    $child.Opacity = 0.52 + (0.18 * (1 + [math]::Sin($t * 1.2)) / 2)
                }
            }
            'rain' {
                $top = [System.Windows.Controls.Canvas]::GetTop($child) + 1.6
                if ($top -gt 98) { $top = -18 }
                [System.Windows.Controls.Canvas]::SetTop($child, $top)
            }
            'snow' {
                $top = [System.Windows.Controls.Canvas]::GetTop($child) + (0.25 + (($index % 4) * 0.08))
                if ($top -gt 98) { $top = -8 }
                $left = [System.Windows.Controls.Canvas]::GetLeft($child) + ([math]::Sin($t + $index) * 0.08)
                [System.Windows.Controls.Canvas]::SetLeft($child, $left)
                [System.Windows.Controls.Canvas]::SetTop($child, $top)
            }
            'cloudy' {
                $left = [System.Windows.Controls.Canvas]::GetLeft($child) + 0.08
                if ($left -gt 190) { $left = 112 }
                [System.Windows.Controls.Canvas]::SetLeft($child, $left)
            }
            'sunset' {
                $child.Opacity = 0.16 + (0.12 * (1 + [math]::Sin($t + $index)) / 2)
            }
            'nightSky' {
                $child.Opacity = 0.34 + (0.46 * (1 + [math]::Sin(($t * 2.1) + $index)) / 2)
            }
        }
        $index++
    }
}

function Set-CardTheme {
    param(
        [string]$Key,
        [switch]$Persist
    )

    $weatherThemeKeys = @('sunny', 'rain', 'snow', 'cloudy', 'sunset', 'nightSky')

    switch ($Key) {
        'porcelain' { $card.Background = New-Brush -Hex '#F9FAFB'; $card.BorderBrush = New-Brush -Hex '#E5E7EB' }
        'sage' { $card.Background = New-Brush -Hex '#ECFDF5'; $card.BorderBrush = New-Brush -Hex '#A7F3D0' }
        'mist' { $card.Background = New-Brush -Hex '#EFF6FF'; $card.BorderBrush = New-Brush -Hex '#BFDBFE' }
        'apricot' { $card.Background = New-Brush -Hex '#FFF7ED'; $card.BorderBrush = New-Brush -Hex '#FED7AA' }
        'lavender' { $card.Background = New-Brush -Hex '#F5F3FF'; $card.BorderBrush = New-Brush -Hex '#DDD6FE' }
        'rose' { $card.Background = New-Brush -Hex '#FFF1F2'; $card.BorderBrush = New-Brush -Hex '#FECDD3' }
        'butter' { $card.Background = New-Brush -Hex '#FEFCE8'; $card.BorderBrush = New-Brush -Hex '#FEF08A' }
        'stone' { $card.Background = New-Brush -Hex '#F5F5F4'; $card.BorderBrush = New-Brush -Hex '#D6D3D1' }
        'sky' { $card.Background = New-Brush -Hex '#F0F9FF'; $card.BorderBrush = New-Brush -Hex '#BAE6FD' }
        'mint' { $card.Background = New-Brush -Hex '#F0FDFA'; $card.BorderBrush = New-Brush -Hex '#99F6E4' }
        'sand' { $card.Background = New-Brush -Hex '#FFFBEB'; $card.BorderBrush = New-Brush -Hex '#FDE68A' }
        'pearl' { $card.Background = New-Brush -Hex '#FAFAFA'; $card.BorderBrush = New-Brush -Hex '#D4D4D8' }
        'powder' { $card.Background = New-Brush -Hex '#FDF4FF'; $card.BorderBrush = New-Brush -Hex '#F5D0FE' }
        'tea' { $card.Background = New-Brush -Hex '#F7FEE7'; $card.BorderBrush = New-Brush -Hex '#D9F99D' }
        'oat' { $card.Background = New-Brush -Hex '#FAF7F2'; $card.BorderBrush = New-Brush -Hex '#E7D8C9' }
        'ice' { $card.Background = New-Brush -Hex '#F8FAFC'; $card.BorderBrush = New-Brush -Hex '#E2E8F0' }
        'morning' { $card.Background = New-GradientBrush -StartHex '#FDF2F8' -EndHex '#ECFEFF'; $card.BorderBrush = New-Brush -Hex '#FBCFE8' }
        'seaSalt' { $card.Background = New-GradientBrush -StartHex '#E0F2FE' -EndHex '#F0FDFA'; $card.BorderBrush = New-Brush -Hex '#BAE6FD' }
        'twilight' { $card.Background = New-GradientBrush -StartHex '#FAE8FF' -EndHex '#E0E7FF'; $card.BorderBrush = New-Brush -Hex '#DDD6FE' }
        'peachMist' { $card.Background = New-GradientBrush -StartHex '#FFE4E6' -EndHex '#FEF3C7'; $card.BorderBrush = New-Brush -Hex '#FDBA74' }
        'mintCloud' { $card.Background = New-GradientBrush -StartHex '#DCFCE7' -EndHex '#E0F2FE'; $card.BorderBrush = New-Brush -Hex '#86EFAC' }
        'lilacFog' { $card.Background = New-GradientBrush -StartHex '#F5D0FE' -EndHex '#F8FAFC'; $card.BorderBrush = New-Brush -Hex '#E9D5FF' }
        'blueHour' { $card.Background = New-GradientBrush -StartHex '#DBEAFE' -EndHex '#F5F3FF'; $card.BorderBrush = New-Brush -Hex '#C4B5FD' }
        'spring' { $card.Background = New-GradientBrush -StartHex '#DCFCE7' -EndHex '#FEF9C3'; $card.BorderBrush = New-Brush -Hex '#BEF264' }
        'coralSea' { $card.Background = New-GradientBrush -StartHex '#FFE4E6' -EndHex '#CCFBF1'; $card.BorderBrush = New-Brush -Hex '#FDA4AF' }
        'softDawn' { $card.Background = New-GradientBrush -StartHex '#FFEDD5' -EndHex '#E0E7FF'; $card.BorderBrush = New-Brush -Hex '#FDBA74' }
        'aurora' { $card.Background = New-GradientBrush -StartHex '#D9F99D' -EndHex '#C4B5FD'; $card.BorderBrush = New-Brush -Hex '#A7F3D0' }
        'linenSky' { $card.Background = New-GradientBrush -StartHex '#FAF7F2' -EndHex '#E0F2FE'; $card.BorderBrush = New-Brush -Hex '#E7D8C9' }
        'sunny' { $card.Background = New-GradientBrush -StartHex '#FEF3C7' -EndHex '#DBEAFE'; $card.BorderBrush = New-Brush -Hex '#FDE68A' }
        'rain' { $card.Background = New-GradientBrush -StartHex '#E0F2FE' -EndHex '#E5E7EB'; $card.BorderBrush = New-Brush -Hex '#CBD5E1' }
        'snow' { $card.Background = New-GradientBrush -StartHex '#FFFFFF' -EndHex '#E0F2FE'; $card.BorderBrush = New-Brush -Hex '#BAE6FD' }
        'cloudy' { $card.Background = New-GradientBrush -StartHex '#F8FAFC' -EndHex '#CBD5E1'; $card.BorderBrush = New-Brush -Hex '#CBD5E1' }
        'sunset' { $card.Background = New-GradientBrush -StartHex '#FED7AA' -EndHex '#FBCFE8'; $card.BorderBrush = New-Brush -Hex '#FDBA74' }
        'nightSky' { $card.Background = New-GradientBrush -StartHex '#E0E7FF' -EndHex '#C7D2FE'; $card.BorderBrush = New-Brush -Hex '#A5B4FC' }
        default { $card.Background = New-Brush -Hex '#F9FAFB'; $card.BorderBrush = New-Brush -Hex '#E5E7EB'; $Key = 'porcelain' }
    }

    $script:ThemeKey = $Key
    if ($weatherThemeKeys -contains $Key) {
        Set-WeatherLayer -Mode $Key
    }
    else {
        Set-WeatherLayer -Mode ''
    }

    if ($Persist) {
        Save-AppConfig
    }
}

function New-ThemeMenuItem {
    param(
        [string]$Header,
        [string]$Key
    )

    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $Header
    $item.Tag = $Key
    $item.Add_Click({
        param($sender, $eventArgs)
        Set-CardTheme -Key ([string]$sender.Tag) -Persist
    })
    $item
}

$script:DesignWidth = 190.0
$script:DesignHeight = 96.0
$script:InitialWindowWidth = 170.0
$script:lastDate = (Get-Date).Date
$script:pressPoint = $null
$script:isDragStarted = $false
$script:tabPressY = $null
$script:tabStartTop = 0.0
$script:tabMoved = $false
$script:WeatherMode = ''
$weatherCanvas = $null

$window = New-Object System.Windows.Window
$window.Title = '桌面日历浮窗'
$window.Width = $script:InitialWindowWidth
$window.Height = $script:InitialWindowWidth * $script:DesignHeight / $script:DesignWidth
$window.MinWidth = $window.Width
$window.MinHeight = $window.Height
$window.MaxWidth = $window.Width
$window.MaxHeight = $window.Height
$window.WindowStyle = [System.Windows.WindowStyle]::None
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.AllowsTransparency = $true
$window.Background = [System.Windows.Media.Brushes]::Transparent
$window.Topmost = $true
$window.ShowInTaskbar = $false
$window.Opacity = 0.98

$workArea = [System.Windows.SystemParameters]::WorkArea
$window.Left = $workArea.Right - $window.Width - 28
$window.Top = $workArea.Top + 96

$shell = New-Object System.Windows.Controls.Grid
$window.Content = $shell

$card = New-Object System.Windows.Controls.Border
$card.Background = New-Brush -Hex '#F9FAFB'
$card.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 14
$card.BorderBrush = New-Brush -Hex '#E5E7EB'
$card.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1

$shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
$shadow.BlurRadius = 16
$shadow.ShadowDepth = 3
$shadow.Opacity = 0.16
$shadow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString('#111827')
$card.Effect = $shadow
[void]$shell.Children.Add($card)

$themeMenu = New-Object System.Windows.Controls.ContextMenu

$solidMenu = New-Object System.Windows.Controls.MenuItem
$solidMenu.Header = '单色'
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '瓷白' -Key 'porcelain'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '鼠尾草绿' -Key 'sage'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '雾蓝' -Key 'mist'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '暖杏' -Key 'apricot'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '薰衣草' -Key 'lavender'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '玫瑰雾' -Key 'rose'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '奶油黄' -Key 'butter'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '暖石灰' -Key 'stone'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '天青' -Key 'sky'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '薄荷' -Key 'mint'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '浅沙' -Key 'sand'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '珍珠灰' -Key 'pearl'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '粉雾' -Key 'powder'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '淡茶' -Key 'tea'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '燕麦' -Key 'oat'))
[void]$solidMenu.Items.Add((New-ThemeMenuItem -Header '冰白' -Key 'ice'))

$blendMenu = New-Object System.Windows.Controls.MenuItem
$blendMenu.Header = '混色'
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '清晨' -Key 'morning'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '海盐' -Key 'seaSalt'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '暮光' -Key 'twilight'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '桃雾' -Key 'peachMist'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '薄荷云' -Key 'mintCloud'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '丁香雾' -Key 'lilacFog'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '蓝调时分' -Key 'blueHour'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '春日' -Key 'spring'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '珊瑚海' -Key 'coralSea'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '柔和黎明' -Key 'softDawn'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '极光' -Key 'aurora'))
[void]$blendMenu.Items.Add((New-ThemeMenuItem -Header '亚麻天空' -Key 'linenSky'))

$weatherMenu = New-Object System.Windows.Controls.MenuItem
$weatherMenu.Header = '天气背景'
[void]$weatherMenu.Items.Add((New-ThemeMenuItem -Header '晴天' -Key 'sunny'))
[void]$weatherMenu.Items.Add((New-ThemeMenuItem -Header '雨天' -Key 'rain'))
[void]$weatherMenu.Items.Add((New-ThemeMenuItem -Header '雪天' -Key 'snow'))
[void]$weatherMenu.Items.Add((New-ThemeMenuItem -Header '多云' -Key 'cloudy'))
[void]$weatherMenu.Items.Add((New-ThemeMenuItem -Header '日落' -Key 'sunset'))
[void]$weatherMenu.Items.Add((New-ThemeMenuItem -Header '夜空' -Key 'nightSky'))

$tabMenuItem = New-Object System.Windows.Controls.MenuItem
$tabMenuItem.Header = '缩小到右侧小浮窗'
$tabMenuItem.Add_Click({ Hide-MainToTab })

$closeDisplayMenuItem = New-Object System.Windows.Controls.MenuItem
$closeDisplayMenuItem.Header = '关闭浮窗显示'
$closeDisplayMenuItem.Add_Click({ Close-WidgetDisplay })

[void]$themeMenu.Items.Add($solidMenu)
[void]$themeMenu.Items.Add($blendMenu)
[void]$themeMenu.Items.Add($weatherMenu)
[void]$themeMenu.Items.Add((New-Object System.Windows.Controls.Separator))
[void]$themeMenu.Items.Add($tabMenuItem)
[void]$themeMenu.Items.Add($closeDisplayMenuItem)
$shell.ContextMenu = $themeMenu

$shell.Add_ContextMenuOpening({
    $_.Handled = $true
})

$shell.Add_MouseRightButtonUp({
    $workAreaNow = [System.Windows.SystemParameters]::WorkArea
    $rightSpace = $workAreaNow.Right - ($window.Left + $window.Width)
    if ($rightSpace -ge 170) {
        $themeMenu.PlacementTarget = $shell
        $themeMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Right
        $themeMenu.HorizontalOffset = 4
    }
    else {
        $themeMenu.PlacementTarget = $shell
        $themeMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Left
        $themeMenu.HorizontalOffset = -4
    }

    $themeMenu.VerticalOffset = 0
    $themeMenu.IsOpen = $true
    $_.Handled = $true
})

$viewbox = New-Object System.Windows.Controls.Viewbox
$viewbox.Stretch = [System.Windows.Media.Stretch]::Uniform
$viewbox.Margin = New-Object System.Windows.Thickness -ArgumentList 0
[void]$shell.Children.Add($viewbox)

$canvas = New-Object System.Windows.Controls.Canvas
$canvas.Width = $script:DesignWidth
$canvas.Height = $script:DesignHeight
$viewbox.Child = $canvas

$weatherCanvas = New-Object System.Windows.Controls.Canvas
$weatherCanvas.Width = $script:DesignWidth
$weatherCanvas.Height = $script:DesignHeight
$weatherCanvas.Visibility = [System.Windows.Visibility]::Collapsed
$weatherCanvas.IsHitTestVisible = $false
Set-CanvasBounds -Element $weatherCanvas -Left 0 -Top 0 -Width $script:DesignWidth -Height $script:DesignHeight
[void]$canvas.Children.Add($weatherCanvas)
Set-CardTheme -Key $script:ThemeKey

$dateArea = New-Object System.Windows.Controls.Border
$dateArea.Background = [System.Windows.Media.Brushes]::Transparent
$dateArea.Cursor = [System.Windows.Input.Cursors]::Hand
Set-CanvasBounds -Element $dateArea -Left 8 -Top 6 -Width 46 -Height 68

$dateStack = New-Object System.Windows.Controls.StackPanel
$dateStack.Orientation = [System.Windows.Controls.Orientation]::Vertical
$dateStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

$monthText = New-TextBlock -Text '' -FontSize 10 -Color '#6B7280' -Weight ([System.Windows.FontWeights]::SemiBold)
$monthText.TextAlignment = [System.Windows.TextAlignment]::Center
$monthText.Height = 18

$dateDayText = New-TextBlock -Text '' -FontSize 22 -Color '#111827' -Weight ([System.Windows.FontWeights]::Bold)
$dateDayText.TextAlignment = [System.Windows.TextAlignment]::Center
$dateDayText.Height = 30

$weekdayText = New-TextBlock -Text '' -FontSize 9 -Color '#9CA3AF' -Weight ([System.Windows.FontWeights]::SemiBold)
$weekdayText.TextAlignment = [System.Windows.TextAlignment]::Center
$weekdayText.Height = 18

[void]$dateStack.Children.Add($monthText)
[void]$dateStack.Children.Add($dateDayText)
[void]$dateStack.Children.Add($weekdayText)
$dateArea.Child = $dateStack
[void]$canvas.Children.Add($dateArea)

$yearBadge = New-Object System.Windows.Controls.Border
$yearBadge.Background = New-Brush -Hex '#111827'
$yearBadge.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 7
$yearBadge.Padding = New-Object System.Windows.Thickness -ArgumentList 6, 0, 6, 0
$yearBadge.Visibility = [System.Windows.Visibility]::Collapsed
$yearBadge.IsHitTestVisible = $false
Set-CanvasBounds -Element $yearBadge -Left 8 -Top 0 -Width 46 -Height 16

$yearText = New-TextBlock -Text '' -FontSize 9 -Color '#FFFFFF' -Weight ([System.Windows.FontWeights]::SemiBold)
$yearText.TextAlignment = [System.Windows.TextAlignment]::Center
$yearText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$yearBadge.Child = $yearText
[void]$canvas.Children.Add($yearBadge)

$countdownLabel = New-TextBlock -Text $script:CountdownTitle -FontSize 9 -Color '#6B7280' -Weight ([System.Windows.FontWeights]::SemiBold)
Set-CanvasBounds -Element $countdownLabel -Left 58 -Top 10 -Width 72 -Height 14
[void]$canvas.Children.Add($countdownLabel)

$daysText = New-TextBlock -Text '' -FontSize 12 -Color '#6B7280' -Weight ([System.Windows.FontWeights]::SemiBold)
Set-CanvasBounds -Element $daysText -Left 58 -Top 26 -Width 55 -Height 18
[void]$canvas.Children.Add($daysText)

$hourMinuteText = New-TextBlock -Text '' -FontSize 15 -Color '#111827' -Weight ([System.Windows.FontWeights]::SemiBold)
Set-CanvasBounds -Element $hourMinuteText -Left 58 -Top 48 -Width 54 -Height 22
[void]$canvas.Children.Add($hourMinuteText)

$secondsText = New-TextBlock -Text '' -FontSize 32 -Color '#111827' -Weight ([System.Windows.FontWeights]::Bold)
Set-CanvasBounds -Element $secondsText -Left 110 -Top 34 -Width 42 -Height 44
[void]$canvas.Children.Add($secondsText)

$millisecondsText = New-TextBlock -Text '' -FontSize 15 -Color '#2563EB' -Weight ([System.Windows.FontWeights]::Bold)
Set-CanvasBounds -Element $millisecondsText -Left 148 -Top 53 -Width 38 -Height 22
[void]$canvas.Children.Add($millisecondsText)

$holidayBlock = New-Object System.Windows.Controls.Border
$holidayBlock.Background = New-Brush -Hex '#FFF7ED'
$holidayBlock.BorderBrush = New-Brush -Hex '#FED7AA'
$holidayBlock.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
$holidayBlock.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 8
$holidayBlock.Padding = New-Object System.Windows.Thickness -ArgumentList 8, 0, 8, 0
Set-CanvasBounds -Element $holidayBlock -Left 10 -Top 75 -Width 166 -Height 17

$holidayText = New-TextBlock -Text '' -FontSize 10 -Color '#C2410C' -Weight ([System.Windows.FontWeights]::SemiBold)
$holidayText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$holidayBlock.Child = $holidayText
[void]$canvas.Children.Add($holidayBlock)

$minimizeButton = New-MiniButton -Text '-'
$minimizeButton.ToolTip = '收起到右侧'
Set-CanvasBounds -Element $minimizeButton -Left 170 -Top 7 -Width 14 -Height 14
[void]$canvas.Children.Add($minimizeButton)

$tabWindow = New-Object System.Windows.Window
$tabWindow.Title = '桌面日历浮窗入口'
$tabWindow.Width = 34
$tabWindow.Height = 32
$tabWindow.WindowStyle = [System.Windows.WindowStyle]::None
$tabWindow.ResizeMode = [System.Windows.ResizeMode]::NoResize
$tabWindow.AllowsTransparency = $true
$tabWindow.Background = [System.Windows.Media.Brushes]::Transparent
$tabWindow.Topmost = $true
$tabWindow.ShowInTaskbar = $false
$tabWindow.Left = $workArea.Right - $tabWindow.Width
$tabWindow.Top = $window.Top + 8

$tabBorder = New-Object System.Windows.Controls.Border
$tabBorder.Width = 34
$tabBorder.Height = 32
$tabBorder.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 16, 0, 0, 16
$tabBorder.Background = New-Brush -Hex '#111827'
$tabBorder.Opacity = 0.72
$tabBorder.Cursor = [System.Windows.Input.Cursors]::SizeNS

$tabText = New-TextBlock -Text '' -FontSize 11 -Color '#FFFFFF' -Weight ([System.Windows.FontWeights]::Bold)
$tabText.TextAlignment = [System.Windows.TextAlignment]::Center
$tabText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$tabText.Margin = New-Thickness -Left 2 -Top 0 -Right 0 -Bottom 0
$tabBorder.Child = $tabText
$tabWindow.Content = $tabBorder

function Update-Summary {
    $now = Get-Date
    $summary = Get-AppSummary -Value $now

    Set-DateInlineText -TextBlock $monthText -Primary $summary.MonthNumber -Suffix '月' -PrimarySize 14 -SuffixSize 8 -PrimaryColor '#111827' -SuffixColor '#9CA3AF'
    Set-DateInlineText -TextBlock $dateDayText -Primary $summary.TodayDay -Suffix '日' -PrimarySize 24 -SuffixSize 9 -PrimaryColor '#111827' -SuffixColor '#9CA3AF'

    $weekdayText.Inlines.Clear()
    $weekdayPrefixRun = New-Object System.Windows.Documents.Run
    $weekdayPrefixRun.Text = $summary.WeekdayPrefix
    $weekdayPrefixRun.FontSize = 8
    $weekdayPrefixRun.FontWeight = [System.Windows.FontWeights]::SemiBold
    $weekdayPrefixRun.Foreground = New-Brush -Hex '#9CA3AF'
    $weekdayNumberRun = New-Object System.Windows.Documents.Run
    $weekdayNumberRun.Text = $summary.WeekdayNumber
    $weekdayNumberRun.FontSize = 12
    $weekdayNumberRun.FontWeight = [System.Windows.FontWeights]::Bold
    $weekdayNumberRun.Foreground = New-Brush -Hex '#6B7280'
    [void]$weekdayText.Inlines.Add($weekdayPrefixRun)
    [void]$weekdayText.Inlines.Add($weekdayNumberRun)

    $yearText.Text = $summary.YearText
    $countdownLabel.Text = $summary.CountdownTitle

    if ($summary.Countdown.IsDone) {
        $daysText.Text = '已完成'
        $hourMinuteText.Text = ''
        $secondsText.Text = ''
        $millisecondsText.Text = ''
        $tabText.Text = '0'
    }
    else {
        $daysText.Text = $summary.Countdown.Days
        $hourMinuteText.Text = $summary.Countdown.HourMinute
        $secondsText.Text = $summary.Countdown.Seconds
        $millisecondsText.Text = $summary.Countdown.Milliseconds
        $tabText.Text = $summary.Countdown.RemainingDaysNumber.ToString()
    }

    if ([string]::IsNullOrWhiteSpace($summary.HolidayText)) {
        $holidayBlock.Visibility = [System.Windows.Visibility]::Collapsed
    }
    else {
        $holidayText.Text = $summary.HolidayText
        $holidayBlock.Visibility = [System.Windows.Visibility]::Visible
    }
}

function Position-MainNearTab {
    $workAreaNow = [System.Windows.SystemParameters]::WorkArea
    $window.Left = $workAreaNow.Right - $window.Width - 28
    $targetTop = $tabWindow.Top - (($window.Height - $tabWindow.Height) / 2)
    $window.Top = Clamp-Number -Value $targetTop -Minimum $workAreaNow.Top -Maximum ($workAreaNow.Bottom - $window.Height)
}

function Hide-MainToTab {
    $workAreaNow = [System.Windows.SystemParameters]::WorkArea
    $tabWindow.Left = $workAreaNow.Right - $tabWindow.Width
    $tabWindow.Top = Clamp-Number -Value ($window.Top + (($window.Height - $tabWindow.Height) / 2)) -Minimum $workAreaNow.Top -Maximum ($workAreaNow.Bottom - $tabWindow.Height)
    $window.Hide()
    $tabWindow.Show()
    $tabWindow.Activate()
}

function Restore-MainFromTab {
    Position-MainNearTab
    $window.Show()
    $window.Activate()
    $tabWindow.Hide()
}

function Close-WidgetDisplay {
    $timer.Stop()
    if ($tabWindow.IsVisible) {
        $tabWindow.Hide()
    }
    $window.Close()
}

$minimizeButton.Add_Click({ Hide-MainToTab })

$dateArea.Add_MouseEnter({ $yearBadge.Visibility = [System.Windows.Visibility]::Visible })
$dateArea.Add_MouseLeave({ $yearBadge.Visibility = [System.Windows.Visibility]::Collapsed })

$shell.Add_MouseLeftButtonDown({
    if (Test-IsInteractiveSource -Source $_.OriginalSource) {
        return
    }

    $script:pressPoint = $_.GetPosition($window)
    $script:isDragStarted = $false
    $shell.CaptureMouse()
})

$shell.Add_MouseMove({
    if ($null -eq $script:pressPoint -or $_.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
        return
    }

    $currentPoint = $_.GetPosition($window)
    $distanceX = [math]::Abs($currentPoint.X - $script:pressPoint.X)
    $distanceY = [math]::Abs($currentPoint.Y - $script:pressPoint.Y)
    if ($distanceX -lt 4 -and $distanceY -lt 4) {
        return
    }

    $script:isDragStarted = $true
    $script:pressPoint = $null
    $shell.ReleaseMouseCapture()
    $window.DragMove()
})

$shell.Add_MouseLeftButtonUp({
    $script:pressPoint = $null
    $script:isDragStarted = $false
    $shell.ReleaseMouseCapture()
})

$tabBorder.Add_MouseLeftButtonDown({
    $screenPoint = $tabWindow.PointToScreen($_.GetPosition($tabWindow))
    $script:tabPressY = $screenPoint.Y
    $script:tabStartTop = $tabWindow.Top
    $script:tabMoved = $false
    $tabBorder.CaptureMouse()
})

$tabBorder.Add_MouseMove({
    if ($null -eq $script:tabPressY -or $_.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
        return
    }

    $screenPoint = $tabWindow.PointToScreen($_.GetPosition($tabWindow))
    $deltaY = $screenPoint.Y - $script:tabPressY
    if ([math]::Abs($deltaY) -lt 2) {
        return
    }

    $script:tabMoved = $true
    $workAreaNow = [System.Windows.SystemParameters]::WorkArea
    $tabWindow.Top = Clamp-Number -Value ($script:tabStartTop + $deltaY) -Minimum $workAreaNow.Top -Maximum ($workAreaNow.Bottom - $tabWindow.Height)
    $tabWindow.Left = $workAreaNow.Right - $tabWindow.Width
})

$tabBorder.Add_MouseLeftButtonUp({
    $tabBorder.ReleaseMouseCapture()
    if (-not $script:tabMoved) {
        Restore-MainFromTab
    }

    $script:tabPressY = $null
    $script:tabMoved = $false
})

$window.Add_Closed({
    if ($null -ne $tabWindow -and $tabWindow.IsVisible) {
        $tabWindow.Close()
    }
})

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(40)
$timer.Add_Tick({
    $nowDate = (Get-Date).Date
    if ($nowDate -ne $script:lastDate) {
        $script:lastDate = $nowDate
    }

    Update-WeatherAnimation
    Update-Summary
})
$timer.Start()

Update-Summary

if ($BuildTest) {
    Write-Output 'UI 构建测试通过'
    exit 0
}

$app = New-Object System.Windows.Application
[void]$window.Show()
[void]$app.Run($window)
