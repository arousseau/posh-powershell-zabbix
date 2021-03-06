<#
    .SYNOPSIS 
      Generic Functions for parsing Json to psobjects because convertfrom-json has a 2meg limit. If anyone knows a way around this problem get in touch with me. 
    .EXAMPLE
     none don't bother with this function unless you really need it. 

  #>
  # Loading dependencies for this json parser. The lib that's in play is System.Web.Extensions.dll so if you don't have it on your system you need to add it.
  # TODO: package the lib with the module for now I have it already.
  
	$assemblyload = [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
	$global:javaScriptSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
	$global:javaScriptSerializer.MaxJsonLength = [System.Int32]::MaxValue
	$global:javaScriptSerializer.RecursionLimit = 99
    function ParseItem($jsonItem) {
            if($jsonItem.PSObject.TypeNames -match "Array") {
                    return ParseJsonArray($jsonItem)
            }
            elseif($jsonItem.PSObject.TypeNames -match "Dictionary") {
                    return ParseJsonObject([HashTable]$jsonItem)
            }
            else {
                    return $jsonItem
            }
    }
	<#
    .SYNOPSIS 
      Generic Functions for parsing Json to psobjects because convertfrom-json has a 2meg limit. If anyone knows a way around this problem get in touch with me. 
    .EXAMPLE
     none don't bother with this function unless you really need it. 

  #>
    function ParseJsonObject($jsonObj) {
            $result = New-Object -TypeName PSCustomObject
            foreach ($key in $jsonObj.Keys) {
                    $item = $jsonObj[$key]
                    if ($item) {
                            $parsedItem = ParseItem $item
                    } else {
                            $parsedItem = $null
                    }
                    $result | Add-Member -MemberType NoteProperty -Name $key -Value $parsedItem
            }
            return $result
    }
	<#
    .SYNOPSIS 
      Generic Functions for parsing Json to psobjects because convertfrom-json has a 2meg limit. If anyone knows a way around this problem get in touch with me. 
    .EXAMPLE
     none don't bother with this function unless you really need it. 

  #>
    function ParseJsonArray($jsonArray) {
            $result = @()
            $jsonArray | ForEach-Object {
                    $result += , (ParseItem $_)
            }
            return $result
    }
	<#
    .SYNOPSIS 
      Generic Functions for parsing Json to psobjects because convertfrom-json has a 2meg limit. If anyone knows a way around this problem get in touch with me. 
    .EXAMPLE
     none don't bother with this function unless you really need it. 

  #>
    function ParseJsonString($json) {
            $config = $javaScriptSerializer.DeserializeObject($json)
            return ParseJsonObject($config)
    }

<#
    .SYNOPSIS 
      This cmdlet returns a json to use with the zabbix api 
    .EXAMPLE
     JsonConstructor -method "user.login" -params @{user=$zabbixApiUser;password=$zabbixApiPasswd} 

  #>
function JsonConstructor ($params,$token,$method)
{
	if ($method -eq 'user.login') #Total Hack because you can't give the auth value in an api call with zabbix 2.4 for a login. 
	{
			$objJson = (New-Object PSObject | Add-Member -PassThru NoteProperty jsonrpc '2.0' |
    		Add-Member -PassThru NoteProperty method $method |
   	 		Add-Member -PassThru NoteProperty params $params |
    		Add-Member -PassThru NoteProperty id '1' 
			)
			return $objJson | ConvertTo-Json -Depth 3 
	}
	else
	{
			$objJson = (New-Object PSObject | Add-Member -PassThru NoteProperty jsonrpc '2.0' |
    		Add-Member -PassThru NoteProperty method $method |
   	 		Add-Member -PassThru NoteProperty params $params |
    		Add-Member -PassThru NoteProperty id '2' |
			Add-Member -PassThru NoteProperty auth $token
			)
			return $objJson | ConvertTo-Json -Depth 3
	}
}
<#
    .SYNOPSIS 
      Generic WebRequest function accepts json and zabbix host as a parameter 
    .EXAMPLE
     none

  #>

function WebRequest ($jsonCmd,$zabbixHost) # genereic webrequest method had to do it this way because of SSL errors. 
{
	#// use this code when you have SSL warnings. 
      add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy { 
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certifi$toecate,
            WebRequest request, int certificateProblem) {
           return true;
        }
    }
"@
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
	$request = Invoke-WebRequest -Uri $zabbixHost -Method POST -Body $jsonCmd -ContentType "application/json"
	$response = ParseJsonString $request.content
	return $response
	
}

