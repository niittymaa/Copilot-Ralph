<#
.SYNOPSIS
    Specification management module for Ralph Loop

.DESCRIPTION
    Provides specification handling functions including:
    - Spec file discovery and filtering
    - Next task retrieval from plan
    - Interactive spec creation (interview and quick modes)
    - Planning requirements checking

.NOTES
    This module is sourced by loop.ps1 and requires:
    - $script:SpecsDir to be defined
    - $script:PlanFile to be defined
    - $script:AgentFiles to be defined
    - Write-Ralph, Invoke-Copilot functions to be available
#>

# ═══════════════════════════════════════════════════════════════
#                    SPEC DISCOVERY
# ═══════════════════════════════════════════════════════════════

function Get-UserSpecs {
    <#
    .SYNOPSIS
        Returns user spec files (excludes templates starting with _)
    .DESCRIPTION
        Discovers all .md files in specs directory that don't start with underscore.
        Template files (like _example.md) are excluded.
        Automatically refreshes SpecsDir from task config if available.
    .OUTPUTS
        Array of FileInfo objects
    #>
    # Refresh SpecsDir from task config to ensure we use the correct location
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
        if ($activeTaskId -and (Get-Command Get-TaskSpecsFolder -ErrorAction SilentlyContinue)) {
            $configuredSpecsDir = Get-TaskSpecsFolder -TaskId $activeTaskId
            if ($configuredSpecsDir) {
                $script:SpecsDir = $configuredSpecsDir
            }
        }
    }
    
    # Handle null SpecsDir (e.g., in dry-run mode)
    if (-not $SpecsDir) { return @() }
    if (-not (Test-Path $SpecsDir)) { return @() }
    
    $allSpecs = Get-ChildItem -Path $SpecsDir -Filter "*.md" -ErrorAction SilentlyContinue
    if (-not $allSpecs) { return @() }
    
    $userSpecs = @($allSpecs | Where-Object { -not $_.Name.StartsWith('_') })
    if (-not $userSpecs) { return @() }
    
    return $userSpecs
}

function Test-HasUserSpecs {
    <#
    .SYNOPSIS
        Tests if any user specs exist
    .OUTPUTS
        Boolean - true if user specs exist
    #>
    $specs = @(Get-UserSpecs)
    return ($specs.Count -gt 0)
}

# ═══════════════════════════════════════════════════════════════
#                    TASK OPERATIONS
# ═══════════════════════════════════════════════════════════════

function Get-NextTask {
    <#
    .SYNOPSIS
        Gets the next pending task from IMPLEMENTATION_PLAN.md
    .DESCRIPTION
        Parses plan file for first unchecked checkbox task
        Automatically respects dry-run mode
    .OUTPUTS
        String - Task description, or $null if no pending tasks
    #>
    # AUTO-DETECT DRY-RUN MODE
    if (Test-DryRunEnabled) {
        return Get-NextTaskDryRun -PlanFile $PlanFile
    }
    
    if (-not (Test-Path $PlanFile)) { return $null }
    
    $content = Get-Content $PlanFile
    foreach ($line in $content) {
        if ($line -match '^\s*-\s*\[\s*\]\s*(.+)$') {
            return $Matches[1].Trim()
        }
    }
    return $null
}

function Test-NeedsPlanning {
    <#
    .SYNOPSIS
        Checks if planning phase is needed
    .DESCRIPTION
        Planning is needed if:
        - No user specs exist
        - Plan exists but has no pending tasks
    .OUTPUTS
        Boolean - true if planning is needed
    #>
    # Check if user specs exist (not templates)
    if (-not (Test-HasUserSpecs)) {
        Write-Ralph "No user specs found in ralph/specs/. Create specifications first." -Type warning
        return $false
    }
    
    $stats = Get-TaskStats
    
    # Need planning if no pending tasks
    return $stats.Pending -eq 0
}

# ═══════════════════════════════════════════════════════════════
#                    SPEC CREATION
# ═══════════════════════════════════════════════════════════════

