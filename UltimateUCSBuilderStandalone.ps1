#---------------------------------------------------------------------
# Name:         UltimateUCSBuilder.ps1                                   
# Author:       Matthew Oswalt                                         
# Created:      6/10/2013                                             
# Revision:     v0.1 - ALPHA                                                 
# Rev. Date:                                                 
# Description:  A script that starts with a completely blank UCS system and configures it to completion. 
#               This version of the script is very non-modular and static, but that will change in future versions. 
#               My goal with this version was to define a workflow first, then in later versions, make it more efficient on a module-by-module basis.     
#
# Disclaimer: The vast majority of this script is original material, created entirely by me, Matt Oswalt. There are, portions taken from online sources, and although they too 
#             have been changed to meet my needs, I want to make sure I'm giving credit where it is due, which I will do to the best of my ability.
#                                                                               
#---------------------------------------------------------------------

#region Imports and Connection

################################################################################################################################
### IMPORTS AND CONNECTION  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

Import-Module CiscoUcsPs
#Import-Module "$pwDir\CustomFunctions.psm1" -- To be implemented later

#Used with the UCS Emulator available at: http://developer.cisco.com/web/unifiedcomputing/ucsemulatordownload
$ucsm_mgmt_address = "10.12.0.109"
$ucsmUsername = "config"
$ucsmPass = "config"

$ucsmSecPass = ConvertTo-SecureString $ucsmPass -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($ucsmUsername, $ucsmSecPass)

## $csv_file = "config\fpod.csv"
#$config = Read-FPodConfig($csv_file) -- To be implemented later

## Make sure no other connection is active
Disconnect-Ucs

## Connect
Connect-Ucs $ucsm_mgmt_address -Credential $ucsmCreds

#endregion

#region Vars and Constants

################################################################################################################################
### VARS  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

$mgmt_ippoolstart = "10.12.0.150"
$mgmt_ippoolfinish = "10.12.0.254"
$mgmt_ippoolgw = "10.12.0.1"
$organization = "SUBORG_01"
$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

#Set present working directory - to refer to files alongside the script
$scriptpath = $MyInvocation.MyCommand.Path
$pwDir = Split-Path $scriptpath

<#
These vars to be implemented later

$ntp1 = "ntp1.domain.com"
$ntp2 = "ntp2.domain.com"
$snmpcomm = "readonlycommunity"
$snmplocation = "Datacenter Customer Location"
$traphost1 = "10.0.0.100"
$traphost2 = "10.0.0.101"
$fabavsan = "VSAN_4"
$fabavsanid = "4"
$fabbvsan = "VSAN_5"
$fabbvsanid = "5"
$customerportgroup = "Guest_VLAN"
#>

#############################
## Constants               ##
#############################

## Variables from config

<# 
To be implemented later - taken from Netapp's Flexpod Automation Suite

$VAR_UCSM_INFRA_ORG_NAME = $config.Get_Item("<<var_ucsm_infra_org_name>>")
$VAR_UCSM_MAC_POOL_A_START = $config.Get_Item("<<var_ucsm_mac_pool_A_start>>")
$VAR_UCSM_MAC_POOL_B_START = $config.Get_Item("<<var_ucsm_mac_pool_B_start>>")
$MAC_POOL_A_NAME = "MAC_Pool_A"
$MAC_POOL_B_NAME = "MAC_Pool_B"
$NUMBER_OF_MAC_ADDRS = 33
$WWNN_POOL_NAME = "WWNNPool"
$WWNN_POOL_START = "20:00:00:25:B5:00:00:00"
$WWNN_POOL_END = "20:00:00:25:B5:00:00:20"
$WWPN_POOL_A_NAME = "WWPN_Pool_A"
$WWPN_POOL_B_NAME = "WWPN_Pool_B"
$WWPN_POOL_A_START = "20:00:00:25:B5:00:0A:00"
$WWPN_POOL_A_END = "20:00:00:25:B5:00:0A:3F"
$WWPN_POOL_B_START = "20:00:00:25:B5:00:0B:00"
$WWPN_POOL_B_END = "20:00:00:25:B5:00:0B:3F"
$VSAN_A_NAME = "VSAN_A"
$VSAN_B_NAME = "VSAN_B"
$NCP_NAME = "Net_Ctrl_Policy"
$BEST_EFFORT_MTU = 9000
$VNIC_A_NAME = "vNIC_A"
$VNIC_B_NAME = "vNIC_B"
$VNIC_TEMPLATE_A_NAME = "vNIC_Template_A"
$VNIC_TEMPLATE_B_NAME = "vNIC_Template_B"
$VHBA_A_NAME = "vHBA_A"
$VHBA_B_NAME = "vHBA_B"
$VHBA_TEMPLATE_A_NAME = "vHBA_Template_A"
$VHBA_TEMPLATE_B_NAME = "vHBA_Template_B"
$SERVER_POOL_NAME = "Infra-Pool"
$UUID_POOL_NAME = "UUID_Pool"
$UUID_POOL_START = "0000-000000000001"
$UUID_POOL_END = "0000-000000000064"
$FIBER_CHANNEL_SWITCHING_MODE = "end-host"

