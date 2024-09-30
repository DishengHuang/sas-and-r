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
 
/*----------------------------------------------------------
Read input datasets
----------------------------------------------------------*/
 
data adsl01;
    set mytfl.adsl;
    where saffl="Y";
run;
 
data adae01;
    set mytfl.adae;
    where saffl="Y" and trtemfl="Y";
run;


/*=========================================================
Create variable named 'treatment' to hold report level column groupings
=========================================================*/
 
data adae02;
    set adae01;
    treatment=trtan;
    output;
    treatment=99;
    output;
run;
 
data adsl02;
   set adsl01;
    treatment=trt01an;
    output;
    treatment=99;
    output;
run;

/*=========================================================
Get treatment totals into a dataset and into macro variables (for column headers)
=========================================================*/
 
proc sql;
   create table trttotals_pre as
      select treatment,
      count(distinct usubjid) as trttotal
      from adsl02
      group by treatment;
quit;

 
/*----------------------------------------------------------
Create dummy dataset for treatement totals
----------------------------------------------------------*/
 
data dummy_trttotals;
   do treatment=0,54,81,99;
      output;
   end;
run;
 
/*----------------------------------------------------------
Merge actual counts with dummy counts
----------------------------------------------------------*/
 
data trttotals;
   merge dummy_trttotals(in=a) trttotals_pre(in=b);
   by treatment;
   if trttotal=. then trttotal=0;
run;

/*----------------------------------------------------------
Macro variables
----------------------------------------------------------*/
data _null_;
    set trttotals;
    call symputx(cats("n",treatment),trttotal);
run;

/*=========================================================
Obtaining actual counts-for the table
=========================================================*/

/*----------------------------------------------------------
Subject level count- top row
----------------------------------------------------------*/
 
proc sql noprint;
   create table sub_count as
   select "Overall" as label length=200,
   treatment,
   count(distinct usubjid) as count
   from adae02
   group by treatment;
quit;

 
/*----------------------------------------------------------
SOC level counts
----------------------------------------------------------*/
 
proc sql noprint;
   create table soc_count as
      select aebodsys, treatment,
      count(distinct usubjid) as count
      from adae02
      group by aebodsys,treatment;
quit;
 
/*----------------------------------------------------------
Preferred term level counts
----------------------------------------------------------*/

proc sql noprint;
   create table pt_count as
      select aebodsys, aedecod, treatment,
      count(distinct usubjid) as count
      from adae02
      group by aebodsys, aedecod, treatment;
quit;

/*----------------------------------------------------------
Combine toprow, SOC, and PT level counts into single dataset
----------------------------------------------------------*/
 
data counts01;
   set sub_count soc_count pt_count;
run;


/*=========================================================
Create zero counts if an event is not present in a treatment
=========================================================*/
 
/*----------------------------------------------------------
Get all the available SOC and PT values
----------------------------------------------------------*/
 
proc sort data=counts01 out=dummy01(keep=aebodsys aedecod label) nodupkey;
   by aebodsys aedecod label;
run;
 
/*----------------------------------------------------------
Create a row for each treatment
----------------------------------------------------------*/
 
data dummy02;
   set dummy01;
   do treatment=0,54,81,99;
         output;
   end;
run;

/*=========================================================
Merge dummy counts with actual counts
=========================================================*/
 
proc sort data=dummy02;
   by aebodsys aedecod label treatment;
run;
 
 
proc sort data=counts01;
   by aebodsys aedecod label treatment;
run;
 
data counts02;
   merge dummy02(in=a) counts01(in=b);
   by aebodsys aedecod label treatment;
   if count=. then count=0;
run;

 
/*=========================================================
Calculate percentages
=========================================================*/
 
proc sort data=counts02;
   by treatment;
run;
 
proc sort data=trttotals;
   by treatment;
run;
 
data counts03;
   merge counts02(in=a) trttotals(in=b);
   by treatment;
   if a;
run;
 
data counts04;
   set counts03;
   length cp $30;
   if count ne 0 then cp=put(count,3.)||" ("||put(count/trttotal*100,5.1)||")";
   else cp=put(count,3.);
run;
 
 
/*=========================================================
Create the label column
=========================================================*/
 
data counts05;
   set counts04;
   if missing(aebodsys) and missing(aedecod) then label=label;
   else if not missing(aebodsys) and missing(aedecod) then label=aebodsys;
   else if not missing(aebodsys) and not missing(aedecod) then label= "      "||strip(aedecod);
run;

 
/*=========================================================
Transpose to obtain treatment as columns
=========================================================*/

proc sort data=counts05;
   by aebodsys aedecod label ;
run;
 
proc transpose data=counts05 out=counts06 prefix=trt;
   by aebodsys aedecod label;
   var cp;
   id treatment;
run;

/*=========================================================
Report generation
=========================================================*/

/*=========================================================
Report generation with page numbers
=========================================================*/

footnote j=l "Page \{thispage} of \{lastpage}" j=c "AE_BYSOC_BYDECOD";
title1 j=c f=Times h=16pt "Treatment-Emergent Adverse Events by Primary System Organ Class and Preferred Term";
title2 j=c f=Times h=16pt "Safety Analysis Set";

*Output rtf file*;
ods listing close;
options orientation=landscape nodate nonumber nobyline;
ods rtf file= "/home/u44419478/TFL/table_output/AE_BYSOC_BYAEDECOD.rtf" style=ars_sj1 startpage=Yes;
ods escapechar='\';

proc report data=counts06 center nowd headline headskip spacing=0 NOFS split='|' missing 
    style(report)={width=100% frame=hsides} style(header)={just=c} 
    style(column)={just=c verticalalign=bottom};
    
   columns aebodsys aedecod label  trt0 trt54 trt81 trt99;
   define aebodsys/ order noprint;
   define aedecod/order noprint;
   
   define label /"System Organ Class" "      Preferred Term"
   	style=[just=L cellwidth=2 in asis=on];
 	
   define trt0/"Placebo" "(N=%cmpres(&n0))" "  n   (%)" style=[just=c cellwidth=1 in asis=on];
   define trt54/"Low Dose" "(N=%cmpres(&n54))" "  n   (%)" style=[just=c cellwidth=1 in asis=on];
   define trt81/"High Dose" "(N=%cmpres(&n81))" "  n   (%)" style=[just=c cellwidth=1 in asis=on];
   define trt99/"Total" "(N=%cmpres(&n99))" "  n   (%)" style=[just=c cellwidth=1 in asis=on];  
 
   compute after aebodsys;
        line @1 "";
   endcomp;
 
run;
 
ods rtf close;
ods listing;

 


