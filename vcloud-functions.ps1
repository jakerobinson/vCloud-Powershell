#REQUIRES -Version 2.0

#####################################################################
# Powershell vCloud API functions
# Author: Jake Robinson
# Twitter: @jakerobinson
#####################################################################



 ###################################
# Connect-vCloud
# TODO: give option for PScredential and convert to networkCredential
# TODO: Multiple ORGs (ie The 'system' org)
 ###################################
function Connect-vCloud
{
    <#
    .SYNOPSIS

    Connects to a system running the vCloud API.

    .DESCRIPTION

    Connect-vCloud communicates directly to the REST based vCloud API to establish a session.

    The session auth token is stored for use by other functions until:
      a. Disconnect-vCloud is called.
      b. The session is idle and times out (30 minutes)
    
    Required parameters are:
      1. The URL of the vCloud API you are connecting to. This URL can typically be found by browsing to https://vCloudAPIserver/api/versions
      2. Your username.
      3. The org you are connecting to. (These functions currently only support connecting to a single org.
      4. Your password.

    .INPUTS

    You can pipe the URI of the API to Connect-vCloud.

    .PARAMETER uri

    The URI of the vCloud API in the form of https://vCloudServer.mydomain.com/api/v1.0/

    .PARAMETER username

    The username of the vCloud org account.

    .PARAMETER org

    The org that you are connecting to.

    .PARAMETER password

    The password of the vCloud org account. 
    
    .PARAMETER credential
    
    Powershell Credential login
    
    .EXAMPLE

    Connect to vCloud API with username and password

    Connect-vCloud -uri "https://vCloudserver.mydomain.com/api/v1.0/" -username sarahconnor -org skynet -password hastalavista

    .EXAMPLE
    
    Connect to vCloud API using Powershell Credential

    Connect-vCloud "https://vCloudserver.mydomain.com/api/v1.0/" -credential (get-credential) -org skynet
    
    


#>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,Position=0)]
        [ValidatePattern('^(https)[\S]+/')]
        [alias("url")]
        [string[]]$uri,
        
        [parameter(Mandatory=$false)]
        [alias("user")]
        [string[]]$username,
        
        [parameter(Mandatory=$false)]
        [string[]]$org,
        
        [parameter(Mandatory=$false)]
        [alias("pass")]
        [string[]]$password,
        
        [parameter(Mandatory=$false)]
        [alias("cred")]
        [System.Management.Automation.PSCredential]$credential
    )
    PROCESS
    {
        # we have to convert the password to plaintext. :(
        try
        {
            $global:connection = new-object PSObject
            add-member -membertype NoteProperty -inputobject $global:connection -name "connectedTo" -value $uri
        
            $request = [System.Net.HttpWebRequest]::Create("$($global:connection.connectedto)login")
            if ($credential)
            {
                #[System.Net.NetworkCredential]$netCred = $credential
                $netcred = $credential.GetNetworkCredential()
                if ($org)
                {
                    $request.credentials = new-object System.Net.NetworkCredential("$($netcred.Username)@$($org)",$netcred.Password)    
                }
                else
                {
                    $request.credentials = new-object System.Net.NetworkCredential("$($netcred.Username)@$($netcred.Domain)",$netcred.Password)    
                }
            }
            else
            {
                $request.credentials = new-object System.Net.NetworkCredential("$($username)@$($org)",$password)
            }
            $response = $request.GetResponse()

            add-member -membertype NoteProperty -inputobject $global:connection -name "token" -value $response.headers["x-vCloud-authorization"]
    
            $streamReader = new-object System.IO.StreamReader($response.getResponseStream())
            [xml]$xmldata = $streamreader.ReadToEnd()
            $streamReader.close()
            $response.close()
        
            add-member -membertype NoteProperty -inputobject $global:connection -name "org" -value $xmldata.orglist.org
        }
        catch [Net.WebException]
        {
            return(write-host -ForegroundColor red $_.exception.message)
        }
            write-host -foregroundcolor green "`n`nConnected!"
    }
}

 ######################################################
# Get-vCloudURI
 ######################################################
