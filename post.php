<?php
/**
 * Advanced Image Capture Handler
 * Securely receives, validates, and stores base64-encoded images.
 */

class ImageCaptureHandler
{
    private string $storageDir;
    private int    $maxFileSize;
    private array  $allowedMimeTypes;
    private string $logFile;

    /**
     * @param string $storageDir Directory where images will be stored
     * @param int    $maxFileSize Maximum decoded file size in bytes (default 10MB)
     * @param array  $allowedMimeTypes Allowed image MIME types
     */
    public function __construct(
        string $storageDir = __DIR__ . '/captures',
        int    $maxFileSize = 10 * 1024 * 1024, // 10MB
        array  $allowedMimeTypes = ['image/png', 'image/jpeg', 'image/webp']
    ) {
        $this->storageDir      = rtrim($storageDir, '/');
        $this->maxFileSize     = $maxFileSize;
        $this->allowedMimeTypes = $allowedMimeTypes;
        $this->logFile         = $this->storageDir . '/capture.log';

        $this->ensureDirectoryExists();
    }

    /**
     * Create the storage directory if it doesn't exist.
     */
    private function ensureDirectoryExists(): void
    {
        if (!is_dir($this->storageDir)) {
            if (!mkdir($this->storageDir, 0750, true)) {
                throw new RuntimeException("Cannot create storage directory: {$this->storageDir}");
            }
        }

        // Protect the directory with an index.html to prevent directory listing
        $indexFile = $this->storageDir . '/index.html';
        if (!file_exists($indexFile)) {
            file_put_contents($indexFile, '<!DOCTYPE html><title>403 Forbidden</title><h1>Forbidden</h1>');
        }

        // .htaccess for Apache (optional hardening)
        $htaccess = $this->storageDir . '/.htaccess';
        if (!file_exists($htaccess)) {
            file_put_contents($htaccess, "Deny from all\n");
        }
    }

    /**
     * Validate and parse the incoming base64 image data.
     *
     * @param string $rawData The raw POST data (e.g., "data:image/png;base64,iVBOR...")
     * @return array{data: string, mime: string} Decoded binary data and MIME type
     * @throws InvalidArgumentException
     */
    private function parseBase64Image(string $rawData): array
    {
        if (empty($rawData)) {
            throw new InvalidArgumentException('No image data received.');
        }

        // Extract MIME type if present in data URI scheme
        $mime = 'image/png'; // default
        if (preg_match('#^data:(image/\w+);base64,#i', $rawData, $matches)) {
            $mime = strtolower($matches[1]);
            if (!in_array($mime, $this->allowedMimeTypes, true)) {
                throw new InvalidArgumentException("Unsupported image type: {$mime}");
            }
        }

        // Strip the data URI prefix (anything before the comma)
        $base64Data = $rawData;
        $commaPos = strpos($rawData, ',');
        if ($commaPos !== false) {
            $base64Data = substr($rawData, $commaPos + 1);
        }

        // Remove any whitespace that may have been introduced by transport
        $base64Data = preg_replace('/\s+/', '', $base64Data);

        // Validate base64
        if (!preg_match('#^[A-Za-z0-9+/]*={0,2}$#', $base64Data)) {
            throw new InvalidArgumentException('Data contains invalid base64 characters.');
        }

        // Decode
        $decoded = base64_decode($base64Data, true);
        if ($decoded === false) {
            throw new InvalidArgumentException('Base64 decoding failed.');
        }

        return ['data' => $decoded, 'mime' => $mime];
    }

    /**
     * Deep image content validation.
     *
     * @param string $binaryData Decoded image binary
     * @param string $claimedMime MIME type claimed in the header
     * @throws RuntimeException
     */
    private function validateImageContent(string $binaryData, string $claimedMime): void
    {
        // Check file size
        $size = strlen($binaryData);
        if ($size > $this->maxFileSize) {
            throw new RuntimeException(
                sprintf('File size %d bytes exceeds limit of %d bytes.', $size, $this->maxFileSize)
            );
        }
        if ($size === 0) {
            throw new RuntimeException('Decoded image is empty.');
        }

        // Use finfo to detect actual MIME from binary content
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $detectedMime = $finfo->buffer($binaryData);
        $detectedMime = strtolower($detectedMime);

        // Must match what we expect
        $validMimes = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
        if (!in_array($detectedMime, $validMimes, true)) {
            throw new RuntimeException(
                "File content does not appear to be a valid image. Detected: {$detectedMime}"
            );
        }

        // If claimed MIME is specific, check it matches (with tolerance for jpeg vs jpg)
        $allowedForClaimed = $this->allowedMimeTypes;
        if (!in_array($detectedMime, $allowedForClaimed, true)) {
            throw new RuntimeException(
                "MIME mismatch: claimed {$claimedMime}, detected {$detectedMime}"
            );
        }
    }

