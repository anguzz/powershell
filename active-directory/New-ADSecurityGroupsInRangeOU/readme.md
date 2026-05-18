
# Create security groups.

This script is used to create a bunch of groups with the same base name but differening numbers. and a start index and stop index can be specified. Useful for testing in AD without having to create groups by hand.


For example say you specify 3-10 the following groups would be created.


```shell
.\New-ADSecurityGroupsInRangeOU.ps1`
  -Prefix "MyGroup " `
  -StartNumber 3 `
  -EndNumber 10 `
  -OuDn "OU=Other,OU=PIZZA,OU=GROUPS,OU=OPUS,DC=EXAMPLE,DC=ORG" `
  -PadWidth 2 `
  -GroupScope Universal
  -DescriptionTemplate "Created in AD -Angel Test"
```

MyGroup 3
MyGroup 4
MyGroup .....
MyGroup 10