function Invoke-SpecCreation {
    <#
    .SYNOPSIS
        Interactive spec creation with AI assistance
    .PARAMETER SpecMode
        Creation mode: 'interview' (AI asks questions) or 'quick' (one-shot from description)
    .DESCRIPTION
        Interview mode: AI conducts an interview, asking up to 5 clarifying questions
        Quick mode: User provides single description, AI generates complete spec
    .OUTPUTS
        Boolean - true if spec was successfully created
    #>
    param(
        [ValidateSet('interview', 'quick', 'from-references')]
        [string]$SpecMode = 'interview'
    )
    
    # Log spec creation start
    if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
        Write-LogSpecCreation -Action STARTED -Mode $SpecMode
    }
    
    # Refresh SpecsDir from task config to ensure we use the correct location
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
        if ($activeTaskId -and (Get-Command Get-TaskSpecsFolder -ErrorAction SilentlyContinue)) {
            $configuredSpecsDir = Get-TaskSpecsFolder -TaskId $activeTaskId
            if ($configuredSpecsDir) {
                $script:SpecsDir = $configuredSpecsDir
                if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
                    Write-LogDebug -Message "SpecsDir set to: $configuredSpecsDir" -Context 'SpecCreation'
                }
            }
        }
    }
    
    Write-Ralph "SPEC CREATION MODE [$SpecMode]" -Type header
    
    # DRY-RUN MODE: Simulate spec creation
    if ((Get-Command Test-DryRunEnabled -ErrorAction SilentlyContinue) -and (Test-DryRunEnabled)) {
        Write-Host ""
        Write-Host "  [DRY RUN] Spec creation would begin in '$SpecMode' mode" -ForegroundColor Yellow
        Write-Host ""
        
        if ($SpecMode -eq 'from-references') {
            # Check for references in dry-run mode
            $dryRunRefs = @()
            $dryRunTaskId = $null
            if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
                $dryRunTaskId = Get-ActiveTaskId
            }
            if ($dryRunTaskId -and (Get-Command Get-TaskReferencesFolder -ErrorAction SilentlyContinue)) {
                $refsFolder = Get-TaskReferencesFolder -TaskId $dryRunTaskId
                if ($refsFolder -and (Test-Path $refsFolder)) {
                    $refCount = @(Get-ChildItem -Path $refsFolder -File -ErrorAction SilentlyContinue | 
                                  Where-Object { -not $_.Name.StartsWith('_') }).Count
                } else {
                    $refCount = 0
                }
            } else {
                $refCount = 0
            }
            
            if ($refCount -eq 0) {
                Write-Host "  ⚠ No references configured for this session" -ForegroundColor Yellow
                Write-Host "    Add references first, then use this option" -ForegroundColor DarkGray
                return $false
            }
            
            Write-Host "  From-References mode: Ralph would analyze reference files" -ForegroundColor Cyan
            Write-Host "  Reference sources: $refCount configured" -ForegroundColor Gray
            Write-Host ""
            
            Add-DryRunAction -Type 'AI_Call' -Description "Create spec from references" -Details @{
                ReferenceCount = $refCount
                SpecMode       = 'from-references'
            }
            
            Write-Host "  ⛔ [DRY RUN] AI Call blocked" -ForegroundColor Yellow
            Write-Host "     Would: Analyze reference files and generate specification" -ForegroundColor Gray
            Write-Host ""
        } elseif ($SpecMode -eq 'quick') {
            Write-Host "  Describe what you want to build in one prompt." -ForegroundColor Cyan
            
            $descInput = Show-ArrowTextInput -Prompt "Your description" -Required -AllowBack
            if ($descInput.Type -eq 'back') {
                return $false
            }
            $description = $descInput.Value
            
            if ([string]::IsNullOrWhiteSpace($description)) {
                Write-Ralph "No description provided. Aborting." -Type warning
                return $false
            }
            
            Add-DryRunAction -Type 'AI_Call' -Description "Create spec in quick mode" -Details @{
                Description = $description
                SpecMode    = 'quick'
            }
            
            Write-Host ""
            Write-Host "  ⛔ [DRY RUN] AI Call blocked" -ForegroundColor Yellow
            Write-Host "     Would: Call Copilot to generate spec from description" -ForegroundColor Gray
            Write-Host ""
        } else {
            Write-Host "  Interview mode: Ralph would ask clarifying questions" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  What would you like to build?" -ForegroundColor White
            
            $ideaInput = Show-ArrowTextInput -Prompt "Your idea" -Required -AllowBack
            if ($ideaInput.Type -eq 'back') {
                return $false
            }
            $idea = $ideaInput.Value
            
            if ([string]::IsNullOrWhiteSpace($idea)) {
                Write-Ralph "No idea provided. Aborting." -Type warning
                return $false
            }
            
            Add-DryRunAction -Type 'AI_Call' -Description "Start spec interview" -Details @{
                Idea     = $idea
                SpecMode = 'interview'
            }
            
            Write-Host ""
            Write-Host "  ⛔ [DRY RUN] AI Call blocked" -ForegroundColor Yellow
            Write-Host "     Would: Start AI interview to create specification" -ForegroundColor Gray
            Write-Host ""
        }
        
        Add-DryRunAction -Type 'File_Write' -Description "Write spec file to ralph/specs/" -Details @{
            Directory = $SpecsDir
        }
        
        Write-Host "  ⛔ [DRY RUN] File Write blocked" -ForegroundColor Yellow
        Write-Host "     Would: Create specification file in ralph/specs/" -ForegroundColor Gray
        Write-Host ""
        
        return $true
    }
    
    # Ensure specs directory exists
    if (-not (Test-Path $SpecsDir)) {
        New-Item -ItemType Directory -Path $SpecsDir -Force | Out-Null
        Write-Ralph "Created specs directory: $SpecsDir" -Type info
    }
    
    $agentPath = $AgentFiles.SpecCreator
    if (-not (Test-Path $agentPath)) {
        Write-Ralph "Spec creator agent not found: $agentPath" -Type error
        
        # Attempt automatic repair
        if (Repair-MissingAgentFile -AgentPath $agentPath) {
            # Repair succeeded, continue
        } else {
            return $false
        }
    }
    
    $agentPrompt = Get-AgentPrompt -AgentPath $agentPath
    if (-not $agentPrompt) { return $false }
    
    # Add specs directory context to agent prompt
    $specsPathInstruction = @"

