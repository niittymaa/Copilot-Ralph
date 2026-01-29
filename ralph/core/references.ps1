<#
.SYNOPSIS
    Reference file management module for Ralph Loop

.DESCRIPTION
    Provides comprehensive reference handling including:
    - Multi-directory reference discovery
    - Support for text, structured data, and images
    - Path-based reference handling (no file caching)
    - Session-aware reference tracking
    - Unified content merging for AI analysis

.NOTES
    References are stored as paths only - files are read during analysis
    and results are stored, not the raw files themselves.
#>

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:ReferencePaths = @{
    ProjectRoot          = $null
    DefaultSpecDir       = $null
    DefaultReferenceDir  = $null
    RalphDir             = $null
}

# Supported file types by category
$script:SupportedFileTypes = @{
    Text = @{
        Extensions = @('.md', '.txt', '.text')
        MimeType   = 'text/plain'
        Handler    = 'ReadTextContent'
    }
    Markdown = @{
        Extensions = @('.md', '.markdown')
        MimeType   = 'text/markdown'
        Handler    = 'ReadTextContent'
    }
    StructuredData = @{
        Extensions = @('.json', '.yaml', '.yml', '.toml', '.xml', '.csv', '.ini')
        MimeType   = 'application/json'
        Handler    = 'ReadStructuredContent'
    }
    Code = @{
        Extensions = @('.ps1', '.py', '.js', '.ts', '.cs', '.java', '.go', '.rb', '.php', '.swift', '.kt', '.rs', '.sql')
        MimeType   = 'text/plain'
        Handler    = 'ReadCodeContent'
    }
    Image = @{
        Extensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg')
        MimeType   = 'image/*'
        Handler    = 'ReadImageContent'
    }
}

# Session reference storage (in-memory for current session)
$script:SessionReferences = @{
    Directories = @()  # Array of @{ Path='...', Type='spec'|'reference' }
    Files       = @()
    AnalysisComplete = $false
    AnalysisResult = $null
}

# ═══════════════════════════════════════════════════════════════
#                     INITIALIZATION
# ═══════════════════════════════════════════════════════════════

function Initialize-ReferencePaths {
    <#
    .SYNOPSIS
        Initializes reference system paths
    .PARAMETER ProjectRoot
        Root directory of the project
    .PARAMETER RalphDir
        Ralph directory path (internal .ralph folder, not used for references)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot,
        
        [string]$RalphDir = ''
    )
    
    $script:ReferencePaths.ProjectRoot = $ProjectRoot
    
    # RalphDir points to .ralph (internal cache), but references go in ralph/ (user folder)
    if ($RalphDir) {
        $script:ReferencePaths.RalphDir = $RalphDir
    } else {
        $script:ReferencePaths.RalphDir = Join-Path $ProjectRoot '.ralph'
    }
    
    # Note: DefaultSpecDir is set but NOT auto-created - only create on-demand when user explicitly selects it
    $script:ReferencePaths.DefaultSpecDir = Join-Path $ProjectRoot 'spec'
    
    # References always go in ralph/references/ (user folder), not .ralph/references/ (internal)
    $userRalphDir = Join-Path $ProjectRoot 'ralph'
    $script:ReferencePaths.DefaultReferenceDir = Join-Path $userRalphDir 'references'
    
    # Ensure default reference directory exists (inside ralph/, not .ralph/)
    # Note: We do NOT auto-create DefaultSpecDir - use ralph/specs/ as the primary spec location
    if (-not (Test-Path $script:ReferencePaths.DefaultReferenceDir)) {
        New-Item -ItemType Directory -Path $script:ReferencePaths.DefaultReferenceDir -Force | Out-Null
    }
    
    # Clear session references for fresh start
    Clear-SessionReferences
}

function Clear-SessionReferences {
    <#
    .SYNOPSIS
        Clears current session references
    #>
    $script:SessionReferences = @{
        Directories = @()
        Files       = @()
        AnalysisComplete = $false
        AnalysisResult = $null
    }
}

# ═══════════════════════════════════════════════════════════════
#                     FILE TYPE DETECTION
# ═══════════════════════════════════════════════════════════════

function Get-SupportedFileTypes {
    <#
    .SYNOPSIS
        Returns all supported file types and their categories
    .OUTPUTS
        Hashtable of supported file types
    #>
    return $script:SupportedFileTypes
}