function Get-vCloudURI
{
    <#
        .SYNOPSIS
        Performs a HTTP GET request to the vCloud API. Returns the response data and the XML content of the response.


        .DESCRIPTION
        Get-vCloudURI does the HTTP GET requests to the vCloud API. It returns the HTTP response and the content of the response.
        
        All other functions requiring HTTP GET requests call Get-vCloudURI
        
        Get-vCloudURI is much like the Get-View function in PowerCLI...


        .INPUTS
        You can pipe a URI to Get-vCloudURI


        .PARAMETER uri
        The URI to perform the GET request.


        .EXAMPLE
        
        Get Raw HTTP and XML data for a vApp:
        
        Get-vCloudURI "https://vCloudserver.mycompany.com/vapi/1.0/vApp/vapp-12345"


    #>


    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [ValidatePattern('^(http|https)')]
        [alias("url")]
        [System.URI]$uri
        
    )
    PROCESS
    {
        
        if($debugvCloud){write-host -foregroundcolor cyan $uri}
        
        $responseObj = new-object PSObject
        try
        {
            $request = [System.Net.WebRequest]::Create($uri);
            $request.Headers.Add("x-vCloud-authorization",$global:connection.token)
            $request.Method="GET"
    
            add-member -membertype NoteProperty -inputobject $responseObj -name "response" -value $request.GetResponse()
    
            $responseStream = $responseObj.response.getResponseStream()
            $streamReader = new-object System.IO.StreamReader($responseStream)
            [string]$result = $streamReader.ReadtoEnd()
            [xml]$xmldata = $result
            add-member -membertype NoteProperty -inputobject $responseObj -name "xmldata" -value $xmldata
        }
        catch [Net.WebException]
        {
            return(write-host -ForegroundColor red $_.exception.message)
        }
        
        return $responseObj
    
        $streamReader.close()
        $responseObj.response.close()
    } 
}
 ######################################################
# Post-vCloudURI
 ######################################################
function Post-vCloudURI
{
    <#
        .SYNOPSIS
        Performs a HTTP Post request to the vCloud API. Returns the response data and the XML content of the response.


        .DESCRIPTION
        Post-vCloudURI does the HTTP Post requests to the vCloud API. It returns the HTTP response and the content of the response.
        
        All other functions requiring HTTP POST requests should call Post-vCloudURI.
        
        HTTP POST functions are commonly used for performing an action against something (eg PowerOff, PowerOn)


        .INPUTS
        You can pipe a URI to Post-vCloudURI


        .PARAMETER uri
        The URI to perform the POST request.


        .EXAMPLE
        
        Powering up a vApp:
        
        Post-vCloudURI "https://vCloudserver.mycompany.com/vapi/1.0/vApp/vapp-12345/power/action/poweron"


    #>
    
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [ValidatePattern('^(http|https)')]
        [alias("url")]
        [System.URI]$uri,
        
        [parameter(Mandatory=$false)]
        [String]$returnString
    )
    PROCESS
    {
    
        if($debugvCloud){write-host -foregroundcolor cyan $uri}
        
        try
        {
            $responseObj = new-object PSObject

            $request = [System.Net.WebRequest]::Create($uri);
            $request.Headers.Add("x-vCloud-authorization",$global:connection.token)
            $request.Method="POST"
            add-member -membertype NoteProperty -inputobject $responseObj -name "response" -value $request.GetResponse()
            
            $responseStream = $responseObj.response.getResponseStream()
            $streamReader = new-object System.IO.StreamReader($responseStream)
        
        if ($returnString)
        {
            $result = $streamReader.ReadtoEnd()
        }
        else
        {
            [xml]$result = $streamReader.ReadtoEnd()
        }
    
        add-member -membertype NoteProperty -inputobject $responseObj -name "xmldata" -value $result
    
        $streamReader.close()
        $responseObj.response.close()
        }
        
        catch [Net.WebException]
        {
            return(write-host -ForegroundColor red $_.exception.message)
        }
        return $responseObj
    }
}

 ###################################################
# Get-vCloudvApp
# TODO: More info about the vApps
# TODO: Multiple vDC support when calling the function by itself
 ###################################################