<#
    .SYNOPSIS 
      This cmdlet returns a valid auth token works with the api version 2.0 > 
    .EXAMPLE
     get-zabbixToken -zabbixApiUser Admin -zabbixApiPasswd Zabbix -zabbixApiURL https://zabbix.mydomain.com.

  #>

Function Get-ZabbixToken ([string]$zabbixApiURL,[string]$zabbixApiUser,[string]$zabbixApiPasswd)
{
			$method = "user.login"
			$params = @{user=$zabbixApiUser;password=$zabbixApiPasswd}
			$objAuth = JsonConstructor -method $method -params $params
    		$result = webRequest $objAuth $zabbixApiURL 
			return $result.result
}

<#
    .SYNOPSIS 
      This Cmdlet returns information about a host in zabbix however you can supply one host or an array of hosts. It equally returns the interfaceID used when creating items on a given host  
    .EXAMPLE
     Get-ZabbixHost -hosts mypc.mydomain.com -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL https://zabbix.mydomain.com.

#>

function Get-ZabbixHosts ($hosts,$token,$zabbixApiURL) 
{
	$method = "host.get"
	$params = @{output = "extend";filter = @{host=@($hosts)};selectInterfaces = "extend";selectItems = "extend";selectTriggers = "extend"; selectParentTemplates = "extend"}
	$objHost = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objHost $zabbixApiURL 
	return $result.result
}

<#
    .SYNOPSIS 
      Not Implemented Yet
    .EXAMPLE
     N/A

#>

function Get-ZabbixGraph()
{
}

<#
    .SYNOPSIS 
      This Cmdlet returns all the items attached to a host in zabbix you can supply an array of host ID's 
    .EXAMPLE
     Get-ZabbixItem -hostids 100112424 -zabbixApiURL  https://zabbix.mydomain.com -token ab5bf1ea28f1ec58f6fbe33a75c1f98c
 
#>

function Get-ZabbixItem ($hostids,$zabbixApiURL,$token)
{
	$method = "item.get"
	$params = @{output = "extend";hostids = @($hostids);sortfiled = "name"; selectItemDiscovery = "extend" }
	$objItem = JsonConstructor -method $method -params $params -token $token
    $result = webRequest $objItem $zabbixApiURL 
	return $result.result
}

<#
    .SYNOPSIS 
      This Cmdlet returns information about a Template it can be an array of templates
    .EXAMPLE
     Get-ZabbixTemplate -TemplateNames MyCustomTemplate -zabbixApiUrl https://my.zabbixinstance.com -token ab5bf1ea28f1ec58f6fbe33a75c1f98c

#>

function Get-ZabbixTemplate ($TemPlateNames,$zabbixApiURL,$token)
{
	$method = "template.get"
	$params = @{output = "extend";selectItems = "extend";selectHosts = "extend";selectTriggers = "extend";selectGroups = "extend" ;filter = @{host = @($TemPlateNames)}}
	$objTemplate = JSONConstructor -method $method -params $params -token $token
	$result = webRequest $objTemplate $zabbixApiURL 
	return $result.result
}

<#
    .SYNOPSIS 
      This Cmdlet Is used to create a new blank template and return it's ID you can also link it to hosts if you like while creating it. 
    .EXAMPLE
     Get-ZabbixHost Set-ZabbixTemplate -TemplateName MyTestTemplate -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL https://my.zabbixinstance.com -description MyCustomDescription -groupids someGroupID

#>

function Set-ZabbixTemplate ($TemplateName,$token,$zabbixApiURL,$description,$groupids) 
{
	$method = "template.create"
	$params = @{host = $TemplateName; description = $description ;groups = @{groupid = $groupids} }
	$objTemplate = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objTemplate $zabbixApiURL 
	return $result.result
}



<#
    .SYNOPSIS 
      This Cmdlet returns information about a Trigger attached to a host/hosts.
    .EXAMPLE
     Get-ZabbixHost -hosts mypc.mydomain.com -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL https://zabbix.mydomain.com.