function Get-FileCategory {
    <#
    .SYNOPSIS
        Determines the category of a file based on its extension
    .PARAMETER Path
        File path to check
    .OUTPUTS
        Category name or $null if not supported
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    # Ensure SupportedFileTypes is available
    if (-not $script:SupportedFileTypes) {
        $script:SupportedFileTypes = @{
            Text = @{ Extensions = @('.md', '.txt', '.text') }
            Markdown = @{ Extensions = @('.md', '.markdown') }
            StructuredData = @{ Extensions = @('.json', '.yaml', '.yml', '.toml', '.xml', '.csv', '.ini') }
            Code = @{ Extensions = @('.ps1', '.py', '.js', '.ts', '.cs', '.java', '.go', '.rb', '.php', '.swift', '.kt', '.rs', '.sql') }
            Image = @{ Extensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg') }
        }
    }
    
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    
    foreach ($category in $script:SupportedFileTypes.Keys) {
        if ($ext -in $script:SupportedFileTypes[$category].Extensions) {
            return $category
        }
    }
    
    return $null
}

function Test-SupportedFile {
    <#
    .SYNOPSIS
        Tests if a file is a supported reference type
    .PARAMETER Path
        File path to check
    .OUTPUTS
        Boolean - true if supported
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    return $null -ne (Get-FileCategory -Path $Path)
}

function Test-ImageFile {
    <#
    .SYNOPSIS
        Tests if a file is an image
    .PARAMETER Path
        File path to check
    .OUTPUTS
        Boolean
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    return (Get-FileCategory -Path $Path) -eq 'Image'
}

function Test-IsSpecFile {
    <#
    .SYNOPSIS
        Tests if a markdown file is a specification (not a reference)
    .DESCRIPTION
        Specs typically have:
        - Headers describing requirements/features
        - User stories or acceptance criteria
        - TODO items or task lists
        References are more like documentation, examples, or supporting materials
    .PARAMETER Path
        File path to check
    .OUTPUTS
        Boolean - true if likely a spec file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) { return $false }
    
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($ext -notin @('.md', '.markdown')) { return $false }
    
    try {
        $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return $false }
        
        # Spec indicators (patterns suggesting this is a specification)
        $specPatterns = @(
            '(?i)##\s*(requirements?|features?|user stor|acceptance criteria|specifications?)',
            '(?i)\[\s*\]\s+',  # Unchecked checkbox (task list)
            '(?i)(must|shall|should|will)\s+(be|have|support|allow|enable)',
            '(?i)(as a|given|when|then)',  # User story / BDD patterns
            '(?i)##\s*(overview|goals?|objectives?|scope)'
        )
        
        foreach ($pattern in $specPatterns) {
            if ($content -match $pattern) {
                return $true
            }
        }
        
        return $false
    } catch {
        return $false
    }
}

function Get-FolderType {
    <#
    .SYNOPSIS
        Determines if a folder is a spec folder or reference folder
    .PARAMETER Path
        Directory path to check
    .OUTPUTS
        String - 'spec', 'reference', or 'unknown'
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return 'unknown'
    }
    
    $normalizedPath = $Path.TrimEnd('\', '/').ToLower()
    $folderName = Split-Path $normalizedPath -Leaf
    
    # Check if it's a known spec folder
    $specFolderNames = @('spec', 'specs')
    if ($folderName -in $specFolderNames) {
        return 'spec'
    }
    
    # Check if it's inside ralph/specs
    if ($normalizedPath -like '*\ralph\specs' -or $normalizedPath -like '*\ralph\specs\*') {
        return 'spec'
    }
    
    # Check if it's a known reference folder
    if ($folderName -eq 'references' -or $folderName -eq 'reference') {
        return 'reference'
    }
    
    # Everything else is assumed to be a reference folder
    return 'reference'
}

function Get-FileClassification {
    <#
    .SYNOPSIS
        Classifies a file as spec or reference
    .PARAMETER Path
        File path to check
    .PARAMETER FolderType
        Optional folder type hint ('spec', 'reference', or 'unknown')
    .OUTPUTS
        String - 'spec', 'reference', or 'unknown'
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$FolderType = 'unknown'
    )
    
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    
    # Non-markdown files are always references
    if ($ext -notin @('.md', '.markdown')) {
        return 'reference'
    }
    
    # If we know the folder type, use it for .md files
    if ($FolderType -eq 'spec') {
        return 'spec'
    } elseif ($FolderType -eq 'reference') {
        return 'reference'
    }
    
    # Fall back to heuristic classification for unknown folder types
    if (Test-IsSpecFile -Path $Path) {
        return 'spec'
    }
    
    return 'reference'
}

# ═══════════════════════════════════════════════════════════════
#                     REFERENCE DISCOVERY
# ═══════════════════════════════════════════════════════════════

