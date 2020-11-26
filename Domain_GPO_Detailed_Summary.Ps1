Import-Module GroupPolicy
Import-Module ActiveDirectory
$GPOs = Get-GPO -All | Select-Object ID, Path, DisplayName, GPOStatus, WMIFilter, CreationTime, ModificationTime, User, Computer
$GPOsHash = @{}
ForEach ($GPO in $GPOs) {
    $GPOsHash.Add($GPO.Path,$GPO)
}

$gPLinks = @()
$gPLinks += `
 Get-ADObject  -Identity (Get-ADDomain comp.ds).distinguishedName -Properties name, distinguishedName, gPLink, gPOptions, CanonicalName |
 Select-Object name, distinguishedName, gPLink, gPOptions, CanonicalName, @{name='Depth';expression={0}}, @{name='IsSite';expression={$false}}
$gPLinks += `
 Get-ADOrganizationalUnit  -Filter * -Properties name, distinguishedName, gPLink, gPOptions, CanonicalName |
 Select-Object name, distinguishedName, gPLink, gPOptions, CanonicalName, @{name='Depth';expression={($_.distinguishedName -split 'OU=').count - 1}}, @{name='IsSite';expression={$false}}
$gPLinks += `
 Get-ADObject -LDAPFilter '(objectClass=site)' -SearchBase "CN=Sites,$((Get-ADRootDSE).configurationNamingContext)" -SearchScope OneLevel -Properties name, distinguishedName, gPLink, gPOptions, CanonicalName |
 Select-Object name, distinguishedName, gPLink, gPOptions, CanonicalName, @{name='Depth';expression={0}}, @{name='IsSite';expression={$true}}
 $report = @()
ForEach ($SOM in $gPLinks) {
       If ($SOM.gPLink) {
       $gPLinkMetadata = Get-ADReplicationAttributeMetadata  -Object $SOM.distinguishedName -Properties gPLink
        If ($SOM.gPLink.length -gt 1) {
            $links = @($SOM.gPLink -split {$_ -eq '[' -or $_ -eq ']'} | Where-Object {$_})
            For ( $i = $links.count - 1 ; $i -ge 0 ; $i-- ) {
                $GPOData = $links[$i] -split {$_ -eq '/' -or $_ -eq ';'}
                $report += New-Object -TypeName PSCustomObject -Property @{
                    IsSite            = $SOM.IsSite;
                    Depth             = $SOM.Depth;
                    Name              = $SOM.Name;
                    CanonicalName     = $SOM.CanonicalName;
                    DistinguishedName = $SOM.distinguishedName;
                    Path              = $GPOData[2];
                    Precedence        = $links.count - $i
                    GUID              = $GPOsHash[$GPOData[2]].ID;
                    DisplayName       = $GPOsHash[$GPOData[2]].DisplayName;
                    GPOStatus         = $GPOsHash[$GPOData[2]].GPOStatus;
                    WMIFilter         = $GPOsHash[$GPOData[2]].WMIFilter.Name;
                    CreationTime      = $GPOsHash[$GPOData[2]].CreationTime;
                    ModificationTime  = $GPOsHash[$GPOData[2]].ModificationTime;
                    UserVersionDS     = $GPOsHash[$GPOData[2]].User.DSVersion;
                    UserVersionSysvol = $GPOsHash[$GPOData[2]].User.SysvolVersion;
                    UserMatch         = ($GPOsHash[$GPOData[2]].User.DSVersion -eq $GPOsHash[$GPOData[2]].User.SysvolVersion);
                    ComputerVersionDS = $GPOsHash[$GPOData[2]].Computer.DSVersion;
                    ComputerVersionSysvol = $GPOsHash[$GPOData[2]].Computer.SysvolVersion;
                    ComputerMatch     = ($GPOsHash[$GPOData[2]].Computer.DSVersion -eq $GPOsHash[$GPOData[2]].Computer.SysvolVersion);
                    Config            = $GPOData[3];
                    LinkEnabled       = [bool](!([int]$GPOData[3] -band 1));
                    Enforced          = [bool]([int]$GPOData[3] -band 2);
                    BlockInheritance  = [bool]($SOM.gPOptions -band 1)
                    gPLinkVersion     = $gPLinkMetadata.Version
                    gPLinkLastOrigChgTime = $gPLinkMetadata.LastOriginatingChangeTime
                    gPLinkLastOrigChgDirServerId = $gPLinkMetadata.LastOriginatingChangeDirectoryServerIdentity
                    gPLinkLastOrigChgDirServerInvocId = $gPLinkMetadata.LastOriginatingChangeDirectoryServerInvocationId
                } # End Property hash table
            } # End For
        } Else {
            
            $report += New-Object -TypeName PSCustomObject -Property @{
                IsSite            = $SOM.IsSite;
                Depth             = $SOM.Depth;
                Name              = $SOM.Name;
                CanonicalName     = $SOM.CanonicalName;
                DistinguishedName = $SOM.distinguishedName;
                BlockInheritance  = [bool]($SOM.gPOptions -band 1)
                gPLinkVersion     = $gPLinkMetadata.Version
                gPLinkLastOrigChgTime = $gPLinkMetadata.LastOriginatingChangeTime
                gPLinkLastOrigChgDirServerId = $gPLinkMetadata.LastOriginatingChangeDirectoryServerIdentity
                gPLinkLastOrigChgDirServerInvocId = $gPLinkMetadata.LastOriginatingChangeDirectoryServerInvocationId
            }
        } # End If
    } Else {
        
        $report += New-Object -TypeName PSCustomObject -Property @{
            IsSite            = $SOM.IsSite;
            Depth             = $SOM.Depth;
            Name              = $SOM.Name;
            CanonicalName     = $SOM.CanonicalName;
            DistinguishedName = $SOM.distinguishedName;
            BlockInheritance  = [bool]($SOM.gPOptions -band 1)
        }
    } # End If
} # End ForEach

ForEach ($GPO in $GPOsHash.Values) {
    If ($report.GUID -notcontains $GPO.Id) {
        $report += New-Object -TypeName PSCustomObject -Property @{
            IsSite            = $false;
            CanonicalName     = '_GPO_NOT_LINKED_';
            Path              = $GPO.Path;
            GUID              = $GPO.Id
            DisplayName       = $GPO.DisplayName;
            GPOStatus         = $GPO.GPOStatus;
            WMIFilter         = $GPO.WMIFilter.Name;
            CreationTime      = $GPO.CreationTime;
            ModificationTime  = $GPO.ModificationTime;
            UserVersionDS     = $GPO.User.DSVersion;
            UserVersionSysvol = $GPO.User.SysvolVersion;
            UserMatch         = ($GPO.User.DSVersion -eq $GPO.User.SysvolVersion);
            ComputerVersionDS = $GPO.Computer.DSVersion;
            ComputerVersionSysvol = $GPO.Computer.SysvolVersion;
            ComputerMatch     = ($GPO.Computer.DSVersion -eq $GPO.Computer.SysvolVersion);
        }
    }
}
$report |
 Sort-Object IsSite, CanonicalName, Precedence, SOM |
 Select-Object CanonicalName, `
  @{name='SOM';expression={$_.name.PadLeft($_.name.length + ($_.depth * 5),'_')}}, `
  DistinguishedName, BlockInheritance, LinkEnabled, Enforced, Precedence, `
  DisplayName, GPOStatus, WMIFilter, GUID, CreationTime, ModificationTime, `
  UserVersionDS, UserVersionSysvol, UserMatch, ComputerVersionDS, ComputerVersionSysvol, ComputerMatch, Path, `
  gPLinkVersion, gPLinkLastOrigChgTime, gPLinkLastOrigChgDirServerId, gPLinkLastOrigChgDirServerInvocId |  Export-CSV C:\mydata\gPLink_Report_Sorted_Metadata.csv -NoTypeInformation
 