## IMPORTANT: Target Directory

Create all specification files in this directory: $SpecsDir

Do NOT create specs in the project root - use the directory above.
"@
    
    $agentPrompt = $agentPrompt + $specsPathInstruction
    
    # Load references if available (for from-references and interview modes)
    $allRefs = @()
    $referencePrompt = ""
    $activeTaskId = $null
    if (Get-Command Get-ActiveTaskId -ErrorAction SilentlyContinue) {
        $activeTaskId = Get-ActiveTaskId
    }
    
    if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
        Write-LogDebug -Message "Loading references for task: $activeTaskId" -Context 'SpecCreation'
    }
    
    if ($activeTaskId -and (Get-Command Load-SessionReferences -ErrorAction SilentlyContinue)) {
        Load-SessionReferences -TaskId $activeTaskId | Out-Null
    }
    if (Get-Command Get-AllSessionReferences -ErrorAction SilentlyContinue) {
        $allRefs = @(Get-AllSessionReferences)
    }
    
    # Log references loaded
    if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
        Write-LogSpecCreation -Action REFERENCES_LOADED -Mode $SpecMode -ReferenceCount $allRefs.Count
    }
    if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
        foreach ($ref in $allRefs) {
            Write-LogDebug -Message "  Reference: $($ref.Name) ($($ref.Category)) from $($ref.Source)" -Context 'SpecCreation'
        }
    }
    
    if ($allRefs.Count -gt 0 -and (Get-Command Build-ReferenceAnalysisPrompt -ErrorAction SilentlyContinue)) {
        $referencePrompt = Build-ReferenceAnalysisPrompt -References $allRefs
        Write-Ralph "Found $($allRefs.Count) reference file(s) to analyze" -Type info
        
        if (Get-Command Write-LogReference -ErrorAction SilentlyContinue) {
            Write-LogReference -Action ANALYSIS_BUILT -FileCount $allRefs.Count -Details "Prompt size: $($referencePrompt.Length) chars"
        }
    }
    
    if ($SpecMode -eq 'from-references') {
        # FROM-REFERENCES MODE: Build spec directly from reference files
        if ($allRefs.Count -eq 0) {
            Write-Ralph "No references found. Add references first, then use this option." -Type warning
            if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
                Write-LogSpecCreation -Action FAILED -Mode $SpecMode -Details "No references found"
            }
            return $false
        }
        
        Write-Host ""
        Write-Host "  Building specification from reference files..." -ForegroundColor Cyan
        
        # Categorize references for display
        $imageRefs = @($allRefs | Where-Object { $_.IsImage })
        $textRefs = @($allRefs | Where-Object { -not $_.IsImage })
        
        if ($imageRefs.Count -gt 0) {
            Write-Host "  • $($imageRefs.Count) image(s) for UI/UX analysis" -ForegroundColor Gray
        }
        if ($textRefs.Count -gt 0) {
            Write-Host "  • $($textRefs.Count) text/data file(s)" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Log reference categorization
        if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
            Write-LogDebug -Message "References categorized: $($imageRefs.Count) images, $($textRefs.Count) text files" -Context 'SpecCreation'
        }
        
        # Get optional additional context from user
        Write-Host "  (Optional) Add any additional context or requirements:" -ForegroundColor Gray
        Write-Host "  Press ENTER to skip if references are self-explanatory." -ForegroundColor DarkGray
        
        $contextInput = Show-ArrowTextInput -Prompt "Additional context" -AllowBack
        
        # Log user input
        if (Get-Command Write-LogUserAction -ErrorAction SilentlyContinue) {
            if ($contextInput.Type -eq 'back') {
                Write-LogUserAction -Action 'BACK' -Context 'SpecFromReferences' -Details 'User cancelled context input'
            } else {
                $contextSummary = if ([string]::IsNullOrWhiteSpace($contextInput.Value)) { "(empty)" } else { "Provided: $($contextInput.Value.Length) chars" }
                Write-LogUserAction -Action 'INPUT' -Context 'SpecFromReferences' -Value "AdditionalContext=$contextSummary"
            }
        }
        
        if ($contextInput.Type -eq 'back') {
            if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
                Write-LogSpecCreation -Action CANCELLED -Mode $SpecMode -Details "User pressed back during context input"
            }
            return $false
        }
        $additionalContext = $contextInput.Value
        
        # Build prompt for from-references mode
        $fullPrompt = @"
