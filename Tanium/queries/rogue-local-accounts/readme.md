# Tanium Query - Get Rogue/Nonstandard Local User Accounts
The following saved questions help identify unauthorized or nonstandard local accounts across endpoints. These queries filter out known system/service accounts and highlight unexpected users that may require investigation.

## Query - Servers filtered out
```SQL
Get Computer Name and User Accounts not matches ".*(Administrator|DefaultAccount|Guest|WDAGUtilityAccount|WsiAccount|defaultuser0|defaultuser1).*" 

from all entities with ( any User Accounts not matches ".*(Administrator|DefaultAccount|Guest|WDAGUtilityAccount|WsiAccount|defaultuser0|defaultuser1).*" 

and ( Windows OS Type equals Windows Workstation))
```


## Query - All endpoints
```SQL
Get Computer Name and User Accounts not matches ".*(Administrator|DefaultAccount|Guest|WDAGUtilityAccount|WsiAccount|defaultuser0|defaultuser1).*" 

from all entities with ( any User Accounts not matches ".*(Administrator|DefaultAccount|Guest|WDAGUtilityAccount|WsiAccount|defaultuser0|defaultuser1).*" 

```


## Windows accounts
- `WsiAccount` - Windows system init account for OOBE 
- `defaultuser0` - Windows OOBE template/placeholder user
- `defaultuser1` - Windows OOBE template/placeholder user
- `WDAGUtilityAccount` - Windows Defender Application Guard Utility Account

