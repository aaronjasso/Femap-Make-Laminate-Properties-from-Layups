Sub Main
	'==================================================
	'Automatically generate properties based on existing layup definitions.
	'
	'User is prompted for a layup selection, and the program will make properties
	'with the same names. Matching IDs will be used unless they are not available,
	'in which case the user will be given the option to skip them, continue with
	'non-matching IDs, or overwrite the existing properties.
	'
	'Copyright 2019 Aaron Jasso
	'
	'Licensed under the Apache License, Version 2.0 (the "License");
	'you may not use this file except in compliance with the License.
	'You may obtain a copy of the License at
	'
	'    http://www.apache.org/licenses/LICENSE-2.0
	'
	'Unless required by applicable law or agreed to in writing, software
	'distributed under the License Is distributed On an "AS IS" BASIS,
	'WITHOUT WARRANTIES Or CONDITIONS OF Any KIND, either express Or implied.
	'See the License For the specific language governing permissions And
	'limitations under the License.
	'
	'Versions:
   '-Initial Release, 7.18.2019
	'==================================================
    Dim App as femap.model
    Set App = feFemap()
    Dim rc As Variant
    Dim i As Long

    '=================================================
	'Make sure at least one layup has been defined
    '=================================================
	Dim layupSet As femap.Set
	Set layupSet = App.feSet

	rc = layupSet.AddAll(FT_LAYUP)

	If layupSet.Count = 0 Then
		MsgBox("No layups found. At least one layup is required." _
		& vbNewLine & "Program terminating.",vbInformation,"Error")
		Exit Sub
	End If

	lblGetLayups:
    '=================================================
	'Prompt user for layups
	'=================================================
	layupSet.clear
	'rc = layupSet.Select(FT_LAYUP,True,"Select Layup(s) to Make Properties")
	rc = layupSet.SelectMultiID(FT_LAYUP,1,"Select Layup(s) to Make Properties")

	If rc = 2 Then
		Exit Sub
	End If

	If layupSet.Count = 0 Then
		MsgBox("You must select at least one layup",vbInformation,"Error")
		GoTo lblGetLayups
	End If

    '=================================================
	'Check corresponding property IDs to see if they're clear. Prompt user for
	'action if they're not
    '=================================================
	Dim iterProp As femap.Prop
	Set iterProp = App.feProp
	Dim propFailSet As femap.Set
	Set propFailSet = App.feSet
	Dim makeConflictProps As Boolean

	makeConflictProps = False

	layupSet.Reset
	While layupSet.Next
		rc = iterProp.Exist(layupSet.CurrentID)
		If rc = -1 Then
			propFailSet.Add(layupSet.CurrentID)
		End If
	Wend

	If propFailSet.Count > 0 Then
		'make array of property conflicts
		ReDim conflicts(propFailSet.Count) As Variant

		i = 0
		propFailSet.Reset
		While propFailSet.Next
			iterProp.Get(propFailSet.CurrentID)
			conflicts(i) = Str(iterProp.ID) & ".." & iterProp.title
			i = i + 1
		Wend

    	'Dim count As Long
    	'Dim listID As Variant
    	'Dim listTITLE As Variant
    	'rc = iterProp.GetTitleIDList(True,0,0,count,listID,listTITLE)

		'Promt user for how to handle conflicts
		Begin Dialog UserDialog 510,364,"ID Conflict",.DialogFunc ' %GRID:10,7,1,1
			GroupBox 10,0,490,70,"Warning",.GroupBox1
			Text 30,21,450,35,"Some layups cannot be mapped to their corresponding property IDs because the IDs are already in use. The conflicting properties are listed below for your information.",.Text1
			ListBox 10,84,490,84,conflicts(),.ListBox1
			GroupBox 10,175,490,112,"How would you like to continue?",.GroupBox2
			OptionGroup .Group1
				OptionButton 40,196,310,14,"Skip conflicting properties",.OptionButton1
				OptionButton 40,224,450,14,"Make all properties but use non-matching, next-available IDs",.OptionButton2
				OptionButton 40,259,440,14,"Overwrite existing properties (replaces properties shown above)",.OptionButton3
			OKButton 20,322,220,35
			Text 60,238,420,14,"where necessary (preserves properties shown above)",.Text2
			CheckBox 40,294,350,21,"List conflicting properties to message window",.listConflicts
			PushButton 270,322,220,35,"Quit",.quit
		End Dialog
		Dim dlg As UserDialog
		Dialog dlg	'Cancel/Quit button is now handled by .DialogFunc

		'List conflicts if chosen
		If dlg.listConflicts = 1 Then
			App.feAppMessage(FCM_COMMAND,"Conflicting Properties:")
			For Each item In conflicts
				rc = App.feAppMessage(FCM_WARNING,item)
			Next
		End If

		Select Case dlg.Group1
			Case 0	'Skip conflicts
				layupSet.RemoveSet(propFailSet.ID)
				If layupSet.Count = 0 Then
					MsgBox("All layups skipped due to conflicting property IDs." _
					& vbNewLine & "No new properties made.", vbInformation, "Program Terminating")
					Exit Sub
				End If
			Case 1	'Make all, non-matching IDs for conflicts
				layupSet.RemoveSet(propFailSet.ID)
				makeConflictProps = True
			Case 2	'Overwrite existing props
				'do nothing, leave the conflicting IDs in the layupSet
		End Select

	End If

    '=================================================
	'Prompt user for default property parameters
    '=================================================
	Dim setDefaults As Boolean
	setDefaults = True
	Dim iterLayer As femap.layer
	Set iterLayer = App.feLayer

    'make listarrays for Options
    Dim ListArray(5) As String
    ListArray(0) = "0..As Specified"
    ListArray(1) = "1..Symmetric"
    ListArray(2) = "2..Membrane Only (Nastran)"
    ListArray(3) = "3..Bending Only (Nastran)"
    ListArray(4) = "4..Smear (Nastran)"
    ListArray(5) = "5..Smear - Core (Nastran)"

    Dim NEiOptions(3) As String
    NEiOptions(0) = "STRESS"
    NEiOptions(1) = "LARC02"
    NEiOptions(2) = "PUCK"
    NEiOptions(3) = "MCT"

    'Create input dialog
	lblGetParams:
	Begin Dialog UserDialog2 840,210,"Default Laminate Properties",.DialogFunc2 ' %GRID:10,7,1,1
		GroupBox 10,7,820,196,"Choose Parameters for the New Properties",.GroupBox1
		GroupBox 20,28,380,77,"Laminate Definition",.GroupBox2
		CheckBox 40,49,170,21,"Offset Bottom Surface",.offsetBottomSurface
		TextBox 220,49,170,21,.offsetValue
		Text 59,80,60,14,"Options",.Text2
		DropListBox 130,77,260,21,ListArray(),.Options
		GroupBox 410,28,260,112,"Laminate Properties",.GroupBox3
		Text 420,49,110,14,"N.S.Mass/Area",.Text3
		TextBox 530,49,120,14,.NSMvalue
		Text 420,70,110,14,"BondShr Allow",.Text4
		TextBox 530,70,120,14,.bondShrValue
		Text 420,91,110,14,"Ref Temp",.Text5
		TextBox 530,91,120,14,.refTempValue
		Text 420,112,110,14,"Damping",.Text6
		TextBox 530,112,120,14,.dampingValue
		GroupBox 680,21,140,175,"Failure Theory",.GroupBox4
		OptionGroup .FT
			OptionButton 690,42,110,14,"None",.none
			OptionButton 690,63,110,14,"Hill",.Hill
			OptionButton 690,84,110,14,"Hoffman",.Hoffman
			OptionButton 690,105,110,14,"Tsai-Wu",.TW
			OptionButton 690,126,110,14,"Max Strain",.maxStrain
			OptionButton 690,147,110,14,"NEi Nastran",.NEiNastran
		DropListBox 690,168,110,21,NEiOptions(),.NEiOptions
		OKButton 140,154,180,35
		PushButton 370,154,180,35,"Cancel",.cancel
		GroupBox 20,105,380,42,"Color and Layer",.GroupBox5
		TextBox 240,119,140,14,.layer
		Text 190,119,40,14,"Layer",.Text1
		Text 40,119,40,14,"Color",.Text7
		TextBox 80,119,70,14,.color
	End Dialog
	Dim dlg2 As UserDialog2

	'Condition fields
	If setDefaults Then
		dlg2.Options = 0
		dlg2.color = "110"
		dlg2.layer = Str$(App.Info_ActiveID(FT_LAYER))
		dlg2.offsetValue = "0.0"
		dlg2.NSMvalue = "0"
		dlg2.bondShrValue = "0"
		dlg2.refTempValue = "0"
		dlg2.dampingValue = "0"
		setDefaults = False
	End If

	Dialog dlg2

	'Validate inputs
	If Not(IsNumeric(dlg2.layer)) Then
		MsgBox("The value for layer must be numeric",vbOkOnly,"Error")
		GoTo lblGetParams
	End If

	If Not(IsNumeric(dlg2.color)) Then
		MsgBox("The color value must be numeric",vbOkOnly,"Error")
	End If

	If dlg2.color < 1 Or dlg2.color > 149 Then
		MsgBox("Color must be between 1 and 149, inclusive",vbOkOnly,"Invalid Color")
		GoTo lblGetParams
	End If

	If Not(iterLayer.Exist(Val(dlg2.layer))) Then
		rc = MsgBox("Layer " & dlg2.layer & " doesn't exist. Would you like to create it?" _
		& vbNewLine & "(Selecting no will write new properties to the active layer)", _
		vbYesNo,"Error")
		If rc = 6 Then
			With iterLayer
				.ID = dlg2.layer
				.title = "New Laminate Properties"
				.setID = 1
			End With
			iterLayer.Put(0)
		ElseIf rc = 7 Then
			dlg2.layer = Str(App.Info_ActiveID(FT_LAYER))
		End If
	End If


    '=================================================
	'Create new properties
    '=================================================
	Dim iterLayup As femap.Layup
	Set iterLayup = App.feLayup
	Dim successCount As Long
	Dim failCount As Long

	successCount = 0
	failCount = 0

	layupSet.Reset
	While layupSet.Next
		iterLayup.Get(layupSet.CurrentID)
		With iterProp
			.color = Val(dlg2.color)
			.ID = layupSet.CurrentID
			.setID = 1
			.title = iterLayup.title
			.layer = Val(dlg2.layer)
			.type = FET_L_LAMINATE_PLATE
			.layupID = iterLayup.ID
			If dlg2.offsetBottomSurface = 0 Then	'see User Guide Section 7.1.3, number 29 (and maybe others). The notes there might affect this flag?
				.flag(2) = False
			Else
				.flag(2) = True
				.pval(0) = dlg2.offsetValue
			End If
			.flagI(1) = dlg2.Options
			.pval(1) = dlg2.NSMvalue
			.pval(2) = dlg2.bondShrValue
			.pval(3) = dlg2.refTempValue
			.pval(4) = dlg2.dampingValue
			Select Case dlg2.FT
				Case 0
					.flagI(0) = dlg2.FT
				Case 1
					.flagI(0) = dlg2.FT
				Case 2
					.flagI(0) = dlg2.FT
				Case 3
					.flagI(0) = dlg2.FT
				Case 4
					.flagI(0) = dlg2.FT
				Case 5
					.flagI(0) = dlg2.NEiOptions + 5
			End Select
		End With

		'Store new property in database
		rc = iterProp.Put(layupSet.CurrentID)
		If rc = -1 Then
    		successCount = successCount + 1
    	Else
    		failCount = failCount + 1
    	End If
	Wend

	'Repeat for ID conflicts if necessary (this should probably be function-ized to reduce redundancy)
	If makeConflictProps Then
		propFailSet.Reset
		While propFailSet.Next
			iterLayup.Get(propFailSet.CurrentID)
			With iterProp
				.color = Val(dlg2.color)
				.ID = App.Info_NextID(FT_PROP)
				.setID = 1
				.title = iterLayup.title
				.layer = Val(dlg2.layer)
				.Type = FET_L_LAMINATE_PLATE
				.layupID = iterLayup.ID
				If dlg2.offsetBottomSurface = 0 Then	'see User Guide Section 7.1.3, number 29 (and maybe others). The notes there might affect this flag?
					.flag(2) = False
				Else
					.flag(2) = True
					.pval(0) = dlg2.offsetValue
				End If
				.flagI(1) = dlg2.Options
				.pval(1) = dlg2.NSMvalue
				.pval(2) = dlg2.bondShrValue
				.pval(3) = dlg2.refTempValue
				.pval(4) = dlg2.dampingValue
				Select Case dlg2.FT
					Case 0
						.flagI(0) = dlg2.FT
					Case 1
						.flagI(0) = dlg2.FT
					Case 2
						.flagI(0) = dlg2.FT
					Case 3
						.flagI(0) = dlg2.FT
					Case 4
						.flagI(0) = dlg2.FT
					Case 5
						.flagI(0) = dlg2.NEiOptions + 5
				End Select
			End With

			'Store new property in database
			rc = iterProp.Put(0)
			If rc = -1 Then
    			successCount = successCount + 1
	    	Else
    			failCount = failCount + 1
    		End If
		Wend
	End If

	'Report results to user
	Dim reportInfo As String

	reportInfo = successCount & " new Properties created"
	If failCount > 0 Then
		reportInfo = reportInfo & ", " & failCount & " laminates failed"
	End If

	App.feAppMessage(FCM_NORMAL,reportInfo)