$agentPrompt

## FROM-REFERENCES MODE: Build Spec from Reference Materials

You have been provided with reference materials. Analyze them thoroughly and create a complete specification.

$referencePrompt

## INSTRUCTIONS FOR FROM-REFERENCES MODE

Your task is to:

1. **ANALYZE ALL REFERENCES THOROUGHLY**:
   - For images: Identify UI components, layouts, user flows, and implied functionality
   - For text files: Extract requirements, features, constraints, and technical details
   - For code samples: Identify patterns, libraries, and architectural approaches
   - For data files: Understand data structures and schema requirements

2. **EXTRACT REQUIREMENTS**:
   - List all functional requirements visible/described in references
   - Identify non-functional requirements (performance, security, UX)
   - Note any implied constraints or dependencies

3. **CREATE COMPLETE SPECIFICATION**:
   - Generate a comprehensive spec file covering everything in the references
   - Include acceptance criteria for each feature
   - Do NOT ask questions - everything should be derivable from references
   - If something is ambiguous, make reasonable assumptions and note them

$(if ($additionalContext) { @"
## ADDITIONAL USER CONTEXT

The user provided this additional context:
$additionalContext

Incorporate this into your specification.
"@ })

**CRITICAL**: Do NOT ask any questions. Build the complete specification from the provided references.
"@
    } elseif ($SpecMode -eq 'quick') {
        Write-Host ""
        Write-Host "  Describe what you want to build in one prompt." -ForegroundColor Cyan
        Write-Host "  Ralph will generate a complete specification from your description." -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Example: 'A REST API for user authentication with JWT tokens," -ForegroundColor DarkGray
        Write-Host "           password hashing, and role-based access control'" -ForegroundColor DarkGray
        
        $descInput = Show-ArrowTextInput -Prompt "Your description" -Required -AllowBack
        if ($descInput.Type -eq 'back') {
            return $false
        }
        $description = $descInput.Value
        
        if ([string]::IsNullOrWhiteSpace($description)) {
            Write-Ralph "No description provided. Aborting." -Type warning
            return $false
        }
        
        # Escape special characters for prompt
        $safeDescription = $description -replace '`', '``' -replace '\$', '`$'
        
        # Combine agent prompt with user description for one-shot mode
        # Also include references if available
        $fullPrompt = @"
$agentPrompt

## User Request (One-Shot Mode)

The user has provided this description. Generate a complete specification from it:

$safeDescription

$(if ($referencePrompt) { @"

## REFERENCE MATERIALS

The following references are also available. Use them to enhance the specification:

$referencePrompt
"@ })

Create the spec file immediately without asking questions. Extract all requirements from the description above.
"@
    } else {
        # Interactive interview mode - AI asks questions dynamically
        # BUT: If references exist, analyze them first and only ask about gaps
        Write-Host ""
        Write-Host "  Interactive Interview Mode" -ForegroundColor Cyan
        
        # Check if we have references to work with
        $hasReferences = ($allRefs.Count -gt 0)
        
        if ($hasReferences) {
            Write-Host "  Ralph will analyze your references and only ask about missing details." -ForegroundColor Gray
            Write-Host "  Type 'done' when you've provided enough information." -ForegroundColor Gray
        } else {
            Write-Host "  Ralph will ask you questions to understand what you want to build." -ForegroundColor Gray
            Write-Host "  Type 'done' when you've provided enough information." -ForegroundColor Gray
        }
        
        # Get initial idea
        $ideaInput = Show-ArrowTextInput -Prompt "What do you want to build?" -Required -AllowBack
        if ($ideaInput.Type -eq 'back') {
            return $false
        }
        $initialIdea = $ideaInput.Value
        
        if ([string]::IsNullOrWhiteSpace($initialIdea)) {
            Write-Ralph "No idea provided. Aborting." -Type warning
            return $false
        }
        
        # Build conversation history
        $conversation = @()
        $conversation += "User: $initialIdea"
        
        # Interview loop - AI asks questions, user answers
        $maxQuestions = 5
        $questionCount = 0
        
        while ($questionCount -lt $maxQuestions) {
            $questionCount++
            
            # Build context-aware question prompt
            # If references exist, include them so AI knows what's already defined
            $referenceContext = ""
            if ($hasReferences) {
                $referenceContext = @"

## REFERENCE MATERIALS ALREADY PROVIDED

The user has already provided the following reference materials. DO NOT ask questions about things already covered in these references. Only ask about gaps or ambiguities.

$referencePrompt

## IMPORTANT INTERVIEW RULES

1. **FIRST**: Check if the information is already in the references above
2. **ONLY ASK** about things NOT covered in references
3. If references fully describe the feature, respond with READY_TO_CREATE
4. Don't ask about UI details if mockups/images are provided
5. Don't ask about data structures if they're shown in references
6. Focus questions on: business logic, edge cases, or unclear requirements

"@
            }
            
            # Ask AI for next question based on conversation so far
            $questionPrompt = @"
You are helping create a software specification. Based on the conversation and any reference materials, ask ONE focused clarifying question to better understand the requirements. Keep questions short and specific.
$referenceContext
Conversation so far:
$($conversation -join "`n")

If you have enough information to create a good specification (especially considering any reference materials provided), respond with exactly: READY_TO_CREATE

Otherwise, ask your next question (just the question, no preamble). DO NOT ask about things already shown/described in reference materials:
"@
            
            Write-Ralph "Thinking..." -Type info
            $questionResult = Invoke-Copilot -Prompt $questionPrompt
            Update-CopilotStats -Result $questionResult -Phase 'SpecCreation'
            
            if (-not $questionResult.Success) {
                Write-Ralph "Failed to get question from AI" -Type warning
                break
            }
            
            $aiResponse = $questionResult.Output.Trim()
            
            # Check if AI has enough info
            if ($aiResponse -match 'READY_TO_CREATE') {
                Write-Host ""
                Write-Host "  Ralph has enough information to create your specification." -ForegroundColor Green
                break
            }
            
            # Display AI's question
            Write-Host ""
            Write-Host "  Ralph: $aiResponse" -ForegroundColor Cyan
            
            # Get user's answer with ESC support
            $answerInput = Show-ArrowTextInput -Prompt "You" -AllowBack
            if ($answerInput.Type -eq 'back') {
                Write-Host ""
                Write-Host "  Proceeding to create specification..." -ForegroundColor Gray
                break
            }
            $userAnswer = $answerInput.Value
            
            # Check for done signal
            if ($userAnswer -match '^done$' -or $userAnswer -match '^q$' -or [string]::IsNullOrWhiteSpace($userAnswer)) {
                Write-Host ""
                Write-Host "  Proceeding to create specification..." -ForegroundColor Gray
                break
            }
            
            # Add to conversation
            $conversation += "Ralph: $aiResponse"
            $conversation += "User: $userAnswer"
        }
        
        # Escape special characters in conversation
        $safeConversation = ($conversation -join "`n") -replace '`', '``' -replace '\$', '`$'
        
        # Build full prompt including references if available
        $fullPrompt = @"
$agentPrompt

## User Request (Interview Summary)

The user has described what they want to build through this conversation:

$safeConversation

$(if ($hasReferences) { @"

## REFERENCE MATERIALS

The following reference materials have been provided. Use them along with the conversation to create a complete specification:

$referencePrompt

## IMPORTANT

Combine information from BOTH the conversation AND the reference materials to create the most complete specification possible.
"@ })

Create the spec file immediately. Use all information from the conversation$(if ($hasReferences) { " and references" }) above.
"@
    }
    
    # Log prompt built
    $promptLength = $fullPrompt.Length
    if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
        Write-LogSpecCreation -Action PROMPT_BUILT -Mode $SpecMode -PromptLength $promptLength -Details "SpecsDir: $SpecsDir"
    }
    
    Write-Ralph "Starting spec creation..." -Type info
    
    # Log AI call start
    if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
        Write-LogSpecCreation -Action AI_CALLED -Mode $SpecMode -PromptLength $promptLength
    }
    
    $startTime = Get-Date
    $result = Invoke-Copilot -Prompt $fullPrompt -AllowAllTools
    $duration = ((Get-Date) - $startTime).TotalSeconds
    
    # Log AI call result
    if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
        Write-LogSpecCreation -Action AI_RETURNED -Mode $SpecMode -Details "Duration: $($duration.ToString('F2'))s, Success: $($result.Success)"
    }
    if (Get-Command Write-LogCopilotCall -ErrorAction SilentlyContinue) {
        $action = if ($result.Success) { 'SUCCESS' } elseif ($result.Cancelled) { 'CANCELLED' } else { 'FAILURE' }
        Write-LogCopilotCall -Action $action -Phase 'SpecCreation' -PromptLength $promptLength -Duration $duration -Output $result.Output
    }
    
    Update-CopilotStats -Result $result -Phase 'SpecCreation'
    
    if (-not $result.Success) {
        Write-Ralph "Spec creation failed: $($result.Output)" -Type error
        if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
            Write-LogSpecCreation -Action FAILED -Mode $SpecMode -Details "AI returned failure: $($result.Output)"
        }
        return $false
    }
    
    if ($result.Output -match [regex]::Escape($Signals.SpecCreated)) {
        Write-Ralph "Specification created!" -Type success
    }
    
    # Verify spec was created
    $specs = @(Get-UserSpecs)
    if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
        Write-LogDebug -Message "Checking for specs in: $SpecsDir" -Context 'SpecCreation'
        Write-LogDebug -Message "Found $($specs.Count) spec file(s)" -Context 'SpecCreation'
        foreach ($spec in $specs) {
            Write-LogDebug -Message "  Spec: $($spec.Name)" -Context 'SpecCreation'
        }
    }
    
    if ($specs.Count -gt 0) {
        Write-Ralph "Specs available: $($specs.Count)" -Type success
        if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
            Write-LogSpecCreation -Action COMPLETED -Mode $SpecMode -Details "Created $($specs.Count) spec(s)"
        }
        return $true
    } else {
        Write-Ralph "No spec files found after creation." -Type warning
        if (Get-Command Write-LogSpecCreation -ErrorAction SilentlyContinue) {
            Write-LogSpecCreation -Action FAILED -Mode $SpecMode -Details "AI succeeded but no spec files found in $SpecsDir"
        }
        # Log the AI output for debugging
        if (Get-Command Write-LogDebug -ErrorAction SilentlyContinue) {
            $outputPreview = if ($result.Output.Length -gt 500) { $result.Output.Substring(0, 500) + "..." } else { $result.Output }
            Write-LogDebug -Message "AI Output preview: $outputPreview" -Context 'SpecCreation'
        }
        return $false
    }
}
