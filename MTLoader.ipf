#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// This function loads all the the bundles from different Igor pxps in a directory
// It makes corectly formatted MT waves like MTMaker() used to do
Function MTLoader()
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName, expDataFolderName
	String FileList, ThisFile, wavenames, wName, MTwave, wList
	Variable FileLoop, nWaves, i
	 
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList = IndexedFile(expDiskFolder,-1,".pxp")
	Variable nFiles = ItemsInList(FileList)
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString(".pxp",ThisFile,"")	// get rid of .pxp
		LoadData/L=1/O/P=expDiskFolder/T=$expDataFolderName ThisFile
		SetDataFolder $expDataFolderName
		wList = WaveList("wave*",";","")
		nWaves = ItemsInList(wList)
		for (i = 0; i < nWaves; i += 1)
			wName = StringFromList(i,wList)
			Wave w1 = $wName
			MTwave = "MT" + num2str(w1[0])
			Make/O $MTwave = {{w1[1],w1[4]},{w1[2],w1[5]},{w1[3],w1[6]}}
			KillWaves w1	// not part of MTMaker()
		endfor
		SetDataFolder root:data:
	endfor
End

// This function will find number of MTs, the area, the density for each bundle
// It also generates the heatmaps and colour coded MT maps
// It then calls the angle analysis procedures
Function BundleStats()

	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	Make/O/T/N=(numDataFolders) root:stBundleNames	// this will be a list of bundles
	Wave/T stB = root:stBundleNames
	Make/O/N=(numDataFolders) root:stMTWave		// this will contain the number of MTs
	Wave stMT = root:stMTWave
	Make/O/N=(numDataFolders) root:stAreaWave		// this will contain the cross sectional areas
	Wave stA = root:stAreaWave
	Make/O/N=(numDataFolders) root:stDensityWave		//this will contain the cross sectional areas
	Wave stD = root:stDensityWave
	
	Variable nWaves, ncr
	String wList, wName, plotName, imgName
	Variable i, j, k
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		if(stringmatch(folderName,"packages") == 0)
		SetDataFolder $folderName
		// record name of bundle
		stB[i] = folderName
		wList = WaveList("MT*",";","")
		nWaves = ItemsInList(wList)
		// store number of MTs in bundle
		stMT[i] = nWaves
		Make/O/N=(nWaves,2) xyMap
		for (j = 0; j < nWaves; j += 1)
			wName = StringFromList(j,wList)
			Wave w1 = $wName
			xyMap[j][0] = w1[0][0]	// x coord at bottom of tomogram
			xyMap[j][1] = w1[0][1]	// y coord at bottom of tomogram
		endfor
		
		Duplicate/O/R=[][0] xyMap, xW
		Redimension/N=-1 xW
		Duplicate/O/R=[][1] xyMap, yW
		Redimension/N=-1 yW
		ConvexHull/C xW,yW
		Wave W_Xhull,W_Yhull
		// calculate and store area and density of bundle
		stA[i] = polygonArea(W_Xhull,W_Yhull)
		stD[i] = stMT[i]/stA[i]
		
		//now calculate nearest neighbour
		Make/O/N=(nWaves) TempWave
		Make/O/N=(nWaves) DistWave=0, RadWave=0

		for(j = 0; j < nWaves; j+=1)
			TempWave = NaN
			for(k = 0; k < nWaves; k+=1)
				if(k == j)
					TempWave[k] = NaN
				else
					TempWave[k] = sqrt(((xW[j] - xW[k])^2) + ((yW[j] - yW[k])^2))
				endif
			endfor
			DistWave[j] = WaveMin(TempWave)
			Extract/FREE TempWave, tW, TempWave <= 105 //80 nm wall-to-wall is approx 105 nm
			RadWave[j] = numpnts(tW)
		endfor
		
		KillWaves TempWave

		// Make plot of nearest neighbour distance
		plotName = "map_" + folderName
		DoWindow/K $plotName
		Display/N=$plotName xyMap[][1] vs xyMap[][0]
		ModifyGraph mode=3,marker=8
		ModifyGraph zColor(xyMap)={DistWave,25,100,Rainbow,0}
		AppendToGraph W_Yhull vs W_Xhull
		ModifyGraph rgb(W_YHull)=(32768,32768,32768)
		SetAxis/R left 819.2,0;DelayUpdate
		SetAxis bottom 0,1100.8
		ModifyGraph mirror=1
		ModifyGraph width={Aspect,1.34375}
		TextBox/C/N=text0/B=1/F=0/A=LT/X=0.00/Y=0.00 foldername
		
		// Make heatmap
		Concatenate/O {xW,yW,RadWave}, nnMap
		ImageInterpolate/S={floor(waveMin(xW)),1,ceil(waveMax(xW)),floor(waveMin(yW)),1,ceil(waveMax(yW))} Voronoi nnMap
		Wave M_InterpolatedImage
		imgName = "img_" + folderName
		DoWindow/K $imgName
		Display/N=$imgName
		AppendImage M_InterpolatedImage
		SetAxis/R left 819.2,0;DelayUpdate
		SetAxis bottom 0,1100.8
		ModifyGraph mirror=1
		ModifyGraph width={Aspect,1.34375}
		TextBox/C/N=text0/B=1/F=0/A=LT/X=0.00/Y=0.00 foldername
		ModifyImage M_InterpolatedImage ctab= {1,10,Rainbow,1}
		
		// Calculate RefDistWave
		// Old method used StartEnd() and MTcomparer(). This is more simple.
		// Find centre at bottom of tomogram
		FPClustering /maxr=30 /maxc=1 /cm /cac xyMap
		Wave M_clustersCM
		Make/O/N=(nWaves) RefDistWave
		Duplicate /FREE xW sxW
		Duplicate /FREE yW syW
		sxW -= M_clustersCM[0][0]
		syW -= M_ClustersCM[0][1]
		RefDistWave = sqrt((sxW^2)+(syW^2))
		
		//Do Angle Analysis
		LowPoint()
		SpherCoord()
		MakePlane()
			
		else
			return 0
		endif
		
		SetDataFolder dfr
	endfor
	SetDataFolder root:
	Edit/K=0  root:stBundleNames,root:stMTWave,root:stAreaWave,root:stDensityWave
	Execute "TileWindows/O=1/C"