End Sub


Function dialogfunc(DlgItem As String, Action As Integer, SuppValue As Integer) As Boolean
	'Dialog function for the ID conflict user dialog
    Select Case Action
    Case 1 ' Dialog box initialization
        'do things
    Case 2 ' Value changing or button pressed
        'do things
		If DlgItem = "quit" Then
			Exit All
		End If
    Case 3 ' TextBox or ComboBox text changed
        'do things
    Case 4 ' Focus changed
        'do things
    Case 5 ' Idle
        'do things
        Wait .1
    Case 6 ' Function key
        'do things
    End Select
End Function


Function DialogFunc2 (DlgItem As String, Action As Integer, SuppValue As Integer) As Boolean
	'Dialog function for the default property parameters user dialog
	Select Case Action
	Case 1	'dialog box initialization
		'do things
		DlgEnable "offsetValue", False
	Case 2	'Value changing or button pressed
		'do things
		Select Case DlgItem
			Case "cancel"
				Exit All
			Case "offsetBottomSurface"
				Select Case SuppValue
					Case 0
						DlgEnable "offsetValue", False
					Case 1
						DlgEnable "offsetValue", True
				End Select
		End Select
	Case 3	'Text box or ComboBox text changed
		'do things
	Case 4	'Focus changed
		'do things
		If DlgItem = "NEiOptions" Then
			DlgValue "FT", 5
		End If
	Case 5	'Idle
		'Wait a 10th of a second to reduce frequency of calls to this function
		Wait .1
	Case 6	'Function key
		'do nothing
	End Select
End Function
