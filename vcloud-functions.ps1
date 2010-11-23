#REQUIRES -Version 2.0

#####################################################################
# Powershell vCloud API functions
# Version: 0.11
# Author: Jake Robinson
# Don't blame me if you never use the vCD web interface again...
#####################################################################



# global object for storing session token, and other junk
$global:connection = new-object PSObject



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

    Don't forget the trailing /. I'll work in some validation later.

    .PARAMETER username

    The username of the vCloud org account. Currently only supports plaintext.

    .PARAMETER org

    The org that you are connecting to. Currently only supports one org. 

    In case you are curious, a vCloud Administrator can connect to the org named "system" but this has not been tested. You have been warned.

    .PARAMETER password

    The password of the vCloud org account. Currently only supports plaintext. (It's on my todo list, so don't write me nasty emails. :D)

    .EXAMPLE

    Connect to vCloud API

    Connect-vCloud -uri "https://vCloudserver.mydomain.com/api/v1.0/" -username sarahconnor -org skynet -password hastalavista

    .EXAMPLE
    
    Connect to vCloud API

    Connect-vCloud "https://vCloudserver.mydomain.com/api/v1.0/" -user sarahconnor -org skynet -pass hastalavista


#>
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,Position=0)]
        [alias("url")]
        [string[]]$uri,
        
        [parameter(Mandatory=$true)]
        [alias("user")]
        [string[]]$username,
        
        [parameter(Mandatory=$true)]
        [string[]]$org,
        
        [parameter(Mandatory=$true)]
        [alias("pass")]
        [string[]]$password
    )
    PROCESS
    {
        add-member -membertype NoteProperty -inputobject $global:connection -name "connectedTo" -value $uri
        
        $request = [System.Net.HttpWebRequest]::Create("$($global:connection.connectedto)login")
        $request.credentials = new-object System.Net.NetworkCredential("$($username)@$($org)",$password)
        $response = $request.GetResponse()

        add-member -membertype NoteProperty -inputobject $global:connection -name "token" -value $response.headers["x-vcloud-authorization"]
    
        $streamReader = new-object System.IO.StreamReader($response.getResponseStream())
        [xml]$xmldata = $streamreader.ReadToEnd()
        $streamReader.close()
        $response.close()
        
        add-member -membertype NoteProperty -inputobject $global:connection -name "org" -value $xmldata.orglist.org
        
        write-host -foregroundcolor green "`n`nConnected!"
    }
}

 ######################################################
# Get-vcloudURI
 ######################################################
function Get-vcloudURI
{
    <#
        .SYNOPSIS
        Performs a HTTP GET request to the vCloud API. Returns the response data and the XML content of the response.


        .DESCRIPTION
        Get-vcloudURI does the HTTP GET requests to the vCloud API. It returns the HTTP response and the content of the response.
        
        All other functions requiring HTTP GET requests call Get-vcloudURI
        
        Get-vcloudURI is much like the Get-View function in PowerCLI...


        .INPUTS
        You can pipe a URI to Get-vcloudURI


        .PARAMETER uri
        The URI to perform the GET request.


        .EXAMPLE
        
        Get Raw HTTP and XML data for a vApp:
        
        Get-vcloudURI "https://vCloudserver.mycompany.com/vapi/1.0/vApp/vapp-12345"


    #>


    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [alias("url")]
        [System.URI]$uri
        
    )
    PROCESS
    {
        
        if($debugvcloud){write-host -foregroundcolor cyan $uri}
        
        $responseObj = new-object PSObject
    
        $request = [System.Net.WebRequest]::Create($uri);
        $request.Headers.Add("x-vcloud-authorization",$global:connection.token)
        $request.Method="GET"
    
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
 ######################################################
# Post-vcloudURI
 ######################################################
function Post-vcloudURI
{
    <#
        .SYNOPSIS
        Performs a HTTP Post request to the vCloud API. Returns the response data and the XML content of the response.


        .DESCRIPTION
        Post-vcloudURI does the HTTP Post requests to the vCloud API. It returns the HTTP response and the content of the response.
        
        All other functions requiring HTTP POST requests should call Post-vcloudURI.
        
        HTTP POST functions are commonly used for performing an action against something (eg PowerOff, PowerOn)


        .INPUTS
        You can pipe a URI to Post-vcloudURI


        .PARAMETER uri
        The URI to perform the POST request.


        .EXAMPLE
        
        Powering up a vApp:
        
        Post-vcloudURI "https://vCloudserver.mycompany.com/vapi/1.0/vApp/vapp-12345/power/action/poweron"


    #>
    
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [alias("url")]
        [System.URI]$uri
    )
    PROCESS
    {
    
        if($debugvcloud){write-host -foregroundcolor cyan $uri}
        
        $responseObj = new-object PSObject
    
        $request = [System.Net.WebRequest]::Create($uri);
        $request.Headers.Add("x-vcloud-authorization",$global:connection.token)
        $request.Method="POST"
    
        add-member -membertype NoteProperty -inputobject $responseObj -name "response" -value $request.GetResponse()
    
        $responseStream = $responseObj.response.getResponseStream()
        $streamReader = new-object System.IO.StreamReader($responseStream)
        [string]$result = $streamReader.ReadtoEnd()
    
        add-member -membertype NoteProperty -inputobject $responseObj -name "xmldata" -value $result
    
        return $responseObj
    
        $streamReader.close()
        $responseObj.response.close()
    }
}

 ###################################################
