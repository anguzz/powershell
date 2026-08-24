Connect-MgGraph -Scopes "Group.Read.All"

Get-MgGroup -All `
    -Filter "groupTypes/any(c:c eq 'DynamicMembership')" `
    -Property "id,displayName,groupTypes,membershipRule,membershipRuleProcessingState" |
    Select-Object DisplayName, Id, MembershipRule, MembershipRuleProcessingState |
    Sort-Object DisplayName |
    Export-Csv ".\DynamicGroups_$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation -Encoding UTF8