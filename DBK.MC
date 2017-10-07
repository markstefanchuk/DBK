/*----------------------------------------------------------------------+
|																		|
| name		dbk.mc Rectangular Duct Breaks								|
|																		|
| Revision:	01.00.00.01													|
| Date:		1999														|
|																		|
|																		|
| Copyright (c) 1998-2017, Mark Stefanchuk, The Phocaz Group, LLC   	|
| All rights reserved.													|
|																		|
| Redistribution and use in source and binary forms, with or without 	|
| modification, are permitted provided that the following conditions 	|
| are met:																|
|         																|
|   Redistribution of source code must retain the above copyright 		|
|   notice, this list of conditions and the following disclaimer. 		|
|              															|
|   Redistribution in binary form must reproduce the above copyright 	|
|   notice, this list of conditions and the following disclaimer in 	|
|   the documentation and/or other materials provided with the 			|
|   distribution.														|
|           															|
|   Neither name of Mark Stefanchuk, The Phocaz Group, LLC nor the	| 
|   names of its contributors may be used to endorse or promote			|
|   products derived from this software without specific prior          |
|   written permission.													|
|            															|
| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 	|
| "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT 		|
| NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS |
| FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS| 
| OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 		|
| SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 		|
| LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF 		|
| USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 		|
| AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,| 
| OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 	|
| OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 		|
| OF SUCH DAMAGE.														|
|																		|
+----------------------------------------------------------------------*/
/*----------------------------------------------------------------------+
|                                   									|
|   Include Files                               						|
|                                  										|
+----------------------------------------------------------------------*/
#include    <mdl.h>
#include    <tcb.h>
#include    <cexpr.h>
#include    <dlogitem.h>
#include    <cmdlist.h>
#include    <refernce.h>
#include    <rscdefs.h>
#include    <dlogman.fdf>
#include    <mdlerrs.h>
#include    <msstrngl.fdf>
#include    <stdio.h>
#include    <basetype.h>
#include    <msdefs.h>
#include    <userfnc.h>
#include    <dlogids.h>
#include    <global.h>
#include    <mselems.h>
#include    <accudraw.h>

#include    "dbk.h"
#include    "dbkcmd.h"

#include 	"fdf.fdf"

#define     ptStack statedata.dPointStack

/*----------------------------------------------------------------------+
|                                   									|
|   Private Global Variables                      						|
|                                  										|
+----------------------------------------------------------------------*/
DialogBox       *dbm;  

/*----------------------------------------------------------------------+
|                                   									|
|   Function Declarations	                      						|
|                                  										|
+----------------------------------------------------------------------*/
Public void dbk_breakStart ( void );

/*----------------------------------------------------------------------+
|																		|
| rMatrixFrom2PtsAndView			 									|
|																		|
+----------------------------------------------------------------------*/
Private int rMatrixFrom2PtsAndView
(
RotMatrix   *rMatrixP,
Dpoint3d    *originP,
Dpoint3d    *xAxisP,
int	     	view
)
{
    //double	length;
    Dpoint3d	vecs[3];
    RotMatrix	viewMatrix;

    mdlRMatrix_fromView (&viewMatrix, view, TRUE);
    mdlRMatrix_getRowVector (&vecs[2], &viewMatrix, 2);

    if (mdlVec_computeNormal (&vecs[0], xAxisP, originP) < fc_epsilon)
	return ERROR;

    mdlVec_crossProduct (&vecs[1], &vecs[2], &vecs[0]);
    if (mdlVec_normalize (&vecs[1]) < fc_epsilon)
	return ERROR;

    mdlVec_crossProduct (&vecs[2], &vecs[0], &vecs[1]);
    mdlRMatrix_fromRowVectors (rMatrixP, &vecs[0], &vecs[1], &vecs[2]);

    return SUCCESS;
}

