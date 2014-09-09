##-----------------------------------------------------------------------
## Adapted from http://TfsBuildExtensions.codeplex.com/. This source is subject to the Microsoft Permissive License. See http://www.microsoft.com/resources/sharedsource/licensingbasics/sharedsourcelicenses.mspx. All other rights reserved.
##-----------------------------------------------------------------------
# Look for the following pattern in the Build Number '{name}_{number}.{revision}' 
# If found append it to the existing Major and minor version specified on the Assemblies with the AssemblyVersion attribute.
# Updates/Adds the following attributes to all AssemblyInfo.cs files:
#   AssemblyVersion("{current}.{current}.{number}.{revision}")
#   AssemblyFileVersion("{current}.{current}.{number}.{revision}")
#   AssemblyInfoVersion("Built by {BuildNumber}")
#
# For example, if the 'Build number format' build process parameter 
# $(BuildDefinitionName)_$(Year:yy)$(DayOfYear)$(Rev:.r)
# then your build numbers come out like this:
# "Build HelloWorld_14256.1"
# This script would then apply version 14256.1 to your assemblies.
	
# Enable -Verbose option
[CmdletBinding()]
	
# Disable parameter
# Convenience option so you can debug this script or disable it in 
# your build definition without having to remove it from
# the 'Post-build script path' build process parameter.
param([switch]$Disable)
if ($PSBoundParameters.ContainsKey('Disable'))
{
	Write-Verbose "Script disabled; no actions will be taken on the files."
}
	
# Regular expression pattern to find the version in the build number 
# and then apply it to the assemblies
$VersionRegex = "\d+\.\d+\.\d+\.\d+"
$nl = [Environment]::NewLine

# If this script is not running on a build server, remind user to 
# set environment variables so that this script can be debugged
if(-not $Env:TF_BUILD -and -not ($Env:TF_BUILD_SOURCESDIRECTORY -and $Env:TF_BUILD_BUILDNUMBER))
{
	Write-Error "You must set the following environment variables"
	Write-Error "to test this script interactively."
	Write-Host '$Env:TF_BUILD_SOURCESDIRECTORY - For example, enter something like:'
	Write-Host '$Env:TF_BUILD_SOURCESDIRECTORY = "C:\code\FabrikamTFVC\HelloWorld"'
	Write-Host '$Env:TF_BUILD_BUILDNUMBER - For example, enter something like:'
	Write-Host '$Env:TF_BUILD_BUILDNUMBER = "Build HelloWorld_0000.00.00.0"'
	exit 1
}
	
# Make sure path to source code directory is available
if (-not $Env:TF_BUILD_SOURCESDIRECTORY)
{
	Write-Error ("TF_BUILD_SOURCESDIRECTORY environment variable is missing.")
	exit 1
}
elseif (-not (Test-Path $Env:TF_BUILD_SOURCESDIRECTORY))
{
	Write-Error "TF_BUILD_SOURCESDIRECTORY does not exist: $Env:TF_BUILD_SOURCESDIRECTORY"
	exit 1
}
Write-Verbose "TF_BUILD_SOURCESDIRECTORY: $Env:TF_BUILD_SOURCESDIRECTORY"
	
# Make sure there is a build number
if (-not $Env:TF_BUILD_BUILDNUMBER)
{
	Write-Error ("TF_BUILD_BUILDNUMBER environment variable is missing.")
	exit 1
}
Write-Verbose "TF_BUILD_BUILDNUMBER: $Env:TF_BUILD_BUILDNUMBER"
	
# Get and validate the version data
$buildNumberRegex = "^(?<name>.*)_(?<build>\d*)\.(?<revision>\d*)$"
$VersionData = [regex]::matches($Env:TF_BUILD_BUILDNUMBER,$buildNumberRegex)
switch($VersionData.Count)
{
   0		
      { 
         Write-Error "Could not find version number data in TF_BUILD_BUILDNUMBER."
         exit 1
      }
   1 {}
   default 
      { 
         Write-Warning "Found more than instance of version data in TF_BUILD_BUILDNUMBER." 
         Write-Warning "Will assume first instance is version."
      }
}
$BuildVersion = $($VersionData.Groups[2].Value)
$BuildRevision= $($VersionData.Groups[3].Value)
Write-Verbose "BuildVersion: $BuildVersion"
Write-Verbose "BuildRevision: $BuildRevision"
	
# Apply the version to the assembly property files
$files = gci $Env:TF_BUILD_SOURCESDIRECTORY -recurse -include "*Properties*","My Project" | 
	?{ $_.PSIsContainer } | 
	foreach { gci -Path $_.FullName -Recurse -include AssemblyInfo.* }
if($files)
{
	Write-Verbose "Will apply $NewVersion to $($files.count) files."
	
	foreach ($file in $files) {
			
			
		if(-not $Disable)
		{
			$filecontent = Get-Content($file)
            $currentVersion = "0.0.0.0"
            $currentVersionParts = $currentVersion.Split('.')
            # AssemblyVersion handling
            if($filecontent -match "AssemblyVersion\(""(.*)""\)"){
                Write-Verbose "Found AssemblyVersion attribute $($matches[1])"
                
                # Combine the AssemblyVersion and the BuildVersion
                # using format AssemblyVersion[Major].AssemblyVersion[Minor].BuildVersion.BuildRevision
                $assemblyVersionParts = $matches[1].Split('.')
                
                $currentVersionParts[0] = $assemblyVersionParts[0]
                if($assemblyVersionParts.length -gt 1){
                    $currentVersionParts[1]=$assemblyVersionParts[1]
                }

                $currentVersionParts[2]=$BuildVersion
                $currentVersionParts[3]=$BuildReversion
                $currentVersion = $currentVersionParts -join "."
                $fileontent = $filecontent -replace "AssemblyVersion\(""(.*)""\)", "AssemblyVersion(""$currentVersion"")" 
            }
            else{

                $currentVersionParts[2]=$BuildVersion
                $currentVersionParts[3]=$BuildReversion
                $currentVersion = $currentVersionParts -join "."
                $filecontent = $filecontent + $nl + "[assembly: AssemblyVersion(""$currentVersion"")]"
            }		

           
            # AssemblyFileVersion handling
            if($filecontent -match "AssemblyFileVersion"){
                Write-Verbose "Found AssemblyFileVersion attribute"
                $filecontent = $filecontent -replace "AssemblyFileVersion\(.*\)", "AssemblyFileVersion(""$currentVersion"")" 
            }
            else{
                $filecontent = $filecontent + $nl + "[assembly: AssemblyFileVersion(""$currentVersion"")]"
            }
            
            # AssemblyInformationalVersion handling
            if($filecontent -match "AssemblyInformationalVersion"){
                Write-Verbose "Found AssemblyInformationalVersion attribute"
                $filecontent = $filecontent -replace "AssemblyInformationalVersion\(.*\)", "AssemblyInformationalVersion(""Built by $Env:TF_BUILD_BUILDNUMBER"")" 
            }
            else{
                $filecontent = $filecontent + $nl + "[assembly: AssemblyInformationalVersion(""Built by $Env:TF_BUILD_BUILDNUMBER"")]"
            }
            
            

            # Output the updated content to the original file (first make sure it's writeable)
			attrib $file -r
            $filecontent | Out-File $file
			Write-Verbose "$file - version applied"
		}
	}
}
else
{
	Write-Warning "Found no files."
}