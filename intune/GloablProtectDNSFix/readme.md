#  GlobalProtect 5.2.9 DNS Issue and Registry Fix via Intune
This package includes a registry modification to resolve the issue where GlobalProtect does not correctly return DNS queries to Windows devices. Deploy this change to affected devices using Intune to ensure widespread and managed updates. 

 Users on Windows with GlobalProtect (GP) 5.2.9 as well as other possible versions experience intermittent DNS resolution issues, leading to stalled site loading and timeouts. Downgrading to 5.2.8 resolves these issues. A solution PAN engineers recomened is creating a registry entry to change DNS block behavior


Path: `HKEY_LOCAL_MACHINE\SOFTWARE\Palo Alto Networks\GlobalProtect\Settings\DNSBlockMethod`

Type: `DWORD`

Value: `2`