#If you want to change any of these to constants (to prevent inadvertent changing), use below:
#Set-Variable FIBER_CHANNEL_SWITCHING_MODE -Option ReadOnly

## Array to loop through both switches
$switchIds_a = "A", "B"

## Match vLan names to ids taken from config
$NAMES_TO_VLANS = @{"MGMT-VLAN" = $config.Get_Item("<<var_global_mgmt_vlan_id>>");
                    "NFS-VLAN" = $config.Get_Item("<<var_global_nfs_vlan_id>>");
                    "vMotion-VLAN" = $config.Get_Item("<<var_global_vmotion_vlan_id>>");
                    "Pkt-Ctrl-VLAN" = $config.Get_Item("<<var_global_packet_control_vlan_id>>");
                    "VM-Traffic-VLAN" = $config.Get_Item("<<var_global_vm_traffic_vlan_id>>");
                    "Native-VLAN" = $config.Get_Item("<<var_global_native_vlan_id>>");}

#>

#endregion

#region Infrastructure

<# ### Infrastruction section - work in progress, not ready for this version of the script ###

################################################################################################################################
### INFRASTRUCTURE  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

# This section is based off of a script that I found on the internet, and I can't remember where.
# It will be used in a future version of the script, but rewritten to utilize stored values and loops, rather than static entries on a port-by-port basis.

#Add UCS FI Uplinks on FIA and FIB
add-ucsuplinkport -filancloud A -portid 17 -slotid 1
add-ucsuplinkport -filancloud A -portid 18 -slotid 1
add-ucsuplinkport -filancloud B -portid 17 -slotid 1
add-ucsuplinkport -filancloud B -portid 18 -slotid 1

#Add UCS FI Server Uplinks on FIA and FIB
add-ucsserverport -fabricservercloud A -portid 1 -slotid 1
....
add-ucsserverport -fabricservercloud A -portid 4 -slotid 1
add-ucsserverport -fabricservercloud B -portid 1 -slotid 1
....
add-ucsserverport -fabricservercloud B -portid 4 -slotid 1

#Configre Unified Ports to all be FC
Get-UcsFiSanCloud -Id “A” | Add-UcsFcUplinkPort -ModifyPresent -AdminState “enabled” -SlotId 2 -PortId 1
.......
Get-UcsFiSanCloud -Id “A” | Add-UcsFcUplinkPort -ModifyPresent -AdminState “enabled” -SlotId 2 -PortId 16
Get-UcsFiSanCloud -Id “B” | Add-UcsFcUplinkPort -ModifyPresent -AdminState “enabled” -SlotId 2 -PortId 1
.......
Get-UcsFiSanCloud -Id “B” | Add-UcsFcUplinkPort -ModifyPresent -AdminState “enabled” -SlotId 2 -PortId 16

#CONFIGURE SAN PORTS TO VSAN
get-ucsvsan $fabavsan | add-UcsVsanMemberFcPort -portid 13 -slotid 2 -adminstate enabled -switchid A -modifypresent:$true
...
get-ucsvsan $fabavsan | add-UcsVsanMemberFcPort -portid 16 -slotid 2 -adminstate enabled -switchid A -modifypresent:$true
get-ucsvsan $fabbvsan | add-UcsVsanMemberFcPort -portid 13 -slotid 2 -adminstate enabled -switchid B -modifypresent:$true
...
get-ucsvsan $fabbvsan | add-UcsVsanMemberFcPort -portid 16 -slotid 2 -adminstate enabled -switchid B -modifypresent:$true

#>

#CREATE VLANS
##It is important to give all VLANs names in this part of the script, as the "name" parameter is used later when creating vNICs. Future iterations will not have this requirement.
Get-UcsLanCloud | Add-UcsVlan -Name ESX_MGMT -Id 100
Get-UcsLanCloud | Add-UcsVlan -Name ESX_VMOTION -Id 110
Get-UcsLanCloud | Add-UcsVlan -Name IP_Storage -Id 120

Get-UcsLanCloud | Add-UcsVlan -Name Prod_VM_Traffic -Id 210
Get-UcsLanCloud | Add-UcsVlan -Name NonP_VM_Traffic -Id 220

Get-UcsLanCloud | Add-UcsVlan -Name Prod_Bare_Traffic -Id 230
Get-UcsLanCloud | Add-UcsVlan -Name NonP_Bare_Traffic -Id 240