# Get-vcloudvApp
# TODO: More info about the vApps
# TODO: Multiple vDC support when calling the function by itself
 ###################################################
function Get-vcloudvApp
{
    <#
        .SYNOPSIS
        Get-vcloudvApp lists the vApps within a vDC.


        .DESCRIPTION
        Get-vcloudvApp lists the vApps within an vDC. If no vDC is specified, it lists all vApps within an org.


        .INPUTS
        You can pipe a vDC object to Get-vcloudvApp


        .PARAMETER vdcObject
        vdcObject is a return from get-vcloudvDC


        .EXAMPLE
        Get-vcloudvApp


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true,Position=0)]
        [PSObject]$vdcObject
    )
    PROCESS
    {
        if ($vdcObject)
        {
            $result = Get-vcloudURI $vdcObject.href
        }
        else
        {
            $result = Get-vcloudURI (Get-vcloudvDC).href
        }
        $vAppURIs = $result.xmldata.Vdc.ResourceEntities.ResourceEntity | where {$_.type -eq "application/vnd.vmware.vcloud.vApp+xml"} | select name,href
        
        if ($debugvcloud){write-host -foregroundcolor cyan $vAppURI}
        $vAppArray = @()
        ForEach ($vAppURI in $vAppURIs)
        {
            $vApp = Get-vcloudURI $vAppURI.href
            $vAppObject = New-Object PSObject
            add-member -membertype NoteProperty -inputobject $vappObject -name "Name" -value $vApp.xmldata.vApp.name
            add-member -membertype NoteProperty -inputobject $vappObject -name "description" -value $vApp.xmldata.vApp.description
            add-member -membertype NoteProperty -inputobject $vappObject -name "href" -value $vApp.xmldata.vApp.href
            $vAppArray += $vAppObject
        }
        
        return $vAppArray
    }
}

 ###################################################
# Get-vcloudVM
# TODO: More VM info
 ###################################################
function Get-vcloudVM
{
    <#
        .SYNOPSIS
        Get-vcloudVM lists VMs within an vApp.


        .DESCRIPTION
        Get-vcloudVM lists VMs within an vApp. If there is no input, it lists all VMs within an org.


        .INPUTS vApp
        You can pipe a vApp object to get-vcloudVM


        .PARAMETER vApp
        a vApp object returned from get-vcloudvApp


        .EXAMPLE
        get-vcloudVM


    #>

    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true,Position=0)]
        [PSObject]$vappObject
    )
    PROCESS
    {
        $vmReturn = @()
        if ($debugvcloud){write-host -foregroundcolor cyan $vappObject}
        
        if ($vappObject)
        {
            $result = get-vcloudURI $vappObject.href
            $vmList = $result.xmldata.vapp.children.vm | where {$_.type -eq "application/vnd.vmware.vcloud.vm+xml"} | select name,href
            foreach ($vm in $vmList)
            {
                $vmXML = Get-vcloudURI $vm.href
                $vmObject = New-Object PSObject
                add-member -membertype NoteProperty -inputobject $vmObject -name "Name" -value $vmXML.xmldata.Vm.name
                add-member -membertype NoteProperty -inputobject $vmObject -name "CPUs" -value ($vmXML.xmldata.Vm.VirtualHardwareSection | ForEach-Object {$_.item} | where {$_.href -match "cpu"}).virtualquantity
                add-member -membertype NoteProperty -inputobject $vmObject -name "MemoryMB" -value ($vmXML.xmldata.Vm.VirtualHardwareSection | ForEach-Object {$_.item} | where {$_.href -match "Memory"}).virtualquantity
                add-member -membertype NoteProperty -inputobject $vmObject -name "href" -value $vmXML.xmldata.Vm.href
                $vmReturn += $vmObject
            }
        }
        else
        {
            $vappList = Get-vcloudvApp
            
            foreach ($vapp in $vappList)
            {
                $result = Get-vcloudURI $vapp.href
                if ($debugvcloud){write-host -foregroundcolor cyan $vapp.href}
                $vmList = $result.xmldata.vapp.children.vm | where {$_.type -eq "application/vnd.vmware.vcloud.vm+xml"} | select name,href
                
                foreach ($vm in $vmList)
                {
                    $vmXML = Get-vcloudURI $vm.href
                    $vmObject = New-Object PSObject
                    add-member -membertype NoteProperty -inputobject $vmObject -name "Name" -value $vmXML.xmldata.Vm.name
                    add-member -membertype NoteProperty -inputobject $vmObject -name "CPUs" -value ($vmXML.xmldata.Vm.VirtualHardwareSection | %{$_.item} | where {$_.href -match "cpu"}).virtualquantity
                    add-member -membertype NoteProperty -inputobject $vmObject -name "MemoryMB" -value ($vmXML.xmldata.Vm.VirtualHardwareSection | %{$_.item} | where {$_.href -match "Memory"}).virtualquantity
                    add-member -membertype NoteProperty -inputobject $vmObject -name "href" -value $vmXML.xmldata.Vm.href
                    $vmReturn += $vmObject
                }
            }
        }
        return $vmReturn
    }
}

 ##########################################
