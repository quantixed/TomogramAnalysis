#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <New Polar Graphs>
#include <Append Calibrator>
#include <All Gizmo Procedures>
#include <TintedWindowBackground>

//This function makes MT waves - these are 2d waves (3 columns = x y z, 2 rows = start end)
//The input is from excel where each column is a MT rows are: MT number, startx,starty,startz,endx,endy,endz.
//It basically just rejigs this list.
Function MTmaker(wavenames)
	String wavenames	//this will be wavelist("wave*",";","")
	String name
  	Variable i  //loop Variable
	for (i = 0; i < ItemsInList(wavenames); i += 1)
	name = StringFromList(i,wavenames)
	Wave w1=$name
	string MTwave="MT" + num2str(w1(0))
	Make /O $MTwave={{w1(1),w1(4)},{w1(2),w1(5)},{w1(3),w1(6)}}
	endfor
End

//Once you have run MTmaker. You can plot them out with MTplotter
//!!FIRST!! Execute NewGizmo
//It is automatically scaled to min and max, so z scale (at least) needs changing
Function MTplotter() //execute NewGizmo first
	String name
	String path
	String cmd
	Variable i
	for (i = 0; i < ItemsInList(wavelist("MT*",";","")); i += 1)
	name = StringFromList(i,wavelist("MT*",";",""))
	path = "p" + name
	sprintf cmd, "AppendToGizmo /N=Gizmo0/D Path=%s, %s", name, path //for some reason I couldn't figure out, pathname is not used in gizmo
	Print cmd
	Execute cmd
	endfor
End	

Function MTplotterii() //execute NewGizmo first
	String name
	String path
	String cmd
	Variable i
	for (i = 0; i < ItemsInList(wavelist("rMT*",";","")); i += 1)
	name = StringFromList(i,wavelist("rMT*",";",""))
	path = "p" + name
	sprintf cmd, "AppendToGizmo /N=Gizmo1/D Path=%s, %s", name, path //for some reason I couldn't figure out, pathname is not used in gizmo
	Print cmd
	Execute cmd
	endfor
End

Function MTplotteriii() //execute NewGizmo first
	String name
	String path
	String cmd
	Variable i
	for (i = 0; i < ItemsInList(wavelist("mrMT*",";","")); i += 1)
	name = StringFromList(i,wavelist("mrMT*",";",""))
	path = "p" + name
	sprintf cmd, "AppendToGizmo /N=Gizmo2/D Path=%s, %s", name, path //for some reason I couldn't figure out, pathname is not used in gizmo
	Print cmd
	Execute cmd
	endfor
End	

//This function compares the angles of MTs relative to one another.
//It doesn't compare a given MT with itself nor are there replications - handshake problem
//The result is always positive, so it tells you about deviation from the MT.
//Result is in degrees (*180/pi). Only results from 0-180 are possible
//In reality not much beyond 90 is possible because it finds the most acute angle
//MTs all go in the same direction so this constrains things further
Function MTpairer(WavesList)
	String WavesList
	String Wave1, Wave2, pair
	Variable nWaves, nsize
	Variable i, j, k
	Variable ABx, CDx, ABy, CDy, ABz, CDz
	
	nWaves = ItemsInList(WavesList)
	nsize = (nWaves*(nwaves-1))/2
	Make /O /T /N=(nsize) LabelWave
	Make /O /N=(nsize) AngleWave
	
	for (i = 0; i < nWaves; i += 1)
	Wave1 = StringFromList(i, WavesList)
	Wave/Z w1 = $Wave1
		for (j = 0; j < nWaves; j+=1)
		Wave2 = StringFromList(j, WavesList)
		Wave/Z w2 = $Wave2
			if (j>i)
			pair=Wave1 + "_" + Wave2
			LabelWave[k]=pair
			ABx=w1[1][0]-w1[0][0]
			CDx=w2[1][0]-w2[0][0]
			ABy=w1[1][1]-w1[0][1]
			CDy=w2[1][1]-w2[0][1]
			ABz=w1[1][2]-w1[0][2]
			CDz=w2[1][2]-w2[0][2]
			AngleWave[k]=acos(((ABx*CDx)+(ABy*CDy)+(ABz*CDz))/(sqrt((ABx^2)+(ABy^2)+(ABz^2))*sqrt((CDx^2)+(CDy^2)+(CDz^2))))*(180/pi)
			k+=1
			endif
		endfor
	endfor
End

