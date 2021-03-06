$ServerName = "SERVER\production" #SERVERNAME AND INSTANCE, otherwise use Servername only
$path="C:\CodeBase\database-development\" #folder that contains the userdatabase git repository.
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName
$IncludeTypes = @("Tables","StoredProcedures","Views","UserDefinedFunctions", "Triggers", "Users", "Schemas",'Assemblies','Roles') #object you want do backup. 
$ExcludeSchemas = @("sys","Information_Schema")
$ExcludeDbs = @("msdb","model","tempdb")

$so = new-object ('Microsoft.SqlServer.Management.Smo.ScriptingOptions')
$so.AllowSystemObjects = $false;
$so.Default = $true
$so.Indexes= $true
$so.FullTextIndexes = $true
$so.ExtendedProperties= $true
$so.ScriptSchema = $true
$so.SchemaQualify = $true 
$so.ClusteredIndexes = $true
$so.NonClusteredIndexes = $true


$dbs=$serverInstance.Databases

$scrp = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') ($serverInstance)

$lsvrs = $serverInstance.LinkedServers
foreach($lsvr in $lsvrs) 
{
       $masterpath = "$path" + "Master\"
       $lspath = "$path" + "Master\LinkedServers"
       
       if ( !(Test-Path $masterpath))
           {$null=new-item -type directory -name "Master"-path "$path"}
        if ( !(Test-Path $lspath))
           {$null=new-item -type directory -name "Master\LinkedServers"-path "$path"}
                          
            $lsvrname = $lsvr.Name -replace '\s|,|\\|:|<|>|\(|\)|\[|\]|/'
            $filename = "$path" + "Master\LinkedServers\" + "$lsvrname" + ".sql"
            Write-Host $filename 
            $lsvr.Script() | Out-File $filename 
} 
        
foreach ($db in $dbs)
{
       $dbname = "$db".replace("[","").replace("]","")
    
    if ($ExcludeDbs -notcontains $dbname) {
       $dbpath = "$path"+ "\"+"$dbname" + "\"
  
    if ( !(Test-Path $dbpath))
           {$null=new-item -type directory -name "$dbname"-path "$path"}

       foreach ($Type in $IncludeTypes)
       {
         
         $objpath = "$dbpath" + "$Type" + "\"
         
         if ( !(Test-Path $objpath))
           {$null=new-item -type directory -name "$Type"-path "$dbpath"}
              foreach ($objs in $db.$Type)
              {
                     If ($ExcludeSchemas -notcontains $objs.Schema ) 
                      {
                           $ObjName = "$objs".replace("[","").replace("]","")                  
                           $OutFile = "$objpath" + "$ObjName" + ".sql"
                           $dats = $objs.Script($so);
                           if ($dats -ne $null ) {
                           $objs.Script($so)+"GO" | out-File $OutFile
                           }
                      }
              }
       }
       
       if (!(Test-Path -path "$dbpath\ServiceBroker\"))
	   {
	   New-Item "$dbpath\ServiceBroker\" -type directory | out-null
	   }
      $sb = $db.ServiceBroker  
      foreach ($serviceBrokerComponent in @( "MessageTypes", "Contracts",  "Queues", "Routes", "Services", "RemoteServiceBindings"))
	  {
        $sb.($serviceBrokerComponent) | Where-object {$_.IsSystemObject -eq $False -and $_ -ne $null } |  foreach-object {
		$obj = $_
		if (!(Test-Path -path "$dbpath\ServiceBroker\$serviceBrokerComponent\"))
			{
			New-Item "$dbpath\ServiceBroker\$serviceBrokerComponent\" -type directory | out-null
			}
		$objectname = $obj.Name
		$scrp.Options.FileName = "$dbpath\ServiceBroker\$serviceBrokerComponent\$objectname.sql"
		$scrp.Script($obj)
		}
      }  
    }   
}