/*----------------------------------------------------------------------+
|                                   									|
|   dbk_generateVanes		                      						|
|                                  										|
+----------------------------------------------------------------------*/
Private void dbk_generateVanes
(
Dpoint3d    *ptP,
int	    view,
int	    drawMode
)
    {
    MSElementDescr *elmDescr = NULL;
    MSElement	elem, elemOne, elemTwo, elemThree, elemFour, elemFive;
    MSElement   constrArc1, constrArc2;
    RotMatrix	rMatrix;
    //Dpoint3d	ctr,
    Dpoint3d	breakPt1,
                breakPt2,
                points[2],
                newPts[2],
                startEndPts1[2],
                startEndPts2[2],
                normVec;
    double	length;

    points[0] = ptStack[0];
    points[1] = *ptP;

    mdlVec_computeNormal (&normVec, ptP, &ptStack[0]); 
    length = mdlVec_distance (&ptStack[0], ptP);
    mdlVec_projectPoint (&breakPt1, &ptStack[0], &normVec, 0.75*(length/2));
    mdlVec_projectPoint (&breakPt2, &breakPt1, &normVec, length/4);

    if	(rMatrixFrom2PtsAndView (&rMatrix, &ptStack[0], ptP, view)
		!= SUCCESS)
	return;

    mdlRMatrix_invert (&rMatrix, &rMatrix);

    newPts[0] = points[0];
    newPts[1] = breakPt1;
    mdlLine_create (&elemOne, NULL, newPts);
    
    newPts[0] = breakPt2;
    newPts[1] = *ptP;
    mdlLine_create (&elemTwo, NULL, newPts);

    // use construction arcs to get points on Z shape
    mdlArc_create (&constrArc1, NULL, &breakPt1, length/6, length/6,
                      &rMatrix, fc_piover3, fc_pi);
    mdlArc_extract (startEndPts1, NULL, NULL, NULL, NULL, NULL, NULL, &constrArc1);

    newPts[0] = breakPt1;
    newPts[1] = startEndPts1[0];
    mdlLine_create (&elemThree, NULL, newPts);

    mdlArc_create (&constrArc2, NULL, &breakPt2, length/6, length/6,
                      &rMatrix, (fc_piover3 + fc_pi), fc_pi);
    mdlArc_extract (startEndPts2, NULL, NULL, NULL, NULL, NULL, NULL, &constrArc2);

    newPts[0] = startEndPts1[0];
    newPts[1] = startEndPts2[0];
    mdlLine_create (&elemFour, NULL, newPts);

    newPts[0] = breakPt2;
    newPts[1] = startEndPts2[0];
    mdlLine_create (&elemFive, NULL, newPts);

    mdlCell_create (&elem, NULL, ptP, FALSE);
    mdlElmdscr_new (&elmDescr, NULL, &elem);
       
    mdlElmdscr_appendElement (elmDescr, &elemOne);
    mdlElmdscr_appendElement (elmDescr, &elemTwo);
    mdlElmdscr_appendElement (elmDescr, &elemThree);
    mdlElmdscr_appendElement (elmDescr, &elemFour);
    mdlElmdscr_appendElement (elmDescr, &elemFive);

    mdlElmdscr_display (elmDescr, 0, drawMode);

    if (drawMode == NORMALDRAW)
           mdlElmdscr_add (elmDescr);

    mdlElmdscr_freeAll (&elmDescr);
    }

/*----------------------------------------------------------------------+
|                                   									|
|   dbk_breakLastPoint		                      						|
|                                  										|
+----------------------------------------------------------------------*/
Private void dbk_breakLastPoint
(
DPoint3d *ptP,
int      view
)
    {
    double radius;

    dbk_generateVanes (ptP, view, NORMALDRAW);
    dbk_breakStart ();

    // get length of the pipe break just placed
    radius = mdlVec_distance (&ptStack[0], ptP);

    mdlState_setAccudrawContext  
		      ( ACCUDRAW_SetOrigin | ACCUDRAW_SetDistance, &ptStack[0],
		        NULL, &radius, NULL, NULL );     
    }

/*----------------------------------------------------------------------+
|                                   									|
|   dbk_breakFirstPoint		                      						|
|                                  										|
+----------------------------------------------------------------------*/
Private void dbk_breakFirstPoint
(
Dpoint3d *ptP,
int      view
)
    {
    ptStack[0] = *ptP;

    mdlState_setFunction (STATE_DATAPOINT, dbk_breakLastPoint); 
    mdlState_setFunction (STATE_COMPLEX_DYNAMICS, dbk_generateVanes); 
    
    mdlState_setAccudrawContext
		      (ACCUDRAW_SetModeRect, NULL, NULL, NULL, NULL, NULL);
    }

/*----------------------------------------------------------------------+
|                                   									|
|   dbk_breakStart		 	                     						|
|                                  										|
+----------------------------------------------------------------------*/
Public void dbk_breakStart ()

cmdNumber	CMD_DBK
    {

    mdlState_startPrimitive (dbk_breakFirstPoint, dbk_breakStart, 
                             NULL, NULL);
    }

/*----------------------------------------------------------------------+
|                                   									|
|   main				 	                     						|
|                                  										|
+----------------------------------------------------------------------*/
int main ()
    {
    RscFileHandle   rfHandle;

    mdlResource_openFile (&rfHandle, NULL, FALSE);

    if (mdlParse_loadCommandTable (NULL) == NULL)
	mdlOutput_rscPrintf (MSG_ERROR, NULL, 0, 4);

    mdlCurrTrans_begin ();

    return  SUCCESS;
    }