//MTcomparer compares every MT with a reference MT called refMT
//RefMT is created from finding the centre of the bundle at the start and at the end see findrefmt.pxp
//Otherwise this function is the same as MTpairer.
//It actually compares refMt to each MT and not the other way around - but this doesn't matter
Function MTcomparer(WavesList)
	String WavesList
	String Wave1, pair
	Wave/Z w2 = RefMT
	Variable nWaves
	Variable i
	Variable ABx, CDx, ABy, CDy, ABz, CDz
	
	nWaves = ItemsInList(WavesList)
	Make /O /T /N=(nWaves) RefLabelWave
	Make /O /N=(nWaves) RefAngleWave
	Make /O /N=(nWaves) RefDistWave
	
	for (i = 0; i < nWaves; i += 1)
	Wave1 = StringFromList(i, WavesList)
	Wave/Z w1 = $Wave1
			pair="RefMT_" + Wave1 
			RefLabelWave[i]=pair
			ABx=w1[1][0]-w1[0][0]
			CDx=w2[1][0]-w2[0][0]
			ABy=w1[1][1]-w1[0][1]
			CDy=w2[1][1]-w2[0][1]
			ABz=w1[1][2]-w1[0][2]
			CDz=w2[1][2]-w2[0][2]
			RefAngleWave[i]=acos(((ABx*CDx)+(ABy*CDy)+(ABz*CDz))/(sqrt((ABx^2)+(ABy^2)+(ABz^2))*sqrt((CDx^2)+(CDy^2)+(CDz^2))))*(180/pi)
			//calculate distances			
			RefDistWave[i]=sqrt(((w1[0][0]-w2[0][0])^2)+((w1[0][1]-w2[0][1])^2))
	endfor
End

Function StartEnd()
	Variable nWaves
	Variable i
	nWaves = ItemsInList(wavelist("MT*",";",""))
	Make /O /N=(nWaves,3) MapStart
	Make /O /N=(nWaves,3) MapEnd
	for (i = 0; i < ItemsInList(wavelist("MT*",";","")); i += 1)
		String name = StringFromList(i,wavelist("MT*",";",""))
		Wave w1=$name
		MapStart[i][0]=w1[0][0]
		MapStart[i][1]=w1[0][1]
		MapStart[i][2]=w1[0][2]
		MapEnd[i][0]=w1[1][0]
		MapEnd[i][1]=w1[1][1]
		MapEnd[i][2]=w1[1][2]
	endfor
	Wave MT1
	Duplicate /o MT1 RefMT
	fpclustering /maxr=30 /maxc=1 /cm /cac MapStart
	Wave M_clustersCM
	RefMT[0][0]=M_clustersCM[0][0]
	RefMT[0][1]=M_clustersCM[0][1]
	fpclustering /maxr=30 /maxc=1 /cm /cac MapEnd
	RefMT[1][0]=M_clustersCM[0][0]
	RefMT[1][1]=M_clustersCM[0][1]
	
	Wave refanglewave
	Display MapStart[][1] vs MapStart[][0]
	ModifyGraph mode=3,marker=8
	ModifyGraph zColor(MapStart)={RefAngleWave,-45,45,RedWhiteBlue256,1}
	AppendToGraph RefMT[0,0][1] vs RefMT[0,0][0]
	ModifyGraph mode=3,rgb(RefMT)=(0,0,0)
	SetAxis left 0,1170
	SetAxis bottom 0,1570
	ModifyGraph width={Plan,1,bottom,left},height={Plan,1,left,bottom}
	ModifyGraph noLabel=2,axThick=0,standoff=0
	ModifyGraph margin=28
	SetDrawLayer ProgBack
	SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (61166,61166,61166),linethick= 0.00;DelayUpdate
	DrawRect 0,0,1570,1170
	SetDrawLayer UserFront

	Display MapEnd[][1] vs MapEnd[][0]
	ModifyGraph mode=3,marker=8
	ModifyGraph zColor(MapEnd)={RefAngleWave,-45,45,RedWhiteBlue256,1}
	AppendToGraph RefMT[1,1][1] vs RefMT[1,1][0]
	ModifyGraph mode=3,rgb(RefMT)=(0,0,0)
	SetAxis left 0,1170
	SetAxis bottom 0,1570
	ModifyGraph width={Plan,1,bottom,left},height={Plan,1,left,bottom}
	ModifyGraph noLabel=2,axThick=0,standoff=0
	ModifyGraph margin=28
	SetDrawLayer ProgBack
	SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (61166,61166,61166),linethick= 0.00;DelayUpdate
	DrawRect 0,0,1570,1170
	SetDrawLayer UserFront