function Get-vCloudvApp
{
    <#
        .SYNOPSIS
        Get-vCloudvApp lists the vApps within a vDC.


        .DESCRIPTION
        Get-vCloudvApp lists the vApps within an vDC. If no vDC is specified, it lists all vApps within an org.


        .INPUTS
        You can pipe a vDC object to Get-vCloudvApp


        .PARAMETER vdcObject
        vdcObject is a return from get-vCloudvDC


        .EXAMPLE
        Get-vCloudvApp


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [PSObject]$vdcObject,
        
        [parameter(mandatory=$false,Position=0)]
        [String]$name
    )
    PROCESS
    {
        if ($vdcObject)
        {
            if ($name)
            {
                $result = Get-vCloudURI $vdcObject.href | where {$_.name -eq $name}
            }
            else
            {
                $result = Get-vCloudURI $vdcObject.href
            }
        }
        else
        {
            if ($name)
            {
                $result = Get-vCloudvDC | Get-vCloudvApp | where {$_.name -eq $name}
            }
            else
            {
                $result = Get-vCloudvDC | Get-vCloudvApp
            }
            return $result
        }
        $vAppURIs = $result.xmldata.Vdc.ResourceEntities.ResourceEntity | where {$_.type -eq "application/vnd.vmware.vCloud.vApp+xml"} | select name,href
        
        $vAppArray = @()
        ForEach ($vAppURI in $vAppURIs)
        {
            $vApp = Get-vCloudURI $vAppURI.href
            $vAppArray += $vApp.xmldata.vapp
        }
        
        return $vAppArray
    }
}

 ###################################################
# Get-vCloudVM
# TODO: More VM info
 ###################################################
function Get-vCloudVM
{
    <#
        .SYNOPSIS
        Get-vCloudVM lists VMs within an vApp.


        .DESCRIPTION
        Get-vCloudVM lists VMs within an vApp. If there is no input, it lists all VMs within an org.


        .INPUTS vApp
        You can pipe a vApp object to get-vCloudVM


        .PARAMETER vApp
        a vApp object returned from get-vCloudvApp


        .EXAMPLE
        get-vCloudVM


    #>
    
    
    


    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [PSObject]$vappObject,
        
        [parameter(mandatory=$false,Position=0)]
        [PSObject]$name
    )
    PROCESS
    {
        $vmReturn = @()

        if ($vappObject)
        {
            $vmList = @()
            $vmlist = $vappObject | ForEach-Object {$_.children.vm} | ForEach-Object {$_.href} | where {$_} | Get-vCloudURI | Foreach-Object {$_.xmldata.vm}
            return $vmlist
        }
        else
        {
            if ($name)
            {
                $vmList = @()
                Get-vCloudvApp | ForEach-Object {$vmList += ($_.children.vm | where {$_.type -eq "application/vnd.vmware.vCloud.vm+xml"} | where {$_.name -eq $name})}
                foreach ($vm in $vmList)
                {
                    if ($vm.href)
                    {
                        $vmReturn += (Get-vCloudURI $vm.href).xmldata.vm
                    }
                }
                return $vmReturn
            }
            else
            {
                $vmReturn = Get-vCloudvApp | Get-vCloudVM
                return $vmReturn 
            }    
        }
    }
}

 ##########################################
# Get-vCloudvDC
# TODO: More vDC info
 ##########################################
function Get-vCloudvDC
{
    <#
        .SYNOPSIS
        Get-vCloudvDC lists vDCs within an org.


        .DESCRIPTION
        Get-vCloudvDC lists vDCs within an org. Since only connecting to one org is supported at this time, Get-vCloudvDC uses the org URI from the connection variable.


        .INPUTS
        You can piple an org URI to Get-vCloudvDC


        .PARAMETER orgURI
        The URI of the org to list the vDCs


        .EXAMPLE
        Get-vCloudvDC


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [PSObject]$orgURI,
        
        [parameter(mandatory=$false,Position=0)]
        [PSObject]$name
    )
    PROCESS
    {
        if (!$orgURI)
        {
            $orgURI = $global:connection.org.href
        }
        
        $result = get-vCloudURI $orgURI
        if($name)
        {
            $vdcURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vCloud.vdc+xml"} | where {$_.name -eq $name} | select name,href
        }
        else
        {
            $vdcURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vCloud.vdc+xml"} | select name,href
        }
        
        if(!$vdcURI){return}
        
        $vdcList = @()
        foreach ($vdc in $vdcURI)
        {
            $vdcXML = Get-vCloudURI $vdc.href
            $vdcList += $vdcXML.xmldata.vdc
        }
        return $vdcList
    }
}
    
    
    
 #################################################
# Disconnect-vCloud
# TODO: Make Advanced function?
 #################################################