function Get-ReferenceFilesFromDirectory {
    <#
    .SYNOPSIS
        Gets all supported reference files from a directory
    .PARAMETER Directory
        Directory to scan
    .PARAMETER Recurse
        Whether to scan subdirectories
    .PARAMETER IncludeClassification
        Whether to include spec/reference classification for markdown files
    .PARAMETER FolderType
        Optional folder type ('spec' or 'reference') to optimize classification
    .OUTPUTS
        Array of file info objects with metadata
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,
        
        [switch]$Recurse,
        
        [switch]$IncludeClassification,
        
        [string]$FolderType = ''
    )
    
    if (-not (Test-Path $Directory)) {
        return @()
    }
    
    # Auto-detect folder type if not provided
    if (-not $FolderType) {
        $FolderType = Get-FolderType -Path $Directory
    }
    
    # Ensure SupportedFileTypes is available (fallback if script scope lost)
    if (-not $script:SupportedFileTypes) {
        $script:SupportedFileTypes = @{
            Text = @{ Extensions = @('.md', '.txt', '.text') }
            Markdown = @{ Extensions = @('.md', '.markdown') }
            StructuredData = @{ Extensions = @('.json', '.yaml', '.yml', '.toml', '.xml', '.csv', '.ini') }
            Code = @{ Extensions = @('.ps1', '.py', '.js', '.ts', '.cs', '.java', '.go', '.rb', '.php', '.swift', '.kt', '.rs', '.sql') }
            Image = @{ Extensions = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg') }
        }
    }
    
    $allExtensions = @()
    foreach ($category in $script:SupportedFileTypes.Values) {
        $allExtensions += $category.Extensions
    }
    
    $files = @()
    $searchParams = @{
        Path = $Directory
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($Recurse) {
        $searchParams.Recurse = $true
    }
    
    $foundFiles = Get-ChildItem @searchParams
    
    foreach ($file in $foundFiles) {
        $ext = $file.Extension.ToLower()
        if ($ext -in $allExtensions) {
            # Skip template files starting with underscore
            if (-not $file.Name.StartsWith('_')) {
                $category = Get-FileCategory -Path $file.FullName
                $classification = if ($IncludeClassification) { 
                    Get-FileClassification -Path $file.FullName -FolderType $FolderType 
                } else { 
                    $null 
                }
                
                $files += @{
                    Path           = $file.FullName
                    Name           = $file.Name
                    Extension      = $ext
                    Category       = $category
                    Size           = $file.Length
                    IsImage        = $category -eq 'Image'
                    IsSpec         = $classification -eq 'spec'
                    Classification = $classification
                    RelativePath   = $file.FullName.Replace($script:ReferencePaths.ProjectRoot, '').TrimStart('\', '/')
                }
            }
        }
    }
    
    return $files
}

function Get-DefaultSpecFiles {
    <#
    .SYNOPSIS
        Gets reference files from the default spec directory
    .OUTPUTS
        Array of file info objects
    #>
    $specDir = $script:ReferencePaths.DefaultSpecDir
    
    if (-not (Test-Path $specDir)) {
        return @()
    }
    
    return Get-ReferenceFilesFromDirectory -Directory $specDir
}

function Get-AllSessionReferences {
    <#
    .SYNOPSIS
        Gets all reference files from all registered directories, explicit files, and session-references folder
    .OUTPUTS
        Array of file info objects with metadata
    #>
    $allFiles = @()
    $seenPaths = @{}
    $seenNames = @{}  # Track filenames to de-duplicate across directories
    
    # Ensure session references is initialized
    if (-not $script:SessionReferences) {
        $script:SessionReferences = @{
            Directories = @()
            Files       = @()
            AnalysisComplete = $false
            AnalysisResult = $null
        }
    }
    
    # FIRST: Add files from session-references folder (primary source for persisted references)
    # This ensures references copied to the session folder are always found
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
        if ($activeTaskId -and (Get-Command Get-SessionReferencesFolder -ErrorAction SilentlyContinue)) {
            $sessionRefsFolder = Get-SessionReferencesFolder -TaskId $activeTaskId
            if ($sessionRefsFolder -and (Test-Path $sessionRefsFolder)) {
                $sessionFiles = Get-ReferenceFilesFromDirectory -Directory $sessionRefsFolder -FolderType 'reference'
                foreach ($file in $sessionFiles) {
                    if (-not $seenPaths.ContainsKey($file.Path)) {
                        $seenPaths[$file.Path] = $true
                        $seenNames[$file.Name] = $true  # Track by filename
                        $file.Source = 'SessionFolder'
                        $file.SourcePath = $sessionRefsFolder
                        $file.SourceFolderType = 'reference'
                        $allFiles += $file
                    }
                }
            }
        }
    }
    
    # Add files from registered directories
    foreach ($dirEntry in @($script:SessionReferences.Directories)) {
        # Handle both hashtable and PSCustomObject from JSON deserialization
        $dir = if ($dirEntry -is [hashtable]) { $dirEntry.Path } else { $dirEntry.Path }
        $folderType = if ($dirEntry -is [hashtable]) { $dirEntry.Type } else { $dirEntry.Type }
        
        # Skip if dir is empty or null
        if (-not $dir) { continue }
        
        if (Test-Path $dir) {
            $dirFiles = Get-ReferenceFilesFromDirectory -Directory $dir -FolderType $folderType
            foreach ($file in $dirFiles) {
                # Skip if already seen by path OR by filename (de-duplicate copies)
                if (-not $seenPaths.ContainsKey($file.Path) -and -not $seenNames.ContainsKey($file.Name)) {
                    $seenPaths[$file.Path] = $true
                    $seenNames[$file.Name] = $true
                    $file.Source = 'Directory'
                    $file.SourcePath = $dir
                    $file.SourceFolderType = $folderType
                    $allFiles += $file
                }
            }
        }
    }
    
    # Add explicitly registered files
    foreach ($filePath in @($script:SessionReferences.Files)) {
        $fileName = Split-Path -Leaf $filePath
        # Skip if already seen by path OR by filename
        if ((Test-Path $filePath) -and -not $seenPaths.ContainsKey($filePath) -and -not $seenNames.ContainsKey($fileName)) {
            $seenPaths[$filePath] = $true
            $seenNames[$fileName] = $true
            $category = Get-FileCategory -Path $filePath
            $fileInfo = Get-Item $filePath
            $allFiles += @{
                Path       = $filePath
                Name       = $fileInfo.Name
                Extension  = $fileInfo.Extension.ToLower()
                Category   = $category
                Size       = $fileInfo.Length
                IsImage    = $category -eq 'Image'
                RelativePath = $filePath.Replace($script:ReferencePaths.ProjectRoot, '').TrimStart('\', '/')
                Source     = 'Explicit'
                SourcePath = $filePath
            }
        }
    }
    
    return $allFiles
}

# ═══════════════════════════════════════════════════════════════
#                     REFERENCE REGISTRATION
# ═══════════════════════════════════════════════════════════════

function Add-ReferenceDirectory {
    <#
    .SYNOPSIS
        Adds a directory to the session's reference sources
    .PARAMETER Directory
        Directory path to add
    .PARAMETER FolderType
        Optional folder type override ('spec' or 'reference'). If not provided, auto-detected.
    .OUTPUTS
        Hashtable with Success, Warning, and FolderType properties
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,
        
        [ValidateSet('spec', 'reference', '')]
        [string]$FolderType = ''
    )
    
    if (-not (Test-Path $Directory)) {
        return @{ Success = $false; Warning = ''; FolderType = 'unknown' }
    }
    
    $fullPath = (Resolve-Path $Directory).Path
    
    # Auto-detect folder type if not provided
    if (-not $FolderType) {
        $FolderType = Get-FolderType -Path $fullPath
    }
    
    # Check for existing entry and update if needed
    $existing = $script:SessionReferences.Directories | Where-Object { $_.Path -eq $fullPath }
    if ($existing) {
        # Already exists, update type if different
        if ($existing.Type -ne $FolderType) {
            $existing.Type = $FolderType
            $script:SessionReferences.AnalysisComplete = $false
        }
        return @{ 
            Success = $true
            Warning = ''
            FolderType = $FolderType
        }
    }
    
    # Add new directory with type
    $script:SessionReferences.Directories += @{
        Path = $fullPath
        Type = $FolderType
    }
    $script:SessionReferences.AnalysisComplete = $false
    
    # Persist to task.json so references survive session state changes
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
        if ($activeTaskId) {
            Save-SessionReferences -TaskId $activeTaskId | Out-Null
        }
    }
    
    # Generate warning if spec folder is being used
    $warning = ''
    if ($FolderType -eq 'spec') {
        $warning = 'This is a spec folder. Consider using the references folder for non-spec files.'
    }
    
    return @{
        Success = $true
        Warning = $warning
        FolderType = $FolderType
    }
}

