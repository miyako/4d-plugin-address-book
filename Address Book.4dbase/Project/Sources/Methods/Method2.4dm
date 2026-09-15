//%attributes = {}
If (False:C215)
	AB REMOVE FROM PRIVACY LIST
End if 

ARRAY TEXT:C222($UID; 0)

AB GET LIST(AB People; $UID; AB RecordsAll)

If (False:C215)
	
	READ PICTURE FILE:C678(Get 4D folder:C485(Current resources folder:K5:16)+"octocat-gravatar.png"; $icon)
	
	$success:=AB Set person image($UID{1}; $icon)
	
	$success:=AB Get person image($UID{1}; $icon)
	
End if 
