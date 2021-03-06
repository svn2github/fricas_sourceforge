/*
Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    - Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    - Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the
      distribution.

    - Neither the name of The Numerical ALgorithms Group Ltd. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#define _VIEWALONE_C
#include "axiom-c-macros.h"
#include "useproto.h"

#include <stdlib.h>
#include "viewAlone.h"

#include "all_alone.H1"

/************* global variables **************/

viewManager viewP;   /* note that in viewman, this is called viewports */

/* 3D stuff */
view3DStruct doView3D;

/* 2D stuff */
view2DStruct doView2D;
graphStruct      graphArray[maxGraphs];
graphStateStruct graphStateArray[maxGraphs];

/* tube stuff */
tubeModel doViewTube;

int         viewType;
int         filedes,ack;

char        errorStr[80];


int viewOkay  = 0;
int viewError = -1;

FILE *viewFile;
char filename[256];
char pathname[256];

/************* main program **************/

int main (int argc,char *argv[])
{
        printf("viewAlone called with argc=%d\n",argc);
        printf("viewAlone called with argv[1]=%s\n",argv[0]);
        printf("viewAlone called with argv[2]=%s\n",argv[1]);
/******** Open files and Figure out the viewport type ********/

        sprintf(filename,"%s%s",argv[1],".VIEW/data");
        if((viewFile = fopen(filename,"r")) == NULL ) {
         
           sprintf(filename,"%s%s",argv[1],"/data");
           if((viewFile = fopen(filename,"r")) == NULL ){
             fprintf(stderr,"Error: Cannot find the file %s%s or %s%s\n",
                  argv[1],".VIEW/data",argv[1],"/data");
             exit(-1);
           }
           sprintf(pathname,"%s",argv[1]);
        }
        else{
             sprintf(pathname,"%s%s",argv[1],".VIEW");
           }
        fscanf(viewFile,"%d\n",&viewType);
        printf("filename = %s\n",filename);
        printf("viewType = %d\n",viewType);
        switch (viewType) {

        case view3DType:
        case viewTubeType:
                printf("calling spoonView3D\n");
                spoonView3D(viewType);
                break;

        case view2DType:
                printf("calling spoonView2D\n");
                spoonView2D();
                break;

        }  /* switch */
      printf("The first number in the file, %d, called the viewType, not a valid value. It must be a number in the range of [1..4]\n",viewType);
      return(0);
      }