function Add-ReferenceFile {
    <#
    .SYNOPSIS
        Adds an explicit file to the session's references
    .PARAMETER FilePath
        File path to add
    .OUTPUTS
        Boolean - true if added successfully
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    if (-not (Test-SupportedFile -Path $FilePath)) {
        return $false
    }
    
    $fullPath = (Resolve-Path $FilePath).Path
    
    if ($fullPath -notin $script:SessionReferences.Files) {
        $script:SessionReferences.Files += $fullPath
        $script:SessionReferences.AnalysisComplete = $false
        
        # Persist to task.json so references survive session state changes
        if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
            $activeTaskId = Get-ActiveTaskId
            if ($activeTaskId) {
                Save-SessionReferences -TaskId $activeTaskId | Out-Null
            }
        }
    }
    
    return $true
}

function Remove-ReferenceDirectory {
    <#
    .SYNOPSIS
        Removes a directory from session references
    .PARAMETER Directory
        Directory path to remove
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )
    
    $script:SessionReferences.Directories = @($script:SessionReferences.Directories | Where-Object { $_.Path -ne $Directory })
    $script:SessionReferences.AnalysisComplete = $false
    
    # Persist to task.json
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
        if ($activeTaskId) {
            Save-SessionReferences -TaskId $activeTaskId | Out-Null
        }
    }
}