function Disconnect-vCloud()
{
    <#
        .SYNOPSIS
        Disconnect-vCloud kills the session to the vCloud API.


        .DESCRIPTION
        Disconnect-vCloud kills the session to the vCloud API.


        .EXAMPLE
        Disconnect-vCloud


    #>
    
        if ($global:connection)
        {
            $result = Post-vCloudURI "$($global:connection.connectedto)logout" -returnString $true
        
            if ($result.response.Statuscode -eq "OK")
            {
                write-host -foregroundcolor Green "`n`nSuccessfully Logged Out."
            }
            else 
            {
                write-host -foregroundcolor Red "`n`nAn Error Occured when attempting to Disconnect. (Session timed-out?)"
            }
            remove-variable -ErrorAction stop -scope "global" connection
        }
        else {write-host -ForegroundColor red "Already Disconnected."}
}

########################################
# Delete-vCloudURI                     #
########################################
function Delete-vCloudURI
{
    <#
        .SYNOPSIS
        Performs a HTTP DELETE request to the vCloud API. Returns the response data and the XML content of the response.


        .DESCRIPTION
        Delete-vCloudURI does the HTTP DELETE requests to the vCloud API. It returns the HTTP response and the content of the response.
        
        All other functions requiring HTTP DELETE requests call Delete-vCloudURI

        .INPUTS
        You can pipe a URI to Delete-vCloudURI


        .PARAMETER uri
        The URI to perform the Delete request.


        .EXAMPLE
        
        Delete a vApp
        
        Delete-vCloudURI "https://vCloudserver.mycompany.com/vapi/1.0/vApp/vapp-12345"


    #>


    [CmdletBinding(SupportsShouldProcess=$True)]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [ValidatePattern('^(http|https)')]
        [alias("url")]
        [System.URI]$uri
        
    )
    PROCESS
    {
        
        if($debugvCloud){write-host -foregroundcolor cyan $uri}
        
        $responseObj = new-object PSObject
    
        $request = [System.Net.WebRequest]::Create($uri);
        $request.Headers.Add("x-vCloud-authorization",$global:connection.token)
        $request.Method="DELETE"
    
        add-member -membertype NoteProperty -inputobject $responseObj -name "response" -value $request.GetResponse()
    
        $responseStream = $responseObj.response.getResponseStream()
        $streamReader = new-object System.IO.StreamReader($responseStream)
        [string]$result = $streamReader.ReadtoEnd()
        [xml]$xmldata = $result
        add-member -membertype NoteProperty -inputobject $responseObj -name "xmldata" -value $xmldata
    
        return $responseObj
    
        $streamReader.close()
        $responseObj.response.close()
    } 
}

 ##########################################
# Get-vCloudNetwork
#
 ##########################################
function Get-vCloudNetwork
{
    <#
        .SYNOPSIS
        Get-vCloudvDC lists Networks within an org.


        .DESCRIPTION
        Get-vCloudvDC lists Networks within an org.


        .INPUTS
        You can piple an org URI to Get-vCloudNetwork


        .PARAMETER orgURI
        The URI of the org to list the Networks


        .EXAMPLE
        Get-vCloudNetwork


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [alias("org")]
        [PSObject]$orgURI,
        
        [parameter(mandatory=$false,Position=0)]
        [String]$name
    )
    PROCESS
    {
        if (!$orgURI)
        {
            $orgURI = $global:connection.org.href
        }
        
        $result = get-vCloudURI $orgURI
        if ($name)
        {
            $networkURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vcloud.network+xml"} | where {$_.name -eq $name} | select name,href
        }
        else
        {
            $networkURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vcloud.network+xml"} | select name,href
        }
        
        if (!$networkURI){return}
        
        $networkList = @()
        foreach ($network in $networkURI)
        {
            $networkXML = Get-vCloudURI $network.href
            $networkList += $networkXML.xmldata.OrgNetwork
        }
        return $networkList
    }
}

 ##########################################
# Get-vCloudCatalog
#
 ##########################################
