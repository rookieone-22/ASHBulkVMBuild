
using namespace System.Management.Automation
function Copy-Object ($InputObject) {
    <#
    .SYNOPSIS
    Use the serializer to create an independent copy of an object, useful when using an object as a template
    #>
    [psserializer]::Deserialize(
        [psserializer]::Serialize(
            $InputObject
        )
    )
}

function Format-Json {
    <#
    .SYNOPSIS
        Prettifies JSON output.
    .DESCRIPTION
        Reformats a JSON string so the output looks better than what ConvertTo-Json outputs.
    .PARAMETER Json
        Required: [string] The JSON text to prettify.
    .PARAMETER Minify
        Optional: Returns the json string compressed.
    .PARAMETER Indentation
        Optional: The number of spaces (1..1024) to use for indentation. Defaults to 4.
    .PARAMETER AsArray
        Optional: If set, the output will be in the form of a string array, otherwise a single string is output.
    .EXAMPLE
        $json | ConvertTo-Json  | Format-Json -Indentation 2
    #>
    [CmdletBinding(DefaultParameterSetName = 'Prettify')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Json,

        [Parameter(ParameterSetName = 'Minify')]
        [switch]$Minify,

        [Parameter(ParameterSetName = 'Prettify')]
        [ValidateRange(1, 1024)]
        [int]$Indentation = 4,

        [Parameter(ParameterSetName = 'Prettify')]
        [switch]$AsArray
    )

    if ($PSCmdlet.ParameterSetName -eq 'Minify') {
        return ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100 -Compress
    }

    # If the input JSON text has been created with ConvertTo-Json -Compress
    # then we first need to reconvert it without compression
    if ($Json -notmatch '\r?\n') {
        $Json = ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100
    }

    $indent = 0
    $regexUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

    $result = $Json -split '\r?\n' |
        ForEach-Object {
            # If the line contains a ] or } character, 
            # we need to decrement the indentation level unless it is inside quotes.
            if ($_ -match "[}\]]$regexUnlessQuoted") {
                $indent = [Math]::Max($indent - $Indentation, 0)
            }

            # Replace all colon-space combinations by ": " unless it is inside quotes.
            $line = (' ' * $indent) + ($_.TrimStart() -replace ":\s+$regexUnlessQuoted", ': ')

            # If the line contains a [ or { character, 
            # we need to increment the indentation level unless it is inside quotes.
            if ($_ -match "[\{\[]$regexUnlessQuoted") {
                $indent += $Indentation
            }

            #finally, fix issue where it unicodes single quotes
            $line.Replace('\u0027',"'")
        }

    if ($AsArray) { return $result }
    return $result -Join [Environment]::NewLine
}

function Test-ASHVMSize {
    param (
        [string]$VMSize
    )

$VMSizeList = @"
Basic_A0
Basic_A1 
Basic_A2
Basic_A3
Basic_A4
Standard_A0
Standard_A1
Standard_A2
Standard_A3
Standard_A4
Standard_A5
Standard_A6
Standard_A7
Standard_D1
Standard_D2
Standard_D3
Standard_D4
Standard_D11
Standard_D12
Standard_D13
Standard_D14
Standard_D1_v2
Standard_D2_v2
Standard_D3_v2
Standard_D4_v2
Standard_D5_v2
Standard_D11_v2
Standard_D12_v2
Standard_D13_v2
Standard_D14_v2
Standard_DS1
Standard_DS2
Standard_DS3
Standard_DS4
Standard_DS11
Standard_DS12
Standard_DS13
Standard_DS14
Standard_DS1_v2
Standard_DS2_v2
Standard_DS3_v2
Standard_DS4_v2
Standard_DS5_v2
Standard_DS11_v2
Standard_DS12_v2
Standard_DS13_v2
Standard_DS14_v2
Standard_A1_v2
Standard_A2_v2
Standard_A4_v2
Standard_A8_v2
Standard_A2m_v2
Standard_A4m_v2
Standard_A8m_v2
Standard_F1
Standard_F2
Standard_F4
Standard_F8
Standard_F16
Standard_F1s
Standard_F2s
Standard_F4s
Standard_F8s
Standard_F16s
Standard_F2s_v2
Standard_F4s_v2
Standard_F8s_v2
Standard_F16s_v2
Standard_F32s_v2
Standard_F64s_v2
"@

    $VMSizeArray = $VMSizeList.Split(@("$([char][byte]10)", "$([char][byte]10)","$([char][byte]13)", [StringSplitOptions]::None))
    $result = ($VMSizeArray -contains $VMSize)

    Write-Verbose "Testing VM Size value: $VMSize - Result $result"
    return $result

}