# Get-vcloudvDC
# TODO: More vDC info
 ##########################################
function Get-vcloudvDC
{
    <#
        .SYNOPSIS
        Get-vcloudvDC lists vDCs within an org.


        .DESCRIPTION
        Get-vcloudvDC lists vDCs within an org. Since only connecting to one org is supported at this time, Get-vcloudvDC uses the org URI from the connection variable.


        .INPUTS
        You can piple an org URI to Get-vcloudvDC


        .PARAMETER orgURI
        The URI of the org to list the vDCs


        .EXAMPLE
        Get-vcloudvDC


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
            $orgURI = $global:connection.org.href
        }

        if ($debugvcloud){write-host -foregroundcolor cyan $orgURI}
        
        $result = get-vcloudURI $orgURI
        $vdcURI = $result.xmldata.org.link | where {$_.type -eq "application/vnd.vmware.vcloud.vdc+xml"} | select name,href
        $vdcList = @()
        foreach ($vdc in $vdcURI)
        {
            $vdcXML = Get-vcloudURI $vdc.href
        
            $vdcObject = new-object PSObject
            add-member -membertype NoteProperty -inputobject $vdcObject -name "Name" -value $vdcXML.xmldata.vdc.name
            add-member -membertype NoteProperty -inputobject $vdcObject -name "Status" -value $vdcXML.xmldata.vdc.status
            add-member -membertype NoteProperty -inputobject $vdcObject -name "StorageLimitMB" -value $vdcXML.xmldata.vdc.StorageCapacity.Limit
            add-member -membertype NoteProperty -inputobject $vdcObject -name "StorageUsedMB" -value $vdcXML.xmldata.vdc.StorageCapacity.Used
            add-member -membertype NoteProperty -inputobject $vdcObject -name "CPULimitMHz" -value $vdcXML.xmldata.vdc.ComputeCapacity.cpu.Limit
            add-member -membertype NoteProperty -inputobject $vdcObject -name "CPUUsedMHz" -value $vdcXML.xmldata.vdc.ComputeCapacity.cpu.Used
            add-member -membertype NoteProperty -inputobject $vdcObject -name "MemoryLimitMB" -value $vdcXML.xmldata.vdc.ComputeCapacity.Memory.Limit
            add-member -membertype NoteProperty -inputobject $vdcObject -name "MemoryUsedMB" -value $vdcXML.xmldata.vdc.ComputeCapacity.Memory.Used
            add-member -membertype NoteProperty -inputobject $vdcObject -name "href" -value $vdcXML.xmldata.vdc.href
        
            $vdcList += $vdcObject
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
    
        $result = Post-vcloudURI("$($global:connection.connectedto)logout")
        if ($result.response.Statuscode -eq "OK")
        {
            write-host -foregroundcolor Green "`n`nSuccessfully Logged Out."
        }
        else 
        {
            write-host -foregroundcolor Red "`n`nAn Error Occured when attempting to logout. (Already logged out or session time-out.)"
        }
        remove-variable -scope "global" connection
}