function Get-vCloudCatalog
{
    <#
        .SYNOPSIS
        Get-vCloudCatalog lists catalogs within an org.


        .DESCRIPTION
        Get-vCloudCatalog lists catalogs within an org.


        .INPUTS
        You can piple an org URI to Get-vCloudCatalog


        .PARAMETER orgURI
        The URI of the org to list the catalogs


        .EXAMPLE
        Get-vCloudCatalog


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [PSObject]$orgURI,
        
        [parameter(mandatory=$false,Position=0)]
        [PSObject]$name
    )
    PROCESS
    {
        if (!$orgURI)
        {
            $orgURI = $global:connection.org.href
        }

        $result = get-vCloudURI $orgURI
        if ($name)
        {
            $catalogURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vcloud.catalog+xml"} | where {$_.name -eq $name} | select name,href
        }
        else
        {
            $catalogURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vcloud.catalog+xml"} | select name,href
        }
        
        if (!$catalogURI){return}
        
        $catalogList = @()
        foreach ($catalog in $catalogURI)
        {
            $catalogXML = Get-vCloudURI $catalog.href
            $catalogList += $catalogXML.xmldata.Catalog
        }
        return $catalogList
    }
}

 ##########################################
# Get-vCloudOrg
# TODO: list items?
 ##########################################
function Get-vCloudOrg
{
    <#
        .SYNOPSIS
        Get-vCloudOrg gets info about the Org you are connected to.


        .DESCRIPTION
        Get-vCloudOrg gets info about the Org you are connected to. Since only connecting to one org is supported at this time, Get-vCloudOrg uses the org URI from the connection variable.


        .INPUTS
        You can piple an org URI to Get-vCloudOrg


        .PARAMETER orgURI
        The URI of the org.


        .EXAMPLE
        Get-vCloudOrg


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true,Position=0)]
        [PSObject]$orgURI
    )
    PROCESS
    {
        if (!$orgURI)
        {
            $orgURI = $global:connection.org
        }
        
        $orgList = @()
        foreach ($org in $orgURI)
        {
            $orgXML = Get-vCloudURI $org.href
        
            $orgObject = new-object PSObject
            $orgList += $orgXML.xmldata.org
        }
        return $orgList
    }
}


 ##########################################
# PowerOn-vCloudVM
# TODO:
 ##########################################
function PowerOn-vCloudVM
{
    <#
        .SYNOPSIS
        PowerOn-vCloudVM starts a VM.


        .DESCRIPTION
        PowerOn-vCloudVM starts a VM.


        .INPUTS
        You can pipe a vCloudVM object to PowerOn-vCloudVM.


        .PARAMETER vm
        a vcloud VM object


        .EXAMPLE
        Get-vCloudVM "MyVM" | PowerOn-vCloudVM
        
        .EXAMPLE
        $myVM = Get-vCloudVM "MyVM"
        PowerOn-vCloudVM $myVM
    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vm
    )
    PROCESS
    {
        if ($vm)
        {
            $powerOnLink = ($vm.link | where {$_.rel -eq "power:poweron"}).href
            return (Post-vCloudURI $powerOnLink).xmldata.task
        }
    }
}

 ##########################################
# PowerOff-vCloudVM
# TODO:
 ##########################################
function PowerOff-vCloudVM
{
    <#
        .SYNOPSIS
        PowerOff-vCloudVM stops a VM.


        .DESCRIPTION
        PowerOff-vCloudVM stops a VM.


        .INPUTS
        You can pipe a vCloudVM object to PowerOff-vCloudVM.


        .PARAMETER vm
        a vcloud VM object


        .EXAMPLE
        Get-vCloudVM "MyVM" | PowerOff-vCloudVM
        
        .EXAMPLE
        $myVM = Get-vCloudVM "MyVM"
        PowerOff-vCloudVM $myVM
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vm
    )
    PROCESS
    {
        if ($pscmdlet.ShouldProcess($vm.name))
        {
            if ($vm)
            {
                $powerOffLink = ($vm.link | where {$_.rel -eq "power:poweroff"}).href
                return (Post-vCloudURI $powerOffLink).xmldata.task
            }
        }
    }
}


 ##########################################
# Get-vCloudConsole
# TODO:
 ##########################################