#CREATE VSANS
Get-UcsFiSanCloud -Id A | Add-UcsVsan -Name VSAN_PROD_A -Id 2100 -fcoevlan 2100 -zoningstate disabled
Get-UcsFiSanCloud -Id A | Add-UcsVsan -Name VSAN_NONP_A -Id 2110 -fcoevlan 2110 -zoningstate disabled
Get-UcsFiSanCloud -Id B | Add-UcsVsan -Name VSAN_PROD_B -Id 2200 -fcoevlan 2200 -zoningstate disabled
Get-UcsFiSanCloud -Id B | Add-UcsVsan -Name VSAN_NONP_B -Id 2210 -fcoevlan 2210 -zoningstate disabled

$rootOrg = Get-UcsOrg -Level root
$result = Get-UcsOrg -Org $rootOrg -Name $organization
if(!$result) {
    $ourOrg = Add-UcsOrg -Org $rootOrg -Name $organization
} else {
    Write-host "Organization $organization already exists, skipping"
    $ourOrg = $result
}
Clear-Variable $result


#endregion

#region Resource Pools

################################################################################################################################
### RESOURCE POOLS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

#ADD Managment IP Pool Block
add-ucsippoolblock -IpPool "ext-mgmt" -from $mgmt_ippoolstart -to $mgmt_ippoolfinish -defgw $mgmt_ippoolgw -modifypresent:$true

#create UUID pools
$uuidPool = Add-UcsUuidSuffixPool -Org $organization -Name "UUID-ESX-PROD" -AssignmentOrder "sequential" -Descr "Production ESXi" -Prefix derived
Add-UcsUuidSuffixBlock -UuidSuffixPool $uuidPool -From "0000-25B511EE0000" -To "0000-25B511EE00FF"

$uuidPool = Add-UcsUuidSuffixPool -Org $organization -Name "UUID-ESX-NONP" -AssignmentOrder "sequential" -Descr "Production ESXi" -Prefix derived
Add-UcsUuidSuffixBlock -UuidSuffixPool $uuidPool -From "0000-25B511EE1000" -To "0000-25B511EE10FF"

$uuidPool = Add-UcsUuidSuffixPool -Org $organization -Name "UUID-BARE-PROD" -AssignmentOrder "sequential" -Descr "Production ESXi" -Prefix derived
Add-UcsUuidSuffixBlock -UuidSuffixPool $uuidPool -From "0000-25B511BB0000" -To "0000-25B511BB00FF"

$uuidPool = Add-UcsUuidSuffixPool -Org $organization -Name "UUID-BARE-NONP" -AssignmentOrder "sequential" -Descr "Production ESXi" -Prefix derived
Add-UcsUuidSuffixBlock -UuidSuffixPool $uuidPool -From "0000-25B511BB1000" -To "0000-25B511BB10FF"

#create MAC pools
$macPool = Add-UcsMacPool -Org $organization -Name "MAC-ESX-PROD-A" -AssignmentOrder "sequential" -Descr "Production ESXi Fabric A"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:00:00" -To "00:25:B5:11:00:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-BARE-PROD-A" -AssignmentOrder "sequential" -Descr "Production Baremetal Fabric A"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:10:00" -To "00:25:B5:11:10:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-ESX-NONP-A" -AssignmentOrder "sequential" -Descr "Non-Prod ESXi Fabric A"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:20:00" -To "00:25:B5:11:20:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-BARE-NONP-A" -AssignmentOrder "sequential" -Descr "Non-Prod Baremetal Fabric A"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:30:00" -To "00:25:B5:11:30:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-ESX-PROD-B" -AssignmentOrder "sequential" -Descr "Production ESXi Fabric B"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:40:00" -To "00:25:B5:11:40:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-BARE-PROD-B" -AssignmentOrder "sequential" -Descr "Production Baremetal Fabric B"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:50:00" -To "00:25:B5:11:50:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-ESX-NONP-B" -AssignmentOrder "sequential" -Descr "Non-Prod ESXi Fabric B"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:60:00" -To "00:25:B5:11:60:FF"

$macPool = Add-UcsMacPool -Org $organization -Name "MAC-BARE-NONP-B" -AssignmentOrder "sequential" -Descr "Non-Prod Baremetal Fabric B"
Add-UcsMacMemberBlock -MacPool $macPool -From "00:25:B5:11:70:00" -To "00:25:B5:11:70:FF"


#create WWPN pools
$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-ESX-PROD-A" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Production ESXi Fabric A"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:00:00" -To "20:00:00:25:B5:11:00:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-BARE-PROD-A" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Production Baremetal Fabric A"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:10:00" -To "20:00:00:25:B5:11:10:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-ESX-NONP-A" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Non-Prod ESXi Fabric A"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:20:00" -To "20:00:00:25:B5:11:20:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-BARE-NONP-A" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Non-Prod Baremetal Fabric A"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:30:00" -To "20:00:00:25:B5:11:30:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-ESX-PROD-B" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Production ESXi Fabric B"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:40:00" -To "20:00:00:25:B5:11:40:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-BARE-PROD-B" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Production Baremetal Fabric B"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:50:00" -To "20:00:00:25:B5:11:50:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-ESX-NONP-B" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Non-Prod ESXi Fabric B"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:60:00" -To "20:00:00:25:B5:11:60:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWPN-BARE-NONP-B" -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr "Non-Prod Baremetal Fabric B"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:70:00" -To "20:00:00:25:B5:11:70:FF"