End

// Extract the data
////	@param	expA	a semi-colon separated string describing the experimental conditions
////	@param	expB	an optional semi-colon separated string describing other experimental conditions
Function PullOut(expA, [expB])
	String expA,expB // e.g. PullOut("control;drug;",expB="warm;cold;") is 4 conditions
	// PullOut("control;drug1;drug2;") is 3 conditions
	
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Wave /T stB = root:stBundleNames
	Wave stMT = root:stMTWave
	Wave stA = root:stAreaWave
	Wave stD = root:stDensityWave
	Variable nExp = numpnts(stMT)

	String expC, wName, fList = "", cList = ""
	Make/O/N=(nExp) root:stInd
	Wave stN = root:stInd
	Variable i, j, k
	
	if(paramisdefault(expB))
		for (i=0; i < ItemsInList(expA); i+=1)
			fList = ""
			expC = StringFromList(i,expA)
			for (k = 0; k < nExp; k += 1)
				if(stringmatch(stB[k],expC + "*") == 1)
					stN[k] = 1
					fList = fList + ":" + stB[k] + ";"
				else
					stN[k] = 0
				endif
			endfor
			wName = "root:sm" + expC + "_MT"
			Duplicate/O stMT, $wName
			Wave w0 = $wName
			wName = "root:sm" + expC + "_Area"
			Duplicate/O stA, $wName
			Wave w1 = $wName
			wName = "root:sm" + expC + "_Density"
			Duplicate/O stD, $wName
			Wave w2 = $wName
			Duplicate/O stD, w2
			w0 = (stN==1) ? w0 : NaN
			w1 = (stN==1) ? w1 : NaN
			w2 = (stN==1) ? w2 : NaN
			WaveTransform zapnans w0
			WaveTransform zapnans w1
			WaveTransform zapnans w2
			if(numpnts(w0) == 0)
				KillWaves w0,w1,w2
			else
				wName="root:sn" + expC + "_refDist"
				cList=ReplaceString(";", fList, ":RefDistWave;")
				Concatenate/O/NP=0 cList, $wName
				
				wName="root:sn" + expC + "_rSCtheta"
				cList=ReplaceString(";", fList, ":rSCthetaWave;")
				Concatenate/O/NP=0 cList, $wName
					
				wName="root:sn" + expC + "_rSCphi"
				cList=ReplaceString(";", fList, ":rSCphiWave;")
				Concatenate/O/NP=0 cList, $wName
				
				wName="root:sn" + expC + "_rSCxyPlane"
				cList=ReplaceString(";", fList, ":rSCxyPlaneWave;")
				Concatenate/O/NP=0 cList, $wName
			endif
		endfor
	else
		for (i=0; i < ItemsInList(expA); i+=1)
			for (j=0; j < ItemsInList(expB); j+=1)
				fList = ""
				expC = StringFromList(i,expA) + "_" + StringFromList(j,expB)
				for (k = 0; k < nExp; k += 1)
					if(stringmatch(stB[k],expC + "*") == 1)
						stN[k] = 1
						fList = fList + ":" + stB[k] + ";"
					else
						stN[k] = 0
					endif
				endfor
				wName = "root:sm" + expC + "_MT"
				Duplicate/O stMT, $wName
				Wave w0 = $wName
				wName = "root:sm" + expC + "_Area"
				Duplicate/O stA, $wName
				Wave w1 = $wName
				wName = "root:sm" + expC + "_Density"
				Duplicate/O stD, $wName
				Wave w2 = $wName
				Duplicate/O stD, w2
				w0 = (stN==1) ? w0 : NaN
				w1 = (stN==1) ? w1 : NaN
				w2 = (stN==1) ? w2 : NaN
				WaveTransform zapnans w0
				WaveTransform zapnans w1
				WaveTransform zapnans w2
				if(numpnts(w0) == 0)
					KillWaves w0,w1,w2
				else
					wName="root:sn" + expC + "_refDist"
					cList=ReplaceString(";", fList, ":RefDistWave;")
					Concatenate/O/NP=0 cList, $wName
					
					wName="root:sn" + expC + "_rSCtheta"
					cList=ReplaceString(";", fList, ":rSCthetaWave;")
					Concatenate/O/NP=0 cList, $wName
						
					wName="root:sn" + expC + "_rSCphi"
					cList=ReplaceString(";", fList, ":rSCphiWave;")
					Concatenate/O/NP=0 cList, $wName
					
					wName="root:sn" + expC + "_rSCxyPlane"
					cList=ReplaceString(";", fList, ":rSCxyPlaneWave;")
					Concatenate/O/NP=0 cList, $wName
				endif
			endfor
		endfor
	endif
	KillWaves stN
	SetDataFolder root:
End

// Simplifies busy experiments
////	@param	key	string to specify what is shown
Function ShowMe(key)
	string key
	// example: ShowMe("img*") //looks at heatmaps only
	// ShowMe("map*") //looks at maps only
	// ShowMe("*") //resets to see show all windows
	// ShowMe("*GFP*") //shows all GFP windows

	string fulllist = WinList("*", ";","WIN:1")
	string name
	variable i
 
	for(i = 0; i < itemsinlist(fulllist); i += 1)
		name= stringfromlist(i, fulllist)
		if(StringMatch(name, key )==1)
			Dowindow/HIDE=0 $name //show window
		else
			Dowindow/HIDE=1 $name //hide window
		endif
	endfor
	Execute "TileWindows/O=1/C"
End

// Straight(), LowPoint(), SpherCoord() are modified from MTAngleProcedures.ipf
////	@param	phi	variable specifying roation angle in radians
////	@param	theta	variable specifying roation angle in radians
Function Straight(phi,theta)
	variable theta, phi

	String wList = wavelist("MT*",";","")
	String wName
	Variable i

	Make/O zRotationMatrix={{cos(phi),sin(phi),0},{-sin(phi),cos(phi),0},{0,0,1}}
	Make/O yRotationMatrix={{cos(theta),0,-sin(theta)},{0,1,0},{sin(theta),0,cos(theta)}}

	for (i = 0; i < ItemsInList(wList); i += 1)
		wName = StringFromList(i, wList)
		String newname = "r"+wname
		Wave/Z w = $wName
		MatrixMultiply w,zRotationMatrix
		Wave M_Product
		MatrixMultiply M_Product,yRotationMatrix
		Duplicate/O M_product $newname
	endfor
	Killwaves M_Product
End