function Remove-ReferenceFile {
    <#
    .SYNOPSIS
        Removes a file from session references
    .PARAMETER FilePath
        File path to remove
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $script:SessionReferences.Files = @($script:SessionReferences.Files | Where-Object { $_ -ne $FilePath })
    $script:SessionReferences.AnalysisComplete = $false
    
    # Persist to task.json
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
        if ($activeTaskId) {
            Save-SessionReferences -TaskId $activeTaskId | Out-Null
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#                     CONTENT READING
# ═══════════════════════════════════════════════════════════════

function Read-TextContent {
    <#
    .SYNOPSIS
        Reads text file content
    .PARAMETER Path
        File path
    .OUTPUTS
        Hashtable with content and metadata
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return @{ Success = $false; Error = 'File not found' }
    }
    
    try {
        $content = Get-Content $Path -Raw -Encoding UTF8
        return @{
            Success  = $true
            Content  = $content
            Lines    = ($content -split "`n").Count
            Encoding = 'UTF8'
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Read-StructuredContent {
    <#
    .SYNOPSIS
        Reads structured data file content
    .PARAMETER Path
        File path
    .OUTPUTS
        Hashtable with content and metadata
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return @{ Success = $false; Error = 'File not found' }
    }
    
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    
    try {
        $rawContent = Get-Content $Path -Raw -Encoding UTF8
        $parsed = $null
        $format = $ext.TrimStart('.')
        
        switch ($ext) {
            '.json' {
                $parsed = $rawContent | ConvertFrom-Json
            }
            { $_ -in '.yaml', '.yml' } {
                # YAML parsing - just return raw for now, AI can interpret
                $parsed = $rawContent
            }
            '.xml' {
                $parsed = [xml]$rawContent
            }
            '.csv' {
                $parsed = $rawContent | ConvertFrom-Csv
            }
            default {
                $parsed = $rawContent
            }
        }
        
        return @{
            Success  = $true
            Content  = $rawContent
            Parsed   = $parsed
            Format   = $format
        }
    } catch {
        return @{
            Success = $true  # Still return raw content even if parsing fails
            Content = (Get-Content $Path -Raw -Encoding UTF8)
            Format  = $ext.TrimStart('.')
            ParseError = $_.Exception.Message
        }
    }
}

function Read-ImageContent {
    <#
    .SYNOPSIS
        Reads image file and prepares it for AI analysis
    .DESCRIPTION
        Converts image to base64 for embedding in AI prompts
    .PARAMETER Path
        Image file path
    .OUTPUTS
        Hashtable with base64 content and metadata
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        return @{ Success = $false; Error = 'File not found' }
    }
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $base64 = [Convert]::ToBase64String($bytes)
        
        $ext = [System.IO.Path]::GetExtension($Path).ToLower()
        $mimeType = switch ($ext) {
            '.png'  { 'image/png' }
            '.jpg'  { 'image/jpeg' }
            '.jpeg' { 'image/jpeg' }
            '.gif'  { 'image/gif' }
            '.webp' { 'image/webp' }
            '.bmp'  { 'image/bmp' }
            '.svg'  { 'image/svg+xml' }
            default { 'application/octet-stream' }
        }
        
        return @{
            Success     = $true
            Base64      = $base64
            MimeType    = $mimeType
            SizeBytes   = $bytes.Length
            DataUri     = "data:$mimeType;base64,$base64"
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Read-ReferenceContent {
    <#
    .SYNOPSIS
        Reads any reference file based on its type
    .PARAMETER Path
        File path
    .OUTPUTS
        Hashtable with content and metadata
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $category = Get-FileCategory -Path $Path
    
    if (-not $category) {
        return @{ Success = $false; Error = 'Unsupported file type' }
    }
    
    $result = switch ($category) {
        'Image' { Read-ImageContent -Path $Path }
        'StructuredData' { Read-StructuredContent -Path $Path }
        default { Read-TextContent -Path $Path }
    }
    
    $result.Path = $Path
    $result.Category = $category
    $result.Name = [System.IO.Path]::GetFileName($Path)
    
    return $result
}

# ═══════════════════════════════════════════════════════════════
#                     CONTENT MERGING
# ═══════════════════════════════════════════════════════════════

function Build-ReferenceAnalysisPrompt {
    <#
    .SYNOPSIS
        Builds a unified prompt for AI analysis of all references
    .DESCRIPTION
        Combines text specs, structured data, and image paths
        into a single comprehensive prompt for the AI planner.
        Images are referenced by path - the AI will read them using its tools.
    .PARAMETER References
        Array of reference file objects
    .OUTPUTS
        String - Complete analysis prompt
    #>
    param(
        [Parameter(Mandatory)]
        [array]$References
    )
    
    $promptParts = @()
    $textSpecs = @()
    $structuredData = @()
    $images = @()
    
    # Categorize references - for text files read content, for images just note the path
    foreach ($ref in $References) {
        switch ($ref.Category) {
            'Image' {
                # Just store the path - AI will read the image using its tools
                $images += @{
                    Name = $ref.Name
                    Path = $ref.Path
                    RelativePath = $ref.RelativePath
                }
            }
            'StructuredData' {
                $content = Read-ReferenceContent -Path $ref.Path
                if ($content.Success) {
                    $structuredData += @{
                        Name = $ref.Name
                        Path = $ref.RelativePath
                        Content = $content.Content
                        Format = $content.Format
                    }
                }
            }
            default {
                $content = Read-ReferenceContent -Path $ref.Path
                if ($content.Success) {
                    $textSpecs += @{
                        Name = $ref.Name
                        Path = $ref.RelativePath
                        Content = $content.Content
                    }
                }
            }
        }
    }
    
    # Build text specifications section
    if ($textSpecs.Count -gt 0) {
        $promptParts += "## Text Specifications"
        $promptParts += ""
        foreach ($spec in $textSpecs) {
            $promptParts += "### $($spec.Name)"
            $promptParts += "File: ``$($spec.Path)``"
            $promptParts += ""
            $promptParts += $spec.Content
            $promptParts += ""
            $promptParts += "---"
            $promptParts += ""
        }
    }
    
    # Build structured data section
    if ($structuredData.Count -gt 0) {
        $promptParts += "## Structured Data References"
        $promptParts += ""
        foreach ($data in $structuredData) {
            $promptParts += "### $($data.Name) ($($data.Format))"
            $promptParts += "File: ``$($data.Path)``"
            $promptParts += ""
            $promptParts += '```' + $data.Format
            $promptParts += $data.Content
            $promptParts += '```'
            $promptParts += ""
        }
    }
    
    # Build image references section - just paths, AI reads them
    if ($images.Count -gt 0) {
        $promptParts += "## Visual References (Images)"
        $promptParts += ""
        $promptParts += "The following image files are provided as visual references."
        $promptParts += "**YOU MUST READ EACH IMAGE** using the view tool to analyze them."
        $promptParts += ""
        $promptParts += "For each image, analyze:"
        $promptParts += "- UI structure and layout"
        $promptParts += "- Component hierarchy"
        $promptParts += "- User interaction flows"
        $promptParts += "- Visual design patterns"
        $promptParts += "- Implied functionality and features"
        $promptParts += ""
        $promptParts += "### Image Files to Read:"
        $promptParts += ""
        
        foreach ($img in $images) {
            $promptParts += "- **$($img.Name)**: ``$($img.Path)``"
        }
        
        $promptParts += ""
        $promptParts += "**ACTION REQUIRED**: Use the view tool to read each image file listed above before proceeding."
        $promptParts += ""
    }
    
    return ($promptParts -join "`n")
}

function Build-ImageAnalysisPrompt {
    <#
    .SYNOPSIS
        Builds a specialized prompt for image-only analysis
    .DESCRIPTION
        Creates a focused prompt for analyzing UI wireframes, mockups,
        and other visual materials. Passes file paths for AI to read.
    .PARAMETER Images
        Array of image reference objects
    .OUTPUTS
        String - Image analysis prompt
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Images
    )
    
    $prompt = @"
# Image Analysis Task

**YOU MUST READ EACH IMAGE FILE** using the view tool before analyzing.

## Image Files to Read:

"@
    
    foreach ($img in $Images) {
        $prompt += "- **$($img.Name)**: ``$($img.Path)``"
        $prompt += "`n"
    }
    
    $prompt += @"

## For Each Image, Analyze:

1. **Structure Analysis**
   - Identify all UI components (buttons, forms, lists, cards, etc.)
   - Map the visual hierarchy
   - Note layout patterns (grid, flex, columns, etc.)

2. **Logic Extraction**
   - What user actions are implied?
   - What data flows are suggested?
   - What state changes should occur?

3. **UX Flow Mapping**
   - How do screens connect?
   - What navigation patterns are used?
   - What is the optimal user journey?

4. **Implementation Notes**
   - Suggest component breakdown
   - Identify reusable patterns
   - Note responsive design considerations

---

**ACTION REQUIRED**: Use the view tool to read each image file listed above, then provide your analysis.

"@
    
    return $prompt
}

# ═══════════════════════════════════════════════════════════════
#                     SESSION PERSISTENCE
# ═══════════════════════════════════════════════════════════════

function Save-SessionReferences {
    <#
    .SYNOPSIS
        Saves session references to task.json
    .PARAMETER TaskId
        Task ID to save references for
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    $configFile = Join-Path $taskDir 'task.json'
    
    if (-not (Test-Path $configFile)) {
        return $false
    }
    
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        
        # Add references to config
        $config | Add-Member -NotePropertyName 'referenceDirectories' -NotePropertyValue $script:SessionReferences.Directories -Force
        $config | Add-Member -NotePropertyName 'referenceFiles' -NotePropertyValue $script:SessionReferences.Files -Force
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

function Load-SessionReferences {
    <#
    .SYNOPSIS
        Loads session references from task.json
    .PARAMETER TaskId
        Task ID to load references for
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TaskId
    )
    
    Clear-SessionReferences
    
    $taskDir = Get-TaskDirectory -TaskId $TaskId
    $configFile = Join-Path $taskDir 'task.json'
    
    if (-not (Test-Path $configFile)) {
        return $false
    }
    
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        
        if ($config.referenceDirectories) {
            $script:SessionReferences.Directories = @($config.referenceDirectories)
        }
        
        if ($config.referenceFiles) {
            $script:SessionReferences.Files = @($config.referenceFiles)
        }
        
        return $true
    } catch {
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
#                     ANALYSIS STATE
# ═══════════════════════════════════════════════════════════════

function Set-AnalysisComplete {
    <#
    .SYNOPSIS
        Marks analysis as complete with results
    .PARAMETER Result
        Analysis result to store
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Result
    )
    
    $script:SessionReferences.AnalysisComplete = $true
    $script:SessionReferences.AnalysisResult = $Result
}

function Test-AnalysisComplete {
    <#
    .SYNOPSIS
        Tests if analysis has been completed
    .OUTPUTS
        Boolean
    #>
    return $script:SessionReferences.AnalysisComplete
}

function Get-AnalysisResult {
    <#
    .SYNOPSIS
        Gets the stored analysis result
    .OUTPUTS
        String - Analysis result or $null
    #>
    return $script:SessionReferences.AnalysisResult
}

# ═══════════════════════════════════════════════════════════════
#                     SUMMARY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Get-DirectoryFileSummary {
    <#
    .SYNOPSIS
        Gets a summary of files in a directory by type
    .PARAMETER Directory
        Directory path to analyze
    .PARAMETER FolderType
        Optional folder type ('spec' or 'reference') for optimized classification
    .OUTPUTS
        Hashtable with counts, formatted string, and folder type
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,
        
        [string]$FolderType = ''
    )
    
    if (-not (Test-Path $Directory)) {
        return @{
            Valid = $false
            Error = "Directory not found"
            FormattedSummary = "not found"
            FolderType = 'unknown'
        }
    }
    
    # Auto-detect folder type if not provided
    if (-not $FolderType) {
        $FolderType = Get-FolderType -Path $Directory
    }
    
    $files = @(Get-ReferenceFilesFromDirectory -Directory $Directory -IncludeClassification -FolderType $FolderType)
    
    if ($files.Count -eq 0) {
        return @{
            Valid = $true
            TotalFiles = 0
            Images = 0
            Text = 0
            Data = 0
            Code = 0
            Specs = 0
            FormattedSummary = "empty"
            FolderType = $FolderType
        }
    }
    
    # Count by category
    $images = @($files | Where-Object { $_.IsImage }).Count
    $specs = @($files | Where-Object { $_.IsSpec }).Count
    $text = @($files | Where-Object { $_.Category -in @('Text', 'Markdown') -and -not $_.IsSpec }).Count
    $data = @($files | Where-Object { $_.Category -eq 'StructuredData' }).Count
    $code = @($files | Where-Object { $_.Category -eq 'Code' }).Count
    
    # Build formatted summary
    $parts = @()
    if ($specs -gt 0) { $parts += "$specs spec$(if($specs -ne 1){'s'})" }
    if ($images -gt 0) { $parts += "$images image$(if($images -ne 1){'s'})" }
    if ($text -gt 0) { $parts += "$text text" }
    if ($data -gt 0) { $parts += "$data data" }
    if ($code -gt 0) { $parts += "$code code" }
    
    $formatted = if ($parts.Count -gt 0) { $parts -join ', ' } else { "no supported files" }
    
    return @{
        Valid = $true
        TotalFiles = $files.Count
        Images = $images
        Text = $text
        Data = $data
        Code = $code
        Specs = $specs
        FormattedSummary = $formatted
        FolderType = $FolderType
    }
}

function Get-RegisteredDirectoriesWithSummary {
    <#
    .SYNOPSIS
        Gets all registered directories with file summaries
    .OUTPUTS
        Array of directory info with file counts and folder type
    #>
    if (-not $script:SessionReferences) {
        return @()
    }
    
    $result = @()
    foreach ($dirEntry in @($script:SessionReferences.Directories)) {
        $dir = $dirEntry.Path
        $folderType = $dirEntry.Type
        
        $summary = Get-DirectoryFileSummary -Directory $dir -FolderType $folderType
        $shortPath = $dir
        
        # Make path relative to project root if possible
        if ($script:ReferencePaths.ProjectRoot -and $dir.StartsWith($script:ReferencePaths.ProjectRoot)) {
            $shortPath = $dir.Substring($script:ReferencePaths.ProjectRoot.Length).TrimStart('\', '/')
        }
        
        # Add folder type indicator to label
        $typeIndicator = if ($folderType -eq 'spec') { '[SPEC]' } else { '[REF]' }
        
        $result += @{
            Path = $dir
            ShortPath = $shortPath
            FolderType = $folderType
            Summary = $summary
            FormattedLabel = "$typeIndicator $shortPath`: $($summary.FormattedSummary)"
        }
    }
    
    return $result
}

function Get-RegisteredFilesWithInfo {
    <#
    .SYNOPSIS
        Gets all explicitly registered files with info
    .OUTPUTS
        Array of file info objects
    #>
    if (-not $script:SessionReferences) {
        return @()
    }
    
    $result = @()
    foreach ($filePath in @($script:SessionReferences.Files)) {
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
            $category = Get-FileCategory -Path $filePath
            $shortPath = $filePath
            
            # Make path relative to project root if possible
            if ($script:ReferencePaths.ProjectRoot -and $filePath.StartsWith($script:ReferencePaths.ProjectRoot)) {
                $shortPath = $filePath.Substring($script:ReferencePaths.ProjectRoot.Length).TrimStart('\', '/')
            }
            
            $sizeMB = [math]::Round($fileInfo.Length / 1KB, 1)
            $result += @{
                Path = $filePath
                ShortPath = $shortPath
                Name = $fileInfo.Name
                Category = $category
                Size = $fileInfo.Length
                SizeFormatted = "$sizeMB KB"
                FormattedLabel = "$shortPath ($category, $sizeMB KB)"
            }
        }
    }
    
    return $result
}

function Get-ReferenceSummary {
    <#
    .SYNOPSIS
        Gets a summary of all registered references
    .OUTPUTS
        Hashtable with counts and lists
    #>
    $refs = @(Get-AllSessionReferences)
    
    # Ensure session references is initialized
    if (-not $script:SessionReferences) {
        $script:SessionReferences = @{
            Directories = @()
            Files       = @()
            AnalysisComplete = $false
            AnalysisResult = $null
        }
    }
    
    $summary = @{
        TotalFiles      = $refs.Count
        Directories     = @($script:SessionReferences.Directories).Count
        ExplicitFiles   = @($script:SessionReferences.Files).Count
        ByCategory      = @{}
        TextFiles       = @()
        ImageFiles      = @()
        DataFiles       = @()
    }
    
    foreach ($ref in $refs) {
        if (-not $summary.ByCategory.ContainsKey($ref.Category)) {
            $summary.ByCategory[$ref.Category] = 0
        }
        $summary.ByCategory[$ref.Category]++
        
        if ($ref.IsImage) {
            $summary.ImageFiles += $ref
        } elseif ($ref.Category -eq 'StructuredData') {
            $summary.DataFiles += $ref
        } else {
            $summary.TextFiles += $ref
        }
    }
    
    return $summary
}

function Show-ReferenceSummary {
    <#
    .SYNOPSIS
        Displays a formatted summary of references
    #>
    $summary = Get-ReferenceSummary
    
    Write-Host ""
    Write-Host "  Reference Summary" -ForegroundColor Cyan
    Write-Host "  ─────────────────" -ForegroundColor DarkGray
    Write-Host ""
    
    if ($summary.TotalFiles -eq 0) {
        Write-Host "  No reference files found." -ForegroundColor Yellow
        return
    }
    
    Write-Host "  Directories: $($summary.Directories)" -ForegroundColor White
    Write-Host "  Total Files: $($summary.TotalFiles)" -ForegroundColor White
    Write-Host ""
    
    if ($summary.ByCategory.Count -gt 0) {
        Write-Host "  By Category:" -ForegroundColor Gray
        foreach ($cat in $summary.ByCategory.Keys) {
            $count = $summary.ByCategory[$cat]
            $icon = switch ($cat) {
                'Image' { '🖼️' }
                'StructuredData' { '📊' }
                'Code' { '💻' }
                default { '📄' }
            }
            Write-Host "    $icon $cat : $count" -ForegroundColor White
        }
    }
    
    Write-Host ""
}
