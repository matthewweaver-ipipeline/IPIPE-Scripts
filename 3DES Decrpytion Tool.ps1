# PowerShell script to decrypt QA/UAT credentials
# Uses 3DES with MD5 hashed key (matches the Decrypt() method in ERIE_LicenseCheck.svc.cs)

function Decrypt-String {
    param(
        [string]$encryptedString,
        [string]$key
    )

    try {
        # Decode from Base64
        $encryptedBytes = [Convert]::FromBase64String($encryptedString)
        
        # Hash the key with MD5 (matching the C# code)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $keyBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key))
        
        # Create TripleDES decryptor with ECB mode and PKCS7 padding
        $tdes = [System.Security.Cryptography.TripleDESCryptoServiceProvider]::new()
        $tdes.Key = $keyBytes
        $tdes.Mode = [System.Security.Cryptography.CipherMode]::ECB
        $tdes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        # Decrypt
        $decryptor = $tdes.CreateDecryptor()
        $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
        
        # Convert back to string
        $decryptedString = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
        
        $tdes.Clear()
        $md5.Dispose()
        
        return $decryptedString
    }
    catch {
        Write-Error "Decryption failed: $_"
        return $null
    }
}

# Get input from user
Write-Host "QA/UAT Credential Decryption Tool" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

$encryptedString = Read-Host "Enter the encrypted string"
$key = Read-Host "Enter the decryption key"

Write-Host ""
Write-Host "Decrypting..." -ForegroundColor Yellow

$decryptedString = Decrypt-String $encryptedString $key

if ($decryptedString) {
    Write-Host ""
    Write-Host "Decrypted Result: " -NoNewline
    Write-Host $decryptedString -ForegroundColor Green
}
else {
    Write-Host "Decryption failed. Please check your inputs and try again." -ForegroundColor Red
}
