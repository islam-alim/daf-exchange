param([int]$Port = 5500)

$root = (Resolve-Path $PSScriptRoot).Path
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "DaF Exchange is running at http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server."

$mimeTypes = @{
  '.css' = 'text/css; charset=utf-8'; '.html' = 'text/html; charset=utf-8'
  '.js' = 'text/javascript; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
  '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $relativePath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'index.html' }
    $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath.Replace('/', '\')))

    if (-not $filePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
      $context.Response.StatusCode = 404
      $bytes = [System.Text.Encoding]::UTF8.GetBytes('Not found')
    } else {
      $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
      $contentType = $mimeTypes[$extension]
      if (-not $contentType) { $contentType = 'application/octet-stream' }
      $context.Response.ContentType = $contentType
      $bytes = [System.IO.File]::ReadAllBytes($filePath)
    }

    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.Close()
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
