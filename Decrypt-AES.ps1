function Normalize-Key {
    param([string]$Passphrase)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Passphrase)
    foreach ($size in 16, 24, 32) {
        if ($bytes.Length -le $size) {
            $padded = New-Object byte[] $size
            [System.Buffer]::BlockCopy($bytes, 0, $padded, 0, $bytes.Length)
            return $padded
        }
    }
    return $bytes[0..31]
}

function Invoke-AESDecrypt {
    param(
        [string]$CipherB64,
        [string]$Passphrase
    )

    $iv  = [System.Text.Encoding]::ASCII.GetBytes("!QAZ2WSX#EDC4RFV")
    $key = Normalize-Key -Passphrase $Passphrase

    $encrypted = [System.Convert]::FromBase64String($CipherB64)

    $aes             = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode        = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding     = [System.Security.Cryptography.PaddingMode]::None
    $aes.Key         = $key
    $aes.IV          = $iv

    $decryptor = $aes.CreateDecryptor()
    $padded    = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
    $aes.Dispose()

    $padLen = $padded[-1]
    if ($padLen -lt 1 -or $padLen -gt 16) {
        throw "Invalid padding encountered"
    }
    $data = $padded[0..($padded.Length - $padLen - 1)]

    return [System.Text.Encoding]::Unicode.GetString($data)
}

# --- Main ---
Write-Host "AES Decryption Tool"
Write-Host ("-" * 20)

$cipherText  = (Read-Host "Enter the encrypted text to decrypt").Trim()
$passphrase  = (Read-Host "Enter the decrypt key").Trim()

if (-not $cipherText -or -not $passphrase) {
    Write-Host "Error: Both encrypted text and decrypt key are required."
    exit 1
}

try {
    $plaintext = Invoke-AESDecrypt -CipherB64 $cipherText -Passphrase $passphrase
    Write-Host "`nDecrypted text:"
    Write-Host $plaintext
} catch {
    Write-Host "Error: $_"
}