Function LowPoint()
	
	Variable theta,phi //in radians
	Make/O/N=90 MatThetaWave	// 90¡ is sufficient with no reflection (and reversal of Mt polarity)
	MatThetaWave = x/(180/PI)
	Make/O/N=360 MatPhiWave
	MatPhiWave = x/(180/PI)	// 1¡ increments seem OK. For 24 MTs, only 0.03 nm difference for increments from lowpoint
	Make/O/N=(360,90) MatResWave

	String wList = wavelist("MT*",";","")
	String wName
	Variable i, j, k
	Variable px	//pixel value - how much black would be seen in gizmo en face

	for (j = 0; j < numpnts(MatThetaWave); j +=1)
		theta = MatThetaWave(j)
		for (k = 0; k < numpnts(MatPhiWave);  k +=1)
			px = 0
			Phi = MatPhiWave(k)
			Make/O zRotationMatrix = {{cos(phi),-sin(phi),0},{sin(phi),cos(phi),0},{0,0,1}}
			Make/O yRotationMatrix = {{cos(theta),0,sin(theta)},{0,1,0},{-sin(theta),0,cos(theta)}}
			MatrixMultiply zRotationMatrix,yRotationMatrix
			Wave M_Product
			Duplicate/O M_Product,zyRotationMatrix
				for (i = 0; i < ItemsInList(wList); i += 1)
					wName = StringFromList(i, wList)
					Wave/Z w = $wName
					MatrixMultiply w,zyRotationMatrix
					px += sqrt(((M_Product[1][0]-M_Product[0][0])^2)+((M_Product[1][1]-M_Product[0][1])^2))
				endfor
			MatResWave[k][j] = px
		EndFor
	EndFor
	Killwaves zRotationMatrix,yRotationMatrix,zyRotationMatrix,M_Product	///cleanup
	WaveStats /Q MatResWave
	Straight(V_minRowLoc/(180/PI),V_minColLoc/(180/PI))
	Killwaves MatThetaWave,MatPhiWave,MatResWave
End

Function SpherCoord()
	
	String wList = wavelist("rMT*",";","")
		
	String wName, wSC
	Variable nWaves
	Variable i
	Variable wx, wy, wz
	
	string LabelWName, rWName, thetaWName, phiWName
	
	LabelWName = "rSClabelWave"
	rWName = "rSCrWave"
	thetaWName = "rSCthetaWave"
	phiWName = "rSCphiWave"
		
	nWaves = ItemsInList(wList)
	Make/O/T/N=(nWaves) $LabelWName
	Make/O/N=(nWaves) $rWName
	Make/O/N=(nWaves) $thetaWName
	Make/O/N=(nWaves) $phiWName

	Wave/T LabelW = $LabelWName
	Wave rW = $rWName
	Wave thetaW = $thetaWName
	Wave phiW = $phiWName

	for (i = 0; i < nWaves; i += 1)
		wName = StringFromList(i, wList)
		Wave/Z w = $wName
		wSC = wName 
		LabelW[i] = wSc
		
		wx = w[1][0] - w[0][0]
			if((wx > -0.001) && (wx < 0.001))	// if statements to prevent errors from rounding
				wx = 0
			endif
			wy = w[1][1] - w[0][1]
			if((wy > -0.001) && (wy < 0.001))
				wy = 0
			endif			
			wz = w[1][2]-w[0][2]
			if((wz > -0.001) && (wz < 0.001))
				wz = 0
			endif

			rW[i] = sqrt((wx^2) + (wy^2) + (wz^2))
			thetaW[i] = acos(wz / (sqrt((wx^2) + (wy^2) + (wz^2))))
			// need to *(180/pi) to get degrees
			phiW[i] = atan2(wy,wx)
	endfor
	Variable V_avg, V_sdev
	Wavestats /q rW
	Wavestats /q thetaW
	Wavestats /q phiW
End

Function MakePlane()	// find intersection of mrMTs with plane at z=100
	Wave rSCrWave, rSCthetaWave, rSCphiWave
	Variable i
	Variable n = numpnts(rSCrWave)
	Make/O/N=(n,2) rSCxyPlaneWave	// x y values in 2D wave
	Variable xb,yb,zb,t // xa,ya,za are 0,0,0 and t will be 100/xb
	
	for(i = 0; i < n; i +=1)
			xb = rSCrWave[i] * (sin(rSCthetaWave[i])) * (cos(rSCphiWave[i]))
			yb = rSCrWave[i] * (sin(rSCthetaWave[i])) * (sin(rSCphiWave[i]))
			zb = rSCrWave[i] * (cos(rSCthetaWave[i]))
			t = 100/zb
			rSCxyPlaneWave[i][0] = xb*t
			rSCxyPlaneWave[i][1] = yb*t
	endfor
End