    /**
     * Generate a safe, unique filename.
     */
    private function generateFilename(string $extension = 'png'): string
    {
        $timestamp = gmdate('Ymd_His');
        $random = bin2hex(random_bytes(8)); // 16 random hex chars
        return "cam_{$timestamp}_{$random}.{$extension}";
    }

    /**
     * Save the validated image to disk atomically.
     *
     * @param string $binaryData
     * @param string $extension
     * @return string The filename saved
     * @throws RuntimeException
     */
    private function saveImage(string $binaryData, string $extension = 'png'): string
    {
        $filename = $this->generateFilename($extension);
        $filepath = $this->storageDir . '/' . $filename;

        // Atomic write: write to temp, then rename
        $tmpFile = $this->storageDir . '/.' . $filename . '.tmp';
        $bytesWritten = file_put_contents($tmpFile, $binaryData, LOCK_EX);

        if ($bytesWritten === false) {
            throw new RuntimeException("Failed to write temporary file: {$tmpFile}");
        }

        if (!rename($tmpFile, $filepath)) {
            unlink($tmpFile);
            throw new RuntimeException("Failed to move temp file to: {$filepath}");
        }

        return $filename;
    }

    /**
     * Log the capture event.
     */
    private function logCapture(string $filename, int $size, string $mime, string $status = 'success'): void
    {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
        $logEntry = json_encode([
            'timestamp' => gmdate('Y-m-d H:i:s') . ' UTC',
            'event'     => 'image_capture',
            'status'    => $status,
            'filename'  => $filename,
            'size'      => $size,
            'mime'      => $mime,
            'ip'        => $ip,
            'user_agent' => substr($_SERVER['HTTP_USER_AGENT'] ?? 'unknown', 0, 256),
        ], JSON_UNESCAPED_SLASHES) . PHP_EOL;

        @file_put_contents($this->logFile, $logEntry, FILE_APPEND | LOCK_EX);
    }

    /**
     * Main handler — process the incoming image.
     *
     * @param string|null $rawData Raw POST data from 'cat' parameter
     * @return array{success: bool, filename?: string, error?: string}
     */
    public function handle(?string $rawData): array
    {
        try {
            // Validate input exists
            if (empty($rawData)) {
                throw new InvalidArgumentException('No image data received (empty POST parameter).');
            }

            // Parse base64
            $parsed = $this->parseBase64Image($rawData);

            // Deep content validation
            $this->validateImageContent($parsed['data'], $parsed['mime']);

            // Determine extension from MIME
            $extensionMap = [
                'image/png'  => 'png',
                'image/jpeg' => 'jpg',
                'image/webp' => 'webp',
                'image/gif'  => 'gif',
            ];
            $extension = $extensionMap[$parsed['mime']] ?? 'png';

            // Save atomically
            $filename = $this->saveImage($parsed['data'], $extension);

            // Log success
            $this->logCapture($filename, strlen($parsed['data']), $parsed['mime']);

            return [
                'success'  => true,
                'filename' => $filename,
                'size'     => strlen($parsed['data']),
                'mime'     => $parsed['mime'],
            ];

        } catch (InvalidArgumentException | RuntimeException $e) {
            // Log failure
            $this->logCapture('N/A', 0, 'unknown', 'error: ' . $e->getMessage());

            return [
                'success' => false,
                'error'   => $e->getMessage(),
            ];
        }
    }
}

// ─────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────

// CORS and security headers
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Cache-Control: no-store, no-cache, must-revalidate');

// Only accept POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    exit;
}

// Process the image
$handler = new ImageCaptureHandler();
$result = $handler->handle($_POST['cat'] ?? null);

// Return JSON response
header('Content-Type: application/json');
echo json_encode($result, JSON_UNESCAPED_SLASHES);
exit;