function Get-vCloudConsole
{
    <#
        .SYNOPSIS
        Get-vCloudConsole openes the console of a VM running in a vCloud Datacenter


        .DESCRIPTION
        Get-vCloudConsole openes the console of a VM running in a vCloud Datacenter


        .INPUTS
        You can pipe a vCloudVM object to Get-vCloudConsole.


        .PARAMETER vm
        a vcloud VM object


        .EXAMPLE
        Get-vCloudVM "MyVM" | Get-vCloudConsole
        
        .EXAMPLE
        $myVM = Get-vCloudVM "MyVM"
        Get-vCloudConsole $myVM


    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vm
    )
    PROCESS
    {
        if ($vm.status)
        {
            [void] [Reflection.Assembly]::LoadWithPartialName("System.Web")
            $acquireTicketURI = ($vm.link | where {$_.rel -eq "screen:acquireTicket"}).href
            $screenTicket =  (Post-vCloudURI $acquireTicketURI).xmldata.ScreenTicket.InnerText
            # need regex to seperate ticket out
            # $ticketHref.xmldata.ScreenTicket.InnerText | select-string "ticket\=(.*?)$" | fl *
            $server = $screenTicket.split("/")[2]
            $moref = $screenTicket.Split("/")[3].split("\?")[0]
            $unencoded = [System.Web.HttpUtility]::UrlDecode($screenTicket.split("\=")[1])
            if (Test-Path "C:\Program Files (x86)\Common Files\VMware\VMware Remote Console Plug-in\vmware-vmrc.exe")
            {
                $vmrc = "C:\Program Files (x86)\Common Files\VMware\VMware Remote Console Plug-in\vmware-vmrc.exe"
                $vmrcArgs = "-h $($server) -p $($unencoded) -M $($moref)"
                [void] [Diagnostics.Process]::Start($vmrc, $vmrcArgs)
            }
            elseif (Test-Path "C:\Program Files\Common Files\VMware\VMware Remote Console Plug-in\vmware-vmrc.exe")
            {
                $vmrc = "C:\Program Files\Common Files\VMware\VMware Remote Console Plug-in\vmware-vmrc.exe"
                $vmrcArgs = "-h $($server) -p $($unencoded) -M $($moref)"
                [void] [Diagnostics.Process]::Start($vmrc, $vmrcArgs)
            }
            else {throw "VMware Remote Console plugin for IE not installed."}
        }
        else {throw "$($vm.name) not Powered On."}
    }
}

 ##########################################
# PowerOn-vCloudvApp
# TODO:
 ##########################################
function PowerOn-vCloudvApp
{
    <#
        .SYNOPSIS
        PowerOn-vCloudvApp starts a vApp.


        .DESCRIPTION
        PowerOn-vCloudvApp starts a vApp.


        .INPUTS
        You can pipe a vCloudvApp object to PowerOn-vCloudvApp.


        .PARAMETER vApp
        a vcloud vApp object


        .EXAMPLE
        Get-vCloudvApp "MyvApp" | PowerOn-vCloudvApp
        
        .EXAMPLE
        $myvApp = Get-vCloudvApp "MyvApp"
        PowerOn-vCloudvApp $myvApp
    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vApp
    )
    PROCESS
    {
        if ($vApp)
        {
            $powerOnLink = ($vApp.link | where {$_.rel -eq "power:poweron"}).href
            return (Post-vCloudURI $powerOnLink).xmldata.task
        }
    }
}

 ##########################################
# PowerOff-vCloudvApp
# TODO:
 ##########################################
function PowerOff-vCloudvApp
{
    <#
        .SYNOPSIS
        PowerOff-vCloudvApp stops a vApp.


        .DESCRIPTION
        PowerOff-vCloudvApp stops a vApp.


        .INPUTS
        You can pipe a vCloudvApp object to PowerOff-vCloudvApp.


        .PARAMETER vApp
        a vcloud vApp object


        .EXAMPLE
        Get-vCloudvApp "MyvApp" | PowerOff-vCloudvApp
        
        .EXAMPLE
        $myvApp = Get-vCloudvApp "MyvApp"
        PowerOff-vCloudvApp $myvApp
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vApp
    )
    PROCESS
    {
        if ($pscmdlet.ShouldProcess($vApp.name))
        {
            if ($vApp)
            {
                $powerOffLink = ($vApp.link | where {$_.rel -eq "power:poweroff"}).href
                return (Post-vCloudURI $powerOffLink).xmldata.task
            }
        }
    }
}

 ##########################################
# Deploy-vCloudvApp
# TODO:
 ##########################################
