Register-PackageSource -Name MyNuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet


#Array de listes des mmodules Powershell requis pour le bon fonctionnement du script
$requiredPSModules =  @(
    "BurntToast"
)

#For Loop qui va Installer/Importer chaque Modules powershell dans l'Array : « $requiredPSModules »
for ($i=0; $i -lt $requiredPSModules.Length; $i++) {
    
    if(-not (Get-Module $requiredPSModules[$i] -ListAvailable)){
        Install-Module $requiredPSModules[$i] -Scope CurrentUser -Force -AllowClobber
    }else{
        Update-Module $requiredPSModules[$i]
    }
    
    Import-Module $requiredPSModules[$i]
}

Function Check-RunAsAdministrator()
{
  #Get current user context
  $CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  
  #Check user is running the script is member of Administrator Group
  if($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
  {
       Write-host "Script is running with Administrator privileges!"
  }
  else
    {
       #Create a new Elevated process to Start PowerShell
       $ElevatedProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
 
       # Specify the current script path and name as a parameter
       $ElevatedProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
 
       #Set the Process to elevated
       $ElevatedProcess.Verb = "runas"
 
       #Start the new elevated process
       [System.Diagnostics.Process]::Start($ElevatedProcess)
 
       #Exit from the current, unelevated, process
       Exit
 
    }
}

Check-RunAsAdministrator

$logFilePath = "C:\Support\UsersDeletionLogs"

[int]$lastWriteDays = 31

Start-Transcript -Path "$logFilePath\event.log"

if (!(Test-Path $logFilePath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $logFilePath
    Write-Host "Le répertoire log n'existe pas, création en cours.."
}

Write-Host "Étape de création du fichier log complétée"


$inactiveComputerUser = @(( Get-ChildItem –Path "C:\Users" -Exclude "localadmin","Public","admin*", "Default" | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-$lastWriteDays))} ) | Select-Object -ExpandProperty Name)


foreach ($user in $inactiveComputerUser) {
      
     try {
        Write-Host "suppression de C:\Users\$user en cours.."
        Remove-Item -Path "C:\Users\$user" -Force -Recurse
     }
     catch {
     Write-Host "Une erreur est survenue lors de la suppression de : C:\Users\$user" 
     Write-Host $_
     }
     

     try {
        Write-Host "suppression du profil $user en cours.."
        Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -eq $user } | Remove-CimInstance
     }
     catch { 
     Write-Host "Une erreur est survenue lors de la suppression du profil $user"
     Write-Host $_
     }

}


$Header = New-BTHeader -Title 'État - Exécution du Script Powershell'
$Button = New-BTButton -Content 'Good !' -Dismiss
$toastLogo = New-BTImage -Source "https://filestore.community.support.microsoft.com/api/images/c12b37db-ce79-4aa6-9c4a-4c0fa3fe3969"
New-BurntToastNotification -Text "Script - Suppression des Vieux Comptes Windows","Séquence de Suppression des profils terminée" -AppLogo $toastLogo -UniqueIdentifier '001' -Header $Header -Button $Button
Write-Host "Séquence de Suppression des profils terminé, voici la liste des profils supprimés (Si applicable) : $inactiveComputerUsers"

Stop-Transcript