#>

function Get-ZabbixTrigger ($hostids,$zabbixApiURL,$token)
{
	$method = "trigger.get"
	$params = @{output = "extend"; ;hostids = @($hostids);expandExpression=@{};selectItems = "extend"}
	$objTrigger = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objTrigger $zabbixApiURL 
	return $result.result
}

<#
    .SYNOPSIS 
      This Cmdlet returns information about a host in zabbix however you can supply one host or an array of hosts. 
    .EXAMPLE
     Get-ZabbixHost -hosts mypc.mydomain.com -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL https://zabbix.mydomain.com.

#>

function Set-ZabbixHost()
{
}

<#
    .SYNOPSIS 
      This Cmdlet is used to create an Item in zabbix applicationIDs is optional visit https://www.zabbix.com/documentation/2.4/manual/api/reference/item/object to get more information
    .EXAMPLE
     Set-ZabbixItem -itemName MyItem -key 'key[info]' -hostid 1000001 -type 10 -valuetype 4 -interfaceid 100002 -applicationIDs 609 -delay 30 -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL https://zabbix.mydomain.com.

#>

function Set-ZabbixItem ($itemName,$key,$hostid,$type,$valuetype,$interfaceid,$applicationIDs,$delay,$token,$zabbixApiURL)
{
	$method = "item.create"
	$params = @{name = $itemName ; key_ = $key ; hostid = $hostid ; type = $type ; value_type = $valuetype ; interfaceid = $interfaceid ; application = @($applicationIDs) ; delay = $delay }
	$objItem = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objItem $zabbixApiURL 
	return $result.result
}

<#
    .SYNOPSIS 
      This Cmdlet is used to create a trigger. Normally in json you would escape " with \ but in this case the constructor handles this for you so just specify the expression between '' and you will not have any issues. 
    .EXAMPLE
     Set-ZabbixTrigger -triggerName MyTriggerName -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL  https://zabbix.mydomain.com. -triggerExpression '{host:key.function()}<0'

#>

function Set-ZabbixTrigger($triggerName,$token,$zabbixApiURL,$triggerExpression,[int]$triggerPriority)
{
	$method = "trigger.create"
	$params = @{description = $triggerName ; expression = $triggerExpression; priority = $triggerPriority }
	$objTrigger = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objTrigger $zabbixApiURL 
	return $result.result
}

<#
    .SYNOPSIS 
      This Cmdlet is used to create an Item in zabbix applicationIDs is optional visit https://www.zabbix.com/documentation/2.4/manual/api/reference/item/object to get more information
    .EXAMPLE
     Set-ZabbixItem -itemName MyItem -key 'key[info]' -hostid 1000001 -type 10 -valuetype 4 -interfaceid 100002 -applicationIDs 609 -delay 30 -token ab5bf1ea28f1ec58f6fbe33a75c1f98c -zabbixApiURL https://zabbix.mydomain.com.

#>

function Disable-ZabbixItem ($itemid,$token,$zabbixApiURL)
{
	$method = "item.update"
	$params = @{itemid = $itemid; status = 1 }
	$objItem = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objItem $zabbixApiURL 
	return $result.result
}

function Set-ZabbixItemType ($itemid,$token,$zabbixApiURL,$itemType)
{
	$method = "item.update"
	$params = @{itemid = $itemid; type = $itemType }
	$objItem = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objItem $zabbixApiURL 
	return $result.result
}
function Set-ZabbixGraph ($graphName,$graphWidth,$graphHeight,$graphItems)
{
	$method = "graph.create"
	$params = @{ name = $graphName; width = $graphWidth ; height = $graphHeight ; gitems = @(@{itemid = $itemId }) }
	$objItem = JsonConstructor -method $method -params $params -token $token
	$result = webRequest $objItem $zabbixApiURL 
	return $result.result
}

function Get-ZabbixUser ($userId,$token,$zabbixApiURL)
{
	$method = "user.get"
	$params = @{ userids= "$userId";output= "extend" }
	$objItem = JsonConstructor -method $method -params $params -token $token
	write-output $objItem
	$result = webRequest $objItem $zabbixApiURL 
	return $result.result
}