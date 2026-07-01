Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- KONFIGURASI ----
$intervalMenit = 15
$logFile = "C:\aktifitasku\ActivityLog.csv"
$global:history = @()

# Membuat file CSV beserta header-nya jika belum ada
if (-Not (Test-Path $logFile)) {
    "Tanggal,Waktu,Kegiatan" | Out-File -FilePath $logFile -Encoding utf8
} else {
    # Membaca histori dari CSV saat skrip pertama kali dijalankan
    $csvData = Import-Csv -Path $logFile -ErrorAction SilentlyContinue
    if ($csvData -and $csvData.Kegiatan) {
        $allActivities = @($csvData.Kegiatan)
        # Filter agar tulisan "Ganti Hari" tidak masuk ke memori Dropdown
        $allActivities = $allActivities | Where-Object { $_ -notmatch "--- Ganti Hari ---" }
        $global:history = @($allActivities | Select-Object -Unique | Select-Object -First 5)
    }
}

if ($global:history.Count -eq 0) {
    $global:history = @("Sedang bekerja...")
}

function Tampilkan-Popup {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Pencatat Timesheet"
    $form.Size = New-Object System.Drawing.Size(600,240)
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    $besarFont = New-Object System.Drawing.Font("Segoe UI", 16)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20,20)
    $label.Size = New-Object System.Drawing.Size(540,35)
    $label.Font = $besarFont
    $label.Text = "Apa yang sedang Anda kerjakan saat ini?"
    $form.Controls.Add($label)

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(20,60)
    $comboBox.Size = New-Object System.Drawing.Size(540,40)
    $comboBox.Font = $besarFont
    $comboBox.DropDownStyle = 'DropDown'
    
    $comboBox.Items.AddRange($global:history)
    
    if ($global:history.Count -gt 0) {
        $comboBox.Text = $global:history[0]
    }
    $form.Controls.Add($comboBox)

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Location = New-Object System.Drawing.Point(20,110)
    $saveButton.Size = New-Object System.Drawing.Size(120,45)
    $saveButton.Font = $besarFont
    $saveButton.Text = "Simpan"
    $saveButton.Add_Click({
        $activitySafe = $comboBox.Text.Replace(",", " ") 
        
        if ($global:history -contains $activitySafe) {
            $global:history = @($activitySafe) + @($global:history | Where-Object { $_ -ne $activitySafe })
        } else {
            $global:history = @($activitySafe) + $global:history
        }
        
        if ($global:history.Count -gt 5) {
            $global:history = $global:history[0..4]
        }
        
        # --- LOGIKA PENYIMPANAN & PEMBATAS HARI ---
        $date = (Get-Date).ToString("yyyy-MM-dd")
        $time = (Get-Date).ToString("HH:mm:ss")
        $barisBaru = "$date,$time,$activitySafe"
        $headerTetap = "Tanggal,Waktu,Kegiatan"
        $separator = "----------,----------,--- Ganti Hari ---"

        if (Test-Path $logFile) {
            $semuaBaris = @(Get-Content -Path $logFile)
            
            # Filter baris yang valid (ada koma dan bukan header)
            $dataLama = $semuaBaris | Where-Object { $_ -match "," -and $_ -notmatch "^Tanggal" }

            $isGantiHari = $false
            if ($dataLama.Count -gt 0) {
                # Mengambil tanggal dari record terakhir (memotong baris berdasarkan koma)
                $lastDate = ($dataLama[0] -split ",")[0]
                
                # Mengecek jika tanggal berubah dan baris terakhir bukan baris separator
                if (![string]::IsNullOrWhiteSpace($lastDate) -and $lastDate -ne $date -and $lastDate -notmatch "^-") {
                    $isGantiHari = $true
                }
            }

            if ($isGantiHari) {
                # Menyisipkan baris pembatas hari
                $kontenBaru = @($headerTetap, $barisBaru, $separator) + $dataLama
            } else {
                $kontenBaru = @($headerTetap, $barisBaru) + $dataLama
            }
            
            $kontenBaru | Set-Content -Path $logFile -Encoding utf8
        }
        # ------------------------------------------

        $form.Close()
    })
    $form.Controls.Add($saveButton)

    $form.AcceptButton = $saveButton 
    $form.ShowDialog() | Out-Null
}

Write-Host "======================================================"
Write-Host " Aplikasi Pencatat Timesheet sedang berjalan..."
Write-Host " Popup akan muncul setiap $intervalMenit menit."
Write-Host " Log disimpan di: $logFile (Terbaru di atas)"
Write-Host " Tekan CTRL+C di jendela ini untuk menghentikan aplikasi."
Write-Host "======================================================"

while ($true) {
    $waktuMulai = (Get-Date).ToString("HH:mm:ss")
    $waktuBerikutnya = (Get-Date).AddMinutes($intervalMenit).ToString("HH:mm:ss")
    
    Write-Host "[$waktuMulai] Siklus perhitungan $intervalMenit menit dimulai."
    Write-Host "           Popup selanjutnya diperkirakan muncul pukul $waktuBerikutnya..."
    Write-Host "------------------------------------------------------"
    
    Start-Sleep -Seconds ($intervalMenit * 60)
    Tampilkan-Popup
}
