/*=========================================================
Convert the xpt files into sas files
=========================================================*/
%include '/home/u44419478/TFL/program/general/xpt_2_sas.sas'; /* Adjust the path accordingly */

/* Call the macro */
%import_xpt_files(folder=/home/u44419478/TFL/xpt_data/, libname=mytfl, outpath=/home/u44419478/TFL/sas_data/);

options validvarname=upcase;

/*=========================================================
Programming for the Task
=========================================================*/
 
/*=========================================================
Read input data
=========================================================*/
 
data adtte01;
   set mytfl.adtte;
run;
 
proc sort data=adtte01;
   by paramcd trtan;
run;
 
 
/*=========================================================
Get Kaplan-Meier Estimate of Cumulative Incidence
=========================================================*/
 
/*----------------------------------------------------------
alphaqt option is used to specify the level of significance</br>
notice the usage of method= and conftype= options </br>
notice the usage of plots= options </br>
notice the request for failure plot along with atrisk numbers </br>
number of rows output into the dataset of ProductLimitEstimates is restricted by using timelist= option</br>
----------------------------------------------------------*/
proc lifetest data=adtte01
   alphaqt=0.05
   method=km
   plots=survival(failure atrisk=0 to 200 by 25 )
   timelist=(0 to 200 by 25)
   conftype=linear ;
 
   time aval*cnsr(1);
   strata trtan;
   ods output FailurePlot  = sur_fail ProductLimitEstimates=estimates;
run;
 
/*=========================================================
Select the Number of subjects at risk
=========================================================*/
 
data est(rename=(timelist=time stratum=stratumnum));
   set estimates(keep=stratum timelist left );
run;
 
/*=========================================================
Output blockplot timepoints and atrisk numebrs
=========================================================*/
 
proc sort data=sur_fail;
   by stratumnum time;
run;
 
/* Update the data preparation to include correct labels */
data new_survival (drop=j);
   merge est sur_fail ;
   length param_t $100 trt $20;
   by stratumnum time;
      do j = 0 to 200 by 25;
          if time = j  then do;
            blkrsk = put(left,3.);
            blkx   = time;
         end;
      end;
    trtan = stratumnum;
    param_t="parameter name";
    paramn=1;
    /* Assign correct treatment labels */
    if trtan = 1 then trt = 'Placebo';
    else if trtan = 2 then trt = 'Low Dose';
    else if trtan = 3 then trt = 'High Dose';
run;

/* Update the template */
proc template;
   define statgraph kmplot;
   dynamic x_var y_var1 y_var2;
    begingraph;
         entrytitle "Category = Time to Event" /
         textattrs=(size=9pt) pad=(bottom=20px);
 
         discreteattrmap name='colors' / ignorecase=true;
            value 'Placebo'  / lineattrs=(color=blue pattern=solid) markerattrs=(color=blue symbol=trianglefilled);
            value 'Low Dose' / lineattrs=(color=red  pattern=solid) markerattrs=(color=red symbol=circlefilled);
            value 'High Dose'/ lineattrs=(color=green pattern=solid) markerattrs=(color=green symbol=squarefilled);
         enddiscreteattrmap;
 
         discreteattrvar attrvar=gmarker var=trt attrmap='colors';
 
         layout overlay /
            xaxisopts=(Label="Time at Risk (days)"
               display=(tickvalues line label ticks)
               type=linear
               linearopts=(tickvaluesequence=(start=0 end=200 increment=25)
                    viewmin=0 viewmax=200))
            yaxisopts=(Label="Cumulative Incidence of Subjects with Event"
               type=linear linearopts=(viewmin=0 viewmax=1 tickvaluesequence=(start=0 end=1 increment=0.2)));
 
            /* Flip the plot by using 1-survival */
            StepPlot X=x_var Y=eval(1-y_var1) / primary=true Group=gmarker
               LegendLabel="Cumulative Incidence of Subjects with Event" NAME="STEP";
 
            scatterPlot X=x_var Y=eval(1-y_var2) / Group=gmarker markerattrs=(symbol=plus)
                 LegendLabel="Censored" NAME="SCATTER";
 
            /* Move legend up */
            Mergedlegend "STEP" "SCATTER" /
               location=inside halign=left valign=top across=1 valueattrs=(family="Arial" size=8pt)
               autoalign=(TopLeft Top TopRight);
 
         innermargin / align=bottom;
            axistable x=blkx value=blkrsk / class=gmarker colorgroup=gmarker
               display=(label) 
               labelattrs=(family="Arial" size=8pt)
               valueattrs=(family="Arial" size=8pt);
         endinnermargin;
         endlayout;
   endgraph;
   end;
run;



/*=========================================================
Set options for graph and save to RTF
=========================================================*/

ods listing close;
ods graphics on / border=off height=13cm width=14.72cm imagename="KM_CUMULATIVE_INCIDENCE" imagefmt=png;

footnote "&outputname.";
title "Cumulative Incidence Plot";
title2 "Safety Analysis Set";
 
ods rtf file="/home/u44419478/TFL/figure_output/KM_CUMULATIVE_INCIDENCE.rtf" style=csgpool01;

proc sgrender data=new_survival template=kmplot;
    dynamic x_var="time" y_var1="survival" y_var2="censored";
run;

ods rtf close;
ods listing;