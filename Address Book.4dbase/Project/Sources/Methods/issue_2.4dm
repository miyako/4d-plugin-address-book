//%attributes = {"invisible":true}
$permisson:=AB Request permisson

ARRAY TEXT:C222($records; 0)

AB QUERY PEOPLE(AB LastName; ""; ""; "宮下"; AB PrefixMatch; $records)

If (Size of array:C274($records)#0)
	$person:=$records{1}
	$Note:=""
	//$result:=AB Get person property($person; AB Note; $Note)
	$Note:="aaa"
	$result:=AB Set person property($person; AB Note; $Note)
End if 