End

//setOrigin to define where the origin is. Need w1 to be a copy.
Function SetOrigin(ox,oy,oz,w1)
	Variable ox,oy,oz
	Wave w1
	w1[][0] -=ox
	w1[][1] -=oy
	w1[][2] -=oz
End

//find spherical co-ordinates for each MT
//SetOrigin is not incorporated yet
Function SpherCoord([rot])
	Variable rot
	
	String wList
	If (paramisdefault(rot)==1	)
		wList=wavelist("MT*",";","")
	else
		wList=wavelist("rMT*",";","")
	endif
		
	String wName,wSC
	Variable nWaves
	Variable i
	Variable wx, wy, wz
	
	string LabelWName, rWName, thetaWName, phiWName
	
	If (paramisdefault(rot)==1	)
		LabelWName="SClabelWave"
		rWName="SCrWave"
		thetaWName="SCthetaWave"
		phiWName="SCphiWave"
	else
		LabelWName="rSClabelWave"
		rWName="rSCrWave"
		thetaWName="rSCthetaWave"
		phiWName="rSCphiWave"
	endif
	
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
	Print "Radial distance, r: mean",V_avg,"±",V_sdev,"nm. Median =",Statsmedian(rW)
	Wavestats /q thetaW
	Print "Polar angle, theta: mean",V_avg,"±",V_sdev,"radians. Median =",Statsmedian(thetaW)
	Wavestats /q phiW
	Print "Azimuthal angle, phi: mean" ,V_avg,"±",V_sdev,"radians. Median =",Statsmedian(phiW)
End

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
End

Function LowPoint()
	
	variable theta,phi //in radians
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
	WaveStats MatResWave
	Print "Rotating z by phi =",V_minRowLoc/(180/PI)," and then rotating y by theta = ",V_minColLoc/(180/PI)
	Straight(V_minRowLoc/(180/PI),V_minColLoc/(180/PI))
End

Function Originise(wList)	//Wavelist("rMT*",":","")
	String wList
	
	String wName,mW
	Variable i	//loop variable
	Variable ox,oy,oz
	
	For (i = 0; i < itemsInList(wList); i += 1)
		wName = StringFromList(i, wList)
		Wave /Z w = $wName
		ox = w[0][0]
		oy = w[0][1]
		oz = w[0][2]
		mW = "m"+ wName
		Duplicate /O $wName $mW
		Wave /Z w1 = $mW
		w1[][0] -=ox
		w1[][1] -=oy
		w1[][2] -=oz
	EndFor
End

Function MakePlane()	//find intersection of mrMTs with plane at z=100
	Wave rSCrWave,rSCthetaWave,rSCphiWave
	Variable i
	Variable n=numpnts(rSCrWave)
	Make /O /N=(n,2) rSCxyPlaneWave	//x y values in 2D wave
	Variable xb,yb,zb,t //xa,ya,za are 0,0,0 and t will be 100/xb
	
	for(i = 0;i < n;i +=1)
			xb=rSCrWave[i]*(sin(rSCthetaWave[i]))*(cos(rSCphiWave[i]))
			yb=rSCrWave[i]*(sin(rSCthetaWave[i]))*(sin(rSCphiWave[i]))
			zb=rSCrWave[i]*(cos(rSCthetaWave[i]))
			t=100/zb
			rSCxyPlaneWave[i][0]=xb*t
			rSCxyPlaneWave[i][1]=yb*t
	endfor
End

//---------------------------------------------------------------------------------------
// KillOrHideAnyWindow
// -------------------
//   'KillOrHideAnyWindow' kills any graph, table, layout, notebook, panel, or XOP window
//   
//   PARAMETERS:
//        - winMask:      bitmask of window types to kill
//                          - 0x0  kill everything possible
//                          - 0x01 graphs
//                          - 0x02 tables
//                          - 0x04 layouts
//                          - 0x10 notebooks
//                          - 0x40 panels
//                          - 0x1000 XOP target windows
//---------------------------------------------------------------------------------------
FUNCTION KillOrHideAnyWindow(winMask)
	variable                      winMask;
 
	variable                      i,n;
	variable                      all=0x1000+0x40+0x10+0x4+0x2+0x1;
	string                        theWins;
 
	winMask = !winMask ? all : winMask;
 
	theWins = winList("*",";","WIN:"+num2iStr(winMask & all));
	for(i=0,n=itemsInList(theWins,";") ; i<n ; i+=1)
		doWindow/K $stringFromList(i,theWins,";");
	endfor;
END
