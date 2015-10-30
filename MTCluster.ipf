#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function MTLoader()
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName,expDataFolderName
	String FileList, ThisFile,wavenames,wName,MTwave, wList
	Variable FileLoop, nWaves, i
	 
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".pxp")
	Variable nFiles=ItemsInList(FileList)
	
	for (FileLoop=0; FileLoop<nFiles; FileLoop+=1)
		ThisFile=StringFromList(FileLoop, FileList)
		expDataFolderName=ReplaceString(".pxp",ThisFile,"")	//get rid of .pxp
		LoadData /L=1/O/P=expDiskFolder/T=$expDataFolderName ThisFile
		SetDataFolder $expDataFolderName
//		MTMaker(WaveList("wave*",";",""))
		wList=WaveList("wave*",";","")
		nWaves=ItemsInList(wList)
		for (i = 0; i < nWaves; i += 1)
			wName = StringFromList(i,wList)
			Wave w1=$wName
			MTwave="MT" + num2str(w1(0))
			Make /O $MTwave={{w1(1),w1(4)},{w1(2),w1(5)},{w1(3),w1(6)}}
			KillWaves w1	//not part of MTMaker()
		endfor
		SetDataFolder root:data:
	endfor
End

Function FindAngles()
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	Variable nWaves
	String wList, wName
	
	Variable i,j
		
	for(i=0; i<numDataFolders; i+=1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		If(stringmatch(folderName,"packages")==0)
		SetDataFolder $folderName
		Print folderName
		SpherCoord()
		Wave SCThetaWave
		Wave SCPhiWave
		wList=WaveList("MT*",";","")
		nWaves=ItemsInList(wList)
		Make/O/N=(nWaves,2) xyMap
		for (j = 0; j < nWaves; j += 1)
			wName = StringFromList(j,wList)
			Wave w1=$wName
			xyMap[j][0]=w1[0][0]	//x coord at bottom of tomogram
			xyMap[j][1]=w1[0][1]	//y coord at bottom of tomogram
		endfor
		Display xyMap[][1] vs xyMap[][0]
		ModifyGraph mode=3,marker=8
		ModifyGraph zColor(xyMap)={SCthetaWave,0,1.57,Rainbow,1}	//theta scale 0 to pi/2
		SetAxis/R left 819.2,0;DelayUpdate
		SetAxis bottom 0,1100.8
		ModifyGraph mirror=1
		ModifyGraph width={Aspect,1.34375}
		TextBox/C/N=text0/B=1/F=0/X=0.00/Y=0.00 "\\Z14\\F'Symbol'q"
		TextBox/C/N=text1/B=1/F=0/A=LT/X=0.00/Y=0.00 foldername
		
		Display xyMap[][1] vs xyMap[][0]
		ModifyGraph mode=3,marker=8
		ModifyGraph zColor(xyMap)={SCphiWave,-3.14,3.14,Rainbow,1}	//phi scale -pi to pi
		SetAxis/R left 819.2,0;DelayUpdate
		SetAxis bottom 0,1100.8
		ModifyGraph mirror=1
		ModifyGraph width={Aspect,1.34375}
		TextBox/C/N=text0/B=1/F=0/X=0.00/Y=0.00 "\\Z14\\F'Symbol'j"
		TextBox/C/N=text1/B=1/F=0/A=LT/X=0.00/Y=0.00 foldername
		Else
			return 0
		Endif
		SetDataFolder dfr
	endfor
End

//check maps
Function CheckMaps(startexp,endexp)
	Variable startexp,endexp
	
	Execute "NewGizmo"
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	Variable i
		
	for(i=startexp; i<endexp+1; i+=1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		If(stringmatch(folderName,"packages")==0)
		SetDataFolder $folderName
		Print folderName
		MTplotter()
		Else
			return 0
		Endif
		SetDataFolder dfr
	endfor
End

//Function from Igor help edited to list foldernames
Function PrintAllWaveNames()
		String objName
		Variable index = 0
		DFREF dfr = GetDataFolderDFR()	// Reference to current data folder
		do
			objName = GetIndexedObjNameDFR(dfr, 4, index)
			if (strlen(objName) == 0)
				break
			endif
			Print objName
			index += 1
		while(1)
End