function Deploy-vCloudvApp
{
    <#
        .SYNOPSIS
        Deploy-vCloudvApp stops a vApp.


        .DESCRIPTION
        Deploy-vCloudvApp stops a vApp.


        .INPUTS
        You can pipe a vCloudvApp object to Deploy-vCloudvApp.


        .PARAMETER vApp
        a vcloud vApp object


        .EXAMPLE
        Get-vCloudvApp "MyvApp" | Deploy-vCloudvApp
        
        .EXAMPLE
        $myvApp = Get-vCloudvApp "MyvApp"
        Deploy-vCloudvApp $myvApp
    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vApp
    )
    PROCESS
    {
        if ($pscmdlet.ShouldProcess($vApp.name))
        {
            if ($vApp)
            {
                $deployLink = ($vApp.link | where {$_.rel -eq "deploy"}).href
                return (Post-vCloudURI $deployLink).xmldata.task
            }
        }
    }
}

 ##########################################
# Undeploy-vCloudvApp
# TODO:
 ##########################################
function Undeploy-vCloudvApp
{
    <#
        .SYNOPSIS
        Undeploy-vCloudvApp stops a vApp.


        .DESCRIPTION
        Undeploy-vCloudvApp stops a vApp.


        .INPUTS
        You can pipe a vCloudvApp object to Undeploy-vCloudvApp.


        .PARAMETER vApp
        a vcloud vApp object


        .EXAMPLE
        Get-vCloudvApp "MyvApp" | Undeploy-vCloudvApp
        
        .EXAMPLE
        $myvApp = Get-vCloudvApp "MyvApp"
        Undeploy-vCloudvApp $myvApp
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [PSObject]$vApp
    )
    PROCESS
    {
        if ($vApp)
        {
            $deployLink = ($vApp.link | where {$_.rel -eq "undeploy"}).href
            return (Post-vCloudURI $undeployLink).xmldata.task
        }
    }
}

 ##########################################
# Get-vCloudvAppTemplate
#
 ##########################################
function Get-vCloudvAppTemplate
{
    <#
        .SYNOPSIS
        Get-vCloudvAppTemplate lists vAppTemplates within an org.


        .DESCRIPTION
        Get-vCloudvAppTemplate lists vAppTemplates within an org.


        .INPUTS
        You can piple an org URI to Get-vCloudvAppTemplate


        .PARAMETER name
        The name of a vAppTemplate


        .EXAMPLE
        Get-vCloudvAppTemplate
    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [alias("url")]
        [PSObject]$CatalogObj,
        
        [parameter(mandatory=$false,Position=0)]
        [PSObject]$name
    )
    PROCESS
    {
        if (!$CatalogObj)
        {
            $CatalogObj = get-vCloudCatalog
        }
        $templateList = @()
        $templateList += $CatalogObj | 
            ForEach-Object {$_.catalogitems.catalogitem} | 
            ForEach-Object {Get-vCloudURI $_.href} | ForEach-Object {$_.xmldata.Catalogitem.entity} | 
            where {$_.type -eq "application/vnd.vmware.vcloud.vAppTemplate+xml"}
            
        if ($name)
        {
            $return = $templateList | where {$_.name -eq $name}
        }
        else
        {
            $return = $templateList
        }
        return $return
    }
}

 ##########################################
# Get-vCloudMedia
#
 ##########################################
function Get-vCloudMedia
{
    <#
        .SYNOPSIS
        Get-vCloudvDC lists catalogs within an org.


        .DESCRIPTION
        Get-vCloudvDC lists catalogs within an org.


        .INPUTS
        You can piple an org URI to Get-vCloudcatalog


        .PARAMETER orgURI
        The URI of the org to list the catalogs


        .EXAMPLE
        Get-vCloudcatalog
    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true)]
        [alias("url")]
        [PSObject]$CatalogObj,
        
        [parameter(mandatory=$false,Position=0)]
        [PSObject]$name
    )
    PROCESS
    {
        if (!$CatalogObj)
        {
            $CatalogObj = get-vCloudCatalog
        }
        $mediaList = @()
        $mediaList += $CatalogObj | 
            ForEach-Object {$_.catalogitems.catalogitem} | 
            ForEach-Object {Get-vCloudURI $_.href} | ForEach-Object {$_.xmldata.Catalogitem.entity} | 
            where {$_.type -eq "application/vnd.vmware.vcloud.media+xml"}
            
        if ($name)
        {
            $return = $mediaList | where {$_.name -eq $name}
        }
        else
        {
            $return = $mediaList
        }
        return $return
    }
}