#create WWNN pools
$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWNN-ESX-PROD" -AssignmentOrder "sequential" -Purpose "node-wwn-assignment" -Descr "Production ESXi"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:A0:00" -To "20:00:00:25:B5:11:A0:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWNN-BARE-PROD" -AssignmentOrder "sequential" -Purpose "node-wwn-assignment" -Descr "Production Baremetal"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:B0:00" -To "20:00:00:25:B5:11:B0:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWNN-ESX-NONP" -AssignmentOrder "sequential" -Purpose "node-wwn-assignment" -Descr "Non-Prod ESXi"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:C0:00" -To "20:00:00:25:B5:11:C0:FF"

$wwnPool = Add-UcsWwnPool -Org $organization -Name "WWNN-BARE-NONP" -AssignmentOrder "sequential" -Purpose "node-wwn-assignment" -Descr "Non-Prod Baremetal"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From "20:00:00:25:B5:11:D0:00" -To "20:00:00:25:B5:11:D0:FF"


#create server pools
Add-UcsServerPool -Org $organization -Name "B230-POOL" -Descr "B230 Servers (Vmware)"
Add-UcsServerPool -Org $organization -Name "B200-512-POOL" -Descr "B200 M3 Servers (Windows-SQL)"
Add-UcsServerPool -Org $organization -Name "B200-256-POOL" -Descr "B200 M3 Servers (Vmware)"
Add-UcsServerPool -Org $organization -Name "B420-POOL" -Descr "B420 Servers (Windows-SQL)"

#endregion

#region Policies...

################################################################################################################################
### POLICIES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

#Set Chassis Discovery Policy
Get-UcsChassisDiscoveryPolicy | Set-UcsChassisDiscoveryPolicy -Action 4-link -LinkAggregationPref port-channel -Rebalance immediate -Force

#Set Power Control Policy
Get-UcsPowerControlPolicy | Set-UcsPowerControlPolicy -Redundancy grid -Force

#Set MAC Aging Policy
get-ucslancloud | set-ucslancloud -macaging mode-default -force 

#Set Global Power Allocation Policy
#NOTWORKING -  set-ucspowergroup does not modify this... cannot find within PowerTool

#CONFIGURE QOS
get-ucsqosclass platinum | set-ucsqosclass -mtu 1500 -Force -Adminstate disabled
get-ucsqosclass gold | set-ucsqosclass -mtu 1500 -Force -Adminstate disabled
get-ucsqosclass silver | set-ucsqosclass -mtu 9000 -Force -Adminstate enabled
get-ucsqosclass bronze | set-ucsqosclass -mtu 9000 -Force -Adminstate enabled
get-ucsqosclass best-effort | set-ucsqosclass -mtu 1500 -Force -Adminstate enabled

#Configure NTP
#add-ucsntpserver -name $ntp1
#add-ucsntpserver -name $ntp2

#Configure TimeZone
#set-ucstimezone -timezone "America/New_York (Eastern Time)" -Force

#Configure SNMP Community
#set-ucssnmp -community $snmpcomm -syscontact ENOC -syslocation $snmplocation -adminstate enabled -force

#Configure SNMP Traps
#add-ucssnmptrap -hostname $traphost1 -community $snmpcomm -notificationtype traps -port 162 -version v2c
#add-ucssnmptrap -hostname $traphost2 -community $snmpcomm -notificationtype traps -port 162 -version v2c

#Create QOS Policies
Start-UcsTransaction
$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name BE
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "best-effort" -Rate line-rate
Complete-UcsTransaction

Start-UcsTransaction
$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Bronze
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "bronze" -Rate line-rate
Complete-UcsTransaction

Start-UcsTransaction
$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Gold
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "gold" -Rate line-rate
Complete-UcsTransaction

Start-UcsTransaction
$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Platinum
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "platinum" -Rate line-rate
Complete-UcsTransaction

Start-UcsTransaction
$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Silver
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "silver" -Rate line-rate
Complete-UcsTransaction



#Server Pool Qualification Policies and map to Server Pool 
$SPQname = "B200-ODDBALL"
$poolDN = "org-root/org-" + $organization + "/compute-pool-B200-ODDBALL"
$SPQ = Add-UcsServerPoolQualification -Org $organization -Name $SPQname 
$SPQ | Add-UcsCpuQualification -Model "UCS-CPU-E5-2665"
Add-UcsServerPoolPolicy -Org $organization -Name "B200-ODDBALL" -Qualifier $SPQname -PoolDN $poolDN

