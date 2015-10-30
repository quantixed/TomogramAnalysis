#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//This function loads all the the bundles from different Igor pxps in a directory
//It makes MT waves like MTMaker does
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

//This function will find number of MTs, the area, the density for each bundle
Function BundleStats()

	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	Make /O /T /N=(numDataFolders) root:stBundleNames	//this will be a list of bundles
	Wave /T stB = root:stBundleNames
	Make /O /N=(numDataFolders) root:stMTWave		//this will contain the number of MTs
	Wave stMT = root:stMTWave
	Make /O /N=(numDataFolders) root:stAreaWave		//this will contain the cross sectional areas
	Wave stA = root:stAreaWave
	Make /O /N=(numDataFolders) root:stDensityWave		//this will contain the cross sectional areas
	Wave stD = root:stDensityWave
	
	Variable nWaves,ncr
	String wList, wName,plotName,imgName
	Variable i,j,k
		
	for(i=0; i<numDataFolders; i+=1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		If(stringmatch(folderName,"packages")==0)
		SetDataFolder $folderName
		//record name of bundle
		stB[i]=folderName
		wList=WaveList("MT*",";","")
		nWaves=ItemsInList(wList)
		//store number of MTs in bundle
		stMT[i]=nWaves
		Make/O/N=(nWaves,2) xyMap
		for (j = 0; j < nWaves; j += 1)
			wName = StringFromList(j,wList)
			Wave w1=$wName
			xyMap[j][0]=w1[0][0]	//x coord at bottom of tomogram
			xyMap[j][1]=w1[0][1]	//y coord at bottom of tomogram
		endfor
		
		Duplicate/O /R=[][0] xyMap, xW
		Redimension /N=-1 xW
		Duplicate/O /R=[][1] xyMap, yW
		Redimension /N=-1 yW
		ConvexHull /C xW,yW
		Wave W_Xhull,W_Yhull
		//calculate and store area and density of bundle
		stA[i]=polygonArea(W_Xhull,W_Yhull)
		stD[i]= stMT[i]/stA[i]
		
		//now calculate nearest neighbour
		Make /O /N=(nWaves) TempWave
		Make /O /N=(nWaves) DistWave=0,RadWave=0

		For (j = 0; j < nWaves; j+=1)
			TempWave=NaN
			For (k = 0; k < nWaves; k+=1)
				if (k==j)
					TempWave[k]=NaN
				else
					TempWave[k]=sqrt(((xW[j]-xW[k])^2)+((yW[j]-yW[k])^2))
				endif
			EndFor
			DistWave[j]=WaveMin(TempWave)
			Extract /FREE TempWave, tW, TempWave <= 105 //80 nm wall-to-wall is approx 105 nm
			RadWave[j]=numpnts(tW)
		EndFor
		
		KillWaves TempWave

		//Make plot of nearest neighbour distance
		plotName = "map_" + folderName
		DoWindow /K $plotName
		Display /N=$plotName xyMap[][1] vs xyMap[][0]
		ModifyGraph mode=3,marker=8
		ModifyGraph zColor(xyMap)={DistWave,25,100,Rainbow,0}
		AppendToGraph W_Yhull vs W_Xhull
		ModifyGraph rgb(W_YHull)=(32768,32768,32768)
		SetAxis/R left 819.2,0;DelayUpdate
		SetAxis bottom 0,1100.8
		ModifyGraph mirror=1
		ModifyGraph width={Aspect,1.34375}
		TextBox/C/N=text0/B=1/F=0/A=LT/X=0.00/Y=0.00 foldername
		
		//Make heatmap
		Concatenate /O {xW,yW,RadWave}, nnMap
		ImageInterpolate /S={floor(waveMin(xW)),1,ceil(waveMax(xW)),floor(waveMin(yW)),1,ceil(waveMax(yW))} Voronoi nnMap
		Wave M_InterpolatedImage
		imgName = "img_" + folderName
		DoWindow /K $imgName
		Display /N=$imgName
		AppendImage M_InterpolatedImage
		SetAxis/R left 819.2,0;DelayUpdate
		SetAxis bottom 0,1100.8
		ModifyGraph mirror=1
		ModifyGraph width={Aspect,1.34375}
		TextBox/C/N=text0/B=1/F=0/A=LT/X=0.00/Y=0.00 foldername
		ModifyImage M_InterpolatedImage ctab= {1,10,Rainbow,1}
		
		//Calculate RefDistWave. Old method used StartEnd() and MTcomparer(). This is more simple.
		//Find centre at bottom of tomogram
		FPClustering /maxr=30 /maxc=1 /cm /cac xyMap
		Wave M_clustersCM
		Make/O/N=(nWaves) RefDistWave
		Duplicate /FREE xW sxW
		Duplicate /FREE yW syW
		sxW -=M_clustersCM[0][0]
		syW -=M_ClustersCM[0][1]
		RefDistWave =sqrt((sxW^2)+(syW^2)) //checked this by plotting xyMap and colourcoding - OK.
		
		//Do Angle Analysis
		LowPoint()
		SpherCoord()
		
		
		Else
			return 0
		Endif
		
		SetDataFolder dfr
	EndFor
	SetDataFolder root:
	Edit/K=0  root:stBundleNames,root:stMTWave,root:stAreaWave,root:stDensityWave
	Execute "TileWindows/O=1/C"
End

//simplifies busy experiments
//example: ShowMe("img*") //looks at heatmaps only
//ShowMe("map*") //looks at maps only
//ShowMe("*") //resets to see show all windows
//ShowMe("*GFP*") //shows all GFP windows
Function ShowMe(key)
	string key
	
	string fulllist = WinList("*", ";","WIN:1")
	string name
	variable i
 
	for(i=0; i<itemsinlist(fulllist); i +=1)
		name= stringfromlist(i, fulllist)
		If(StringMatch(name, key )==1)
			Dowindow/HIDE=0 $name //show window
		Else
			Dowindow/HIDE=1 $name //hide window
		EndIf
	endfor
	Execute "TileWindows/O=1/C"
End

//Straight(), LowPoint(), SpherCoord() are modified from MTAngleProcedures.ipf
Function Straight(phi,theta)
	variable theta,phi //in radians

	String wList=wavelist("MT*",";","")
	String wName
	Variable i

	Make/o zRotationMatrix={{cos(phi),-sin(phi),0},{sin(phi),cos(phi),0},{0,0,1}}
	Make/o yRotationMatrix={{cos(theta),0,sin(theta)},{0,1,0},{-sin(theta),0,cos(theta)}}

	For (i = 0; i < ItemsInList(wList); i += 1)
		wName = StringFromList(i, wList)
		String newname="r"+wname
		Wave/Z w = $wName
		MatrixMultiply w,zRotationMatrix
		Wave M_Product
		MatrixMultiply M_Product,yRotationMatrix
		Duplicate /o M_product $newname
	EndFor
	Killwaves M_Product
End

//Straight(), LowPoint(), SpherCoord() are modified from MTAngleProcedures.ipf
Function LowPoint()
	
	Variable theta,phi //in radians
	Make /o /n=90 MatThetaWave	//90¡ is sufficient with no reflection (and reversal of Mt polarity)
	MatThetaWave =x/(180/PI)
	Make /o /n=360 MatPhiWave
	MatPhiWave =x/(180/PI)	//1¡ increments seem OK. For 24 MTs, only 0.03 nm difference for increments from lowpoint
	Make /o /n=(360,90) MatResWave

	String wList=wavelist("MT*",";","")
	String wName
	Variable i,j,k
	Variable px	//pixel value - how much black would be seen in gizmo en face

	For (j = 0; j < numpnts(MatThetaWave); j +=1)
		Theta=MatThetaWave(j)
		For (k = 0; k < numpnts(MatPhiWave);  k +=1)
			px=0
			Phi=MatPhiWave(k)
			Make/o zRotationMatrix={{cos(phi),-sin(phi),0},{sin(phi),cos(phi),0},{0,0,1}}
			Make/o yRotationMatrix={{cos(theta),0,sin(theta)},{0,1,0},{-sin(theta),0,cos(theta)}}
			MatrixMultiply zRotationMatrix,yRotationMatrix
			Wave M_Product
			Duplicate /O M_Product,zyRotationMatrix
				For (i = 0; i < ItemsInList(wList); i += 1)
					wName = StringFromList(i, wList)
					Wave/Z w = $wName
					MatrixMultiply w,zyRotationMatrix
					px +=sqrt(((M_Product[1][0]-M_Product[0][0])^2)+((M_Product[1][1]-M_Product[0][1])^2))
				EndFor
			MatResWave[k][j]=px
		EndFor
	EndFor
	Killwaves zRotationMatrix,yRotationMatrix,zyRotationMatrix,M_Product	///cleanup
	WaveStats /Q MatResWave
//	Print "Rotating z by phi =",V_minRowLoc/(180/PI)," and then rotating y by theta = ",V_minColLoc/(180/PI)
	Straight(V_minRowLoc/(180/PI),V_minColLoc/(180/PI))
	Killwaves MatThetaWave,MatPhiWave,MatResWave
End

//Straight(), LowPoint(), SpherCoord() are modified from MTAngleProcedures.ipf
Function SpherCoord()
	
	String wList=wavelist("rMT*",";","")
		
	String wName,wSC
	Variable nWaves
	Variable i
	Variable wx, wy, wz
	
	string LabelWName, rWName, thetaWName, phiWName
	
	LabelWName="rSClabelWave"
	rWName="rSCrWave"
	thetaWName="rSCthetaWave"
	phiWName="rSCphiWave"
		
	nWaves = ItemsInList(wList)
	Make /O /T /N=(nWaves) $LabelWName
	Make /O /N=(nWaves) $rWName
	Make /O /N=(nWaves) $thetaWName
	Make /O /N=(nWaves) $phiWName

	Wave /T LabelW=$LabelWName
	Wave rW=$rWName
	Wave thetaW=$thetaWName
	Wave phiW=$phiWName

	for (i = 0; i < nWaves; i += 1)
	wName = StringFromList(i, wList)
	Wave/Z w = $wName
			wSC =wName 
			LabelW[i]=wSc
			
			wx=w[1][0]-w[0][0]
			If  ((wx > -0.001) && (wx < 0.001))	//if statements to prevent errors from rounding
				wx=0
			endif
			wy=w[1][1]-w[0][1]
			If  ((wy > -0.001) && (wy < 0.001))
				wy=0
			endif			
			wz=w[1][2]-w[0][2]
			If  ((wz > -0.001) && (wz < 0.001))
				wz=0
			endif

			rW[i]=sqrt((wx^2)+(wy^2)+(wz^2))
			thetaW[i]=acos(wz/(sqrt((wx^2)+(wy^2)+(wz^2))))
			//need to *(180/pi) to get ¡			
			phiW[i]=atan2(wy,wx)
	endfor
	Variable V_avg,V_sdev
	Wavestats /q rW
//	Print "Radial distance, r: mean",V_avg,"±",V_sdev,"nm. Median =",Statsmedian(rW)
	Wavestats /q thetaW
//	Print "Polar angle, theta: mean",V_avg,"±",V_sdev,"radians. Median =",Statsmedian(thetaW)
	Wavestats /q phiW
//	Print "Azimuthal angle, phi: mean" ,V_avg,"±",V_sdev,"radians. Median =",Statsmedian(phiW)
End