$SPQname = "B200-512-QUAL"
$poolDN = "org-root/org-" + $organization + "/compute-pool-B200-512-POOL"
$SPQ = Add-UcsServerPoolQualification -Org $organization -Name $SPQname 
$SPQ | Add-UcsCpuQualification -Model "UCS-CPU-E5-2680"
$SPQ | Add-UcsMemoryQualification -Units 32
Add-UcsServerPoolPolicy -Org $organization -Name "B200-512-PLCY" -Qualifier $SPQname -PoolDN $poolDN

$SPQname = "B200-256-QUAL"
$poolDN = "org-root/org-" + $organization + "/compute-pool-B200-256-POOL"
$SPQ = Add-UcsServerPoolQualification -Org $organization -Name $SPQname 
$SPQ | Add-UcsCpuQualification -Model "UCS-CPU-E5-2680"
$SPQ | Add-UcsMemoryQualification -Units 16
Add-UcsServerPoolPolicy -Org $organization -Name "B200-256-PLCY" -Qualifier $SPQname -PoolDN $poolDN

$SPQname = "B420-QUAL"
$poolDN = "org-root/org-" + $organization + "/compute-pool-B420-POOL"
$SPQ = Add-UcsServerPoolQualification -Org $organization -Name $SPQname
$SPQ | Add-UcsCpuQualification -Model "UCS-CPU-E5-4610"
Add-UcsServerPoolPolicy -Org $organization -Name "B420-PLCY" -Qualifier $SPQname -PoolDN $poolDN

$SPQname = "B230-QUAL"
$poolDN = "org-root/org-" + $organization + "/compute-pool-B230-POOL"
$SPQ = Add-UcsServerPoolQualification -Org $organization -Name $SPQname 
$SPQ | Add-UcsCpuQualification -Model "UCS-CPU-E72870"
Add-UcsServerPoolPolicy -Org $organization -Name "B230-PLCY" -Qualifier $SPQname -PoolDN $poolDN

#Create blank host firmware package as a placeholder - must manually configure if you want this to do anything. 
#More functionality in later versions.
Add-UcsFirmwareComputeHostPack -Org $organization -Name HOSTFW_PLCY

<# Need to flush out host firmware package creation here

$host_firm_pack = Add-UcsFirmwareComputeHostPack -Name host_firm_pack -IgnoreCompCheck no
$host_firm_pack | Add-UcsFirmwarePackItem -Type adaptor -HwModel N20-AC0002 -HwVendor "Cisco Systems Inc" -Version '1.4(1i)'
$host_firm_pack | Get-UcsFirmwarePackItem -HwModel N20-AC0002 | Set-UcsFirmwarePackItem -Version '2.0(1t)'

http://www.cisco.com/en/US/docs/unified_computing/ucs/sw/msft_tools/powertools/ucs_powertool_book/ucs_pwrtool_bkl1.html#wp439024

#>

#IMPORTANT - Add UCS Maintenance Policy for user-ack. Need to map all SPs or SPTs to this policy
Add-UcsMaintenancePolicy -Org $organization -Name "MAINT-USER-ACK" -UptimeDisr user-ack


#Add Boot Policies
$bp = Add-UcsBootPolicy -Org $organization -Name "BFS-ESX-PROD" -EnforceVnicName yes
$bp | Add-UcsLsBootVirtualMedia -Access "read-only" -Order "1"
$bootstorage = $bp | Add-UcsLsbootStorage -ModifyPresent -Order "2"
$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "primary" -VnicName "ESX-PROD-A"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "secondary" -VnicName "ESX-PROD-B"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bp = Add-UcsBootPolicy -Org $organization -Name "BFS-ESX-NONP" -EnforceVnicName yes
$bp | Add-UcsLsBootVirtualMedia -Access "read-only" -Order "1"
$bootstorage = $bp | Add-UcsLsbootStorage -ModifyPresent -Order "2"
$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "primary" -VnicName "ESX-NONP-A"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "secondary" -VnicName "ESX-NONP-B"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bp = Add-UcsBootPolicy -Org $organization -Name "BFS-BARE-PROD" -EnforceVnicName yes
$bp | Add-UcsLsBootVirtualMedia -Access "read-only" -Order "1"
$bootstorage = $bp | Add-UcsLsbootStorage -ModifyPresent -Order "2"
$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "primary" -VnicName "BARE-PROD-A"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "secondary" -VnicName "BARE-PROD-B"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bp = Add-UcsBootPolicy -Org $organization -Name "BFS-BARE-NONP" -EnforceVnicName yes
$bp | Add-UcsLsBootVirtualMedia -Access "read-only" -Order "1"
$bootstorage = $bp | Add-UcsLsbootStorage -ModifyPresent -Order "2"
$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "primary" -VnicName "BARE-NONP-A"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "secondary" -VnicName "BARE-NONP-B"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:00:00:00:00:00:00:00"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:00:00:00:00:00:00:00"

#endregion

#region vNIC / vHBA Templates

################################################################################################################################
### vNIC/vHBA TEMPLATES ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

#Right now, this vNIC/vHBA creation process is pretty much garbage. It works, but it is among the ugliest parts of this script. I will be changing things around quite a bit later.

# $allowedVLANs is an array, so you can define a list like this: $allowedVLANs =  310, 312, 320, 314, 316, 318

#create vNIC Templates
$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-MGMT-PROD" -Descr "Production ESXi Management" -IdentPoolName "MAC-ESX-PROD-A" -Mtu 1500 -SwitchId A-B -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs = 100
$nativeVLAN = 100
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-MGMT-NONP" -Descr "Non-Prod ESXi Management" -IdentPoolName "MAC-ESX-NONP-A" -Mtu 1500 -SwitchId A-B -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs = 100
$nativeVLAN = 100
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-IPST-PROD-A" -Descr "Production ESXi IP Storage Fabric A" -IdentPoolName "MAC-ESX-PROD-A" -Mtu 9000 -SwitchId A -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-IPST-NONP-A" -Descr "Non-Prod ESXi IP Storage Fabric A" -IdentPoolName "MAC-ESX-NONP-A" -Mtu 9000 -SwitchId A -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-IPST-PROD-B" -Descr "Production ESXi IP Storage Fabric B" -IdentPoolName "MAC-ESX-PROD-B" -Mtu 9000 -SwitchId B -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}


$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-IPST-NONP-B" -Descr "Non-Prod ESXi IP Storage Fabric B" -IdentPoolName "MAC-ESX-NONP-B" -Mtu 9000 -SwitchId B -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-IPST-PROD-A" -Descr "Production Baremetal IP Storage Fabric A" -IdentPoolName "MAC-BARE-PROD-A" -Mtu 9000 -SwitchId A -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-IPST-NONP-A" -Descr "Non-Prod Baremetal IP Storage Fabric A" -IdentPoolName "MAC-BARE-NONP-A" -Mtu 9000 -SwitchId A -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-IPST-PROD-B" -Descr "Production Baremetal IP Storage Fabric B" -IdentPoolName "MAC-BARE-PROD-B" -Mtu 9000 -SwitchId B -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-IPST-NONP-B" -Descr "Non-Prod Baremetal IP Storage Fabric B" -IdentPoolName "MAC-BARE-NONP-B" -Mtu 9000 -SwitchId B -TemplType "updating-template" -QosPolicyName "Silver" 
$allowedVLANs = 120
$nativeVLAN = 120
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-VMTR-PROD-A" -Descr "Production ESXi VM Traffic Fabric A" -IdentPoolName "MAC-ESX-PROD-A" -Mtu 1500 -SwitchId A -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs =  210
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-VMTR-NONP-A" -Descr "Non-Prod ESXi VM Traffic Fabric A" -IdentPoolName "MAC-ESX-NONP-A" -Mtu 1500 -SwitchId A -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs =  220
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-VMTR-PROD-B" -Descr "Production ESXi VM Traffic Fabric B" -IdentPoolName "MAC-ESX-PROD-B" -Mtu 1500 -SwitchId B -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs =  210
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}


$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-VMTR-NONP-B" -Descr "Non-Prod ESXi VM Traffic Fabric B" -IdentPoolName "MAC-ESX-NONP-B" -Mtu 1500 -SwitchId B -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs =  220
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-VMOT-PROD" -Descr "Production ESXi vMotion" -IdentPoolName "MAC-ESX-PROD-B" -Mtu 9000 -SwitchId B-A -TemplType "updating-template" -QosPolicyName "Bronze" 
$allowedVLANs = 110
$nativeVLAN = 110
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "ESX-VMOT-NONP" -Descr "Non-Prod ESXi vMotion" -IdentPoolName "MAC-ESX-NONP-B" -Mtu 9000 -SwitchId B-A -TemplType "updating-template" -QosPolicyName "Bronze" 
$allowedVLANs = 110
$nativeVLAN = 110
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-PROD-A" -Descr "Production Baremetal Fabric A" -IdentPoolName "MAC-BARE-PROD-A" -Mtu 1500 -SwitchId A -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs = 230
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-NONP-A" -Descr "Non-Prod Baremetal Fabric A" -IdentPoolName "MAC-BARE-NONP-A" -Mtu 1500 -SwitchId A -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs = 240
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}

$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-PROD-B" -Descr "Production Baremetal Fabric B" -IdentPoolName "MAC-BARE-PROD-B" -Mtu 1500 -SwitchId A -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs = 230
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}


$vNicTemplate = Add-UcsVnicTemplate -Org $organization -Name "BARE-NONP-B" -Descr "Non-Prod Baremetal Fabric B" -IdentPoolName "MAC-BARE-NONP-B" -Mtu 1500 -SwitchId A -TemplType "updating-template" -QosPolicyName "BE" 
$allowedVLANs = 240
$nativeVLAN = 0
foreach ($vlan in $allowedVLANs)
{
    if($vlan -eq $nativeVLAN) {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet true
    } else {
        $vlanName = Get-UcsVlan -Id $vlan | select name
        Add-UcsVnicInterface -VnicTemplate $vNicTemplate -name $vlanName.name -DefaultNet false
    }
}


#create vHBA Templates
$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "ESX-PROD-A" -Descr "Production ESXi Fabric A" -IdentPoolName "WWPN-ESX-PROD-A" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2100 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "ESX-NONP-A" -Descr "Non-Prod ESXi Fabric A" -IdentPoolName "WWPN-ESX-NONP-A" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2110 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "ESX-PROD-B" -Descr "Production ESXi Fabric B" -IdentPoolName "WWPN-ESX-PROD-B" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2200 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "ESX-NONP-B" -Descr "Non-Prod ESXi Fabric B" -IdentPoolName "WWPN-ESX-NONP-B" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2210 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "BARE-PROD-A" -Descr "Production Baremetal Fabric A" -IdentPoolName "WWPN-BARE-PROD-A" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2100 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "BARE-NONP-A" -Descr "Non-Prod Baremetal Fabric A" -IdentPoolName "WWPN-BARE-NONP-A" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2110 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "BARE-PROD-B" -Descr "Production Baremetal Fabric B" -IdentPoolName "WWPN-BARE-PROD-B" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2200 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

$vHbaTemplate = Add-UcsVhbaTemplate -Org $organization -Name "BARE-NONP-B" -Descr "Non-Prod Baremetal Fabric B" -IdentPoolName "WWPN-BARE-NONP-B" -SwitchId A -TemplType "updating-template"
$vsanName = Get-UcsVsan -Id 2210 | select name
Add-UcsVhbaInterface -VhbaTemplate $vHbaTemplate -name $vsanName.name

#endregion

#region Service Profiles and Service Profile Templates

################################################################################################################################
### SERVICE PROFILES AND SERVICE PROFILE TEMPLATES  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
################################################################################################################################

#Create SPT basics
$SPName = "BARE-SQL-PROD"
$SPT = Add-UcsServiceProfile `
-Org $organization `
-Name $SPName `
-Descr "Baremetal SQL - Production" `
-ExtIPPoolName "ext-mgmt" `
-ExtIPState "pooled" `
-HostFwPolicyName "HOSTFW-PLCY" `
-IdentPoolName "UUID-BARE-PROD" `
-MaintPolicyName "MAINT-USER-ACK" `
-Type "updating-template"

#Assign SPT to pre-existing server pool
$SPT | Add-UcsServerPoolAssignment -Name "B200-512-POOL" -RestrictMigration "no"

#Assign the appropriate WWNN pool to this SPT
$SPT | Add-UcsVnicFcNode -IdentPoolName "WWNN-BARE-PROD"

#Create a list of vNICs to Assign to this SPT and loop through and assign them
$vNicArray = `
"BARE-PROD-A", `
"BARE-PROD-B", `
"BARE-IPST-PROD-A", `
"BARE-IPST-PROD-B"


foreach ($vNicInstance in $vNicArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVnic -NwTemplName $vNicInstance -Name $vNicInstance -AdaptorProfileName "Windows"
}

#Create a list of vHBAs to Assign to this SPT and loop through and assign them
$vHbaArray = `
"BARE-PROD-A", `
"BARE-PROD-B"

foreach ($vHbaInstance in $vHbaArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVhba -NwTemplName $vHbaInstance -Name $vHbaInstance -AdaptorProfileName "Windows"
}



#Create SPT basics
$SPName = "BARE-SQL-NONP"
$SPT = Add-UcsServiceProfile `
-Org $organization `
-Name $SPName `
-Descr "Baremetal SQL - Non-Prod" `
-ExtIPPoolName "ext-mgmt" `
-ExtIPState "pooled" `
-HostFwPolicyName "HOSTFW-PLCY" `
-IdentPoolName "UUID-BARE-NONP" `
-MaintPolicyName "MAINT-USER-ACK" `
-Type "updating-template"

#Assign SPT to pre-existing server pool
$SPT | Add-UcsServerPoolAssignment -Name "B230-POOL" -RestrictMigration "no"

#Assign the appropriate WWNN pool to this SPT
$SPT | Add-UcsVnicFcNode -IdentPoolName "WWNN-BARE-NONP"

#Create a list of vNICs to Assign to this SPT and loop through and assign them
$vNicArray = `
"BARE-NONP-A", `
"BARE-NONP-B", `
"BARE-IPST-NONP-A", `
"BARE-IPST-NONP-B"

foreach ($vNicInstance in $vNicArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVnic -NwTemplName $vNicInstance -Name $vNicInstance -AdaptorProfileName "Windows"
}

#Create a list of vHBAs to Assign to this SPT and loop through and assign them
$vHbaArray = `
"BARE-NONP-A", `
"BARE-NONP-B"

foreach ($vHbaInstance in $vHbaArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVhba -NwTemplName $vHbaInstance -Name $vHbaInstance -AdaptorProfileName "Windows"
}


#Create SPT basics
$SPName = "SPT-ESX-PROD"
$SPT = Add-UcsServiceProfile `
-Org $organization `
-Name $SPName `
-Descr "ESXi - Production" `
-ExtIPPoolName "ext-mgmt" `
-ExtIPState "pooled" `
-HostFwPolicyName "HOSTFW-PLCY" `
-IdentPoolName "UUID-ESX-PROD" `
-MaintPolicyName "MAINT-USER-ACK" `
-Type "updating-template"

#Assign SPT to pre-existing server pool
$SPT | Add-UcsServerPoolAssignment -Name "B200-256-POOL" -RestrictMigration "no"

#Assign the appropriate WWNN pool to this SPT
$SPT | Add-UcsVnicFcNode -IdentPoolName "WWNN-ESX-PROD"

#Create a list of vNICs to Assign to this SPT and loop through and assign them
$vNicArray = `
"ESX-MGMT-PROD", `
"ESX-IPST-PROD-A", `
"ESX-IPST-PROD-B", `
"ESX-VMTR-PROD-A", `
"ESX-VMTR-PROD-B", `
"ESX-VMOT-PROD"

foreach ($vNicInstance in $vNicArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVnic -NwTemplName $vNicInstance -Name $vNicInstance -AdaptorProfileName "VMWare"
}

#Create a list of vHBAs to Assign to this SPT and loop through and assign them
$vHbaArray = `
"ESX-PROD-A", `
"ESX-PROD-B"

foreach ($vHbaInstance in $vHbaArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVhba -NwTemplName $vHbaInstance -Name $vHbaInstance -AdaptorProfileName "VMWare"
}



#Create SPT basics
$SPName = "SPT-ESX-NONP"
$SPT = Add-UcsServiceProfile `
-Org $organization `
-Name $SPName `
-Descr "ESXi - Non-Prod" `
-ExtIPPoolName "ext-mgmt" `
-ExtIPState "pooled" `
-HostFwPolicyName "HOSTFW-PLCY" `
-IdentPoolName "UUID-ESX-NONP" `
-MaintPolicyName "MAINT-USER-ACK" `
-Type "updating-template"

#Assign SPT to pre-existing server pool
$SPT | Add-UcsServerPoolAssignment -Name "B200-256-POOL" -RestrictMigration "no"

#Assign the appropriate WWNN pool to this SPT
$SPT | Add-UcsVnicFcNode -IdentPoolName "WWNN-ESX-NONP"

#Create a list of vNICs to Assign to this SPT and loop through and assign them
$vNicArray = `
"ESX-MGMT-NONP", `
"ESX-IPST-NONP-A", `
"ESX-IPST-NONP-B", `
"ESX-VMTR-NONP-A", `
"ESX-VMTR-NONP-B", `
"ESX-VMOT-NONP"

foreach ($vNicInstance in $vNicArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVnic -NwTemplName $vNicInstance -Name $vNicInstance -AdaptorProfileName "VMWare"
}

#Create a list of vHBAs to Assign to this SPT and loop through and assign them
$vHbaArray = `
"ESX-NONP-A", `
"ESX-NONP-B"

foreach ($vHbaInstance in $vHbaArray) {
    Get-UcsServiceProfile -Name $SPName | Add-UcsVhba -NwTemplName $vHbaInstance -Name $vHbaInstance -AdaptorProfileName "VMWare"
}


#Generate 2 Service Profiles from each template - THIS IS TERRIBLE AND UGLY AND YOU NEED TO MAKE THIS NOT SUCK
$SPTArray = Get-UcsServiceProfile -Type updating-template | select name
foreach ($SPTname in $SPTArray) {
    $sptNameLength = $SPTname.name.length
    $spName = "SP_" + $SPTname.name.substring(4, $sptNameLength - 4) + "01"
    Add-UcsServiceProfile -Org $organization -SrcTemplName $SPTname.name -Name $spName
    $spName = "SP_" + $SPTname.name.substring(4, $sptNameLength - 4) + "02"
    Add-UcsServiceProfile -Org $organization -SrcTemplName $SPTname.name -Name $spName
}

#endregion

Write-Host "Script completed in: " $Elapsed.Elapsed