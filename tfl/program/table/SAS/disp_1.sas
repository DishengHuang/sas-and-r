/*=========================================================
Convert the xpt files into sas files
=========================================================*/
%include '/home/u44419478/TFL/program/general/xpt_2_sas.sas'; /* Adjust the path accordingly */

/* Call the macro */
%import_xpt_files(folder=/home/u44419478/TFL/xpt_data/, libname=mytfl, outpath=/home/u44419478/TFL/sas_data/);

options validvarname=upcase;


/*----------------------------------------------------------
Read input datasets
----------------------------------------------------------*/

/* Intend to Treat */
data adsl01;
    set mytfl.adsl;
    where ITTFL = "Y";
run;


/* Add the Total */
data adsl02;
	set adsl01;
	treatment = TRT01PN;
	output;
	
	treatment = 99;
	output;
run;

/*----------------------------------------------------------
Get the treatment total and create macro variable
----------------------------------------------------------*/

data dummy_trttotals;
	do treatment= 0, 54, 81, 99;
	   output;
	end;
run;

 
*------------------------------------------------------------------------------;
*get actual treatment totals;
*------------------------------------------------------------------------------;
 
proc freq data=adsl02;
	tables treatment /list missing out=trttotals_pre(rename=(count=trttotal) drop=percent);
run;
 
*------------------------------------------------------------------------------;
*merge actual and actual treatment totals;
*------------------------------------------------------------------------------;
 
data trttotals;
   merge dummy_trttotals(in=a)
         trttotals_pre(in=b);
   by treatment;
   if a and not b then trttotal=0;
run;

*------------------------------------------------------------------------------;
*create macro variables;
*------------------------------------------------------------------------------;
 
data _null_;
    set trttotals;
    call symputx(cats("trt",treatment),trttotal);
run;

*==============================================================================;
*get counts for table body;
*==============================================================================;
 
proc sql;
	create table counts01 as 
		select 1 as order, treatment, count(distinct usubjid) as count
		from adsl02
		where ITTFL = "Y"
		group by treatment
		
		union all corr
		
		select 2 as order, treatment, count(distinct usubjid) as count
		from adsl02
		where SAFFL = "Y"
		group by treatment
		
		union all corr
		
		select 3 as order, treatment, count(distinct usubjid) as count
		from adsl02
		where DISCONFL = "Y"
		group by treatment
		
		union all corr

		select 4 as order, treatment, count(distinct usubjid) as count
		from adsl02
		where DTHFL = "Y"
		group by treatment
		
		;
quit;


*==============================================================================;
*create dummy data and merge with actual counts;
*==============================================================================;
 
data dummy01;
    length label $200;
 
    order=1; label="Intent to Treat Set"; output;
    order=2; label="Safety Analysis Set"; output;
    order=3; label="Discontinuation Set"; output;
    order=4; label="Death Set"; output;
run;

 
data dummy02;
   set dummy01;
   
   do treatment=0, 54, 81, 99;
    output;
   end;
run;

proc sort data=counts01;
   by order treatment;
   where  ;
run;
 
data counts02;
   merge dummy02(in=a)
         counts01(in=b);
   by order treatment;
 
   if a and not b then count=0;
run;
 

*==============================================================================;
*calculate percentages;
*==============================================================================;
 
proc sort data=trttotals ;
   by treatment;
run;
 
proc sort data=counts02 ;
   by treatment;
run;
 
data counts03;
   merge counts02(in=a)
         trttotals(in=b);
   by treatment;
 
   if a;
run;
 
data counts04;
   set counts03;
 
   length cp $30;
 
   if count ne 0 then cp=put(count,3.)||" ("||put(count/trttotal*100,5.1)||")";
   else cp=put(count,3.);
run;

*==============================================================================;
*restructure the data to present treatments as columns;
*==============================================================================;
 
proc sort data=counts04;
   by order label;
run;
 
proc transpose data=counts04 out=counts05 prefix=trt  ;
   by order label;
   var cp;
   id treatment;
run;
 

footnote "&outputname.";
title "Summary for Analysis Sets";
title2 "Intend to Treat Set";
ods listing close;

ods rtf file="/home/u44419478/TFL/table_output/disp1.rtf" style=csgpool01;

proc report data = counts05 center headline headskip nowd split='~' missing style(report)=[just=center]
   style(header)=[just=center];
 
   column order label trt0 trt54 trt81 trt99;
 
   define order/order noprint;
 
   define label/width=30 " "  style(column)=[cellwidth=1.5in protectspecialchars=off] style(header)=[just=left];
 
   define trt0/"Placebo"    "(N=&trt0.)"   style(column)=[cellwidth=1.2in just=center] ;
   define trt54/"Low Dose"  "(N=&trt54.)"  style(column)=[cellwidth=1.2in just=center] ;
   define trt81/"High Dose" "(N=&trt81.)"  style(column)=[cellwidth=1.2in just=center] ;
   define trt99/"Total"     "(N=&trt99.)"  style(column)=[cellwidth=1.2in just=center] ;
 
run;
 
ods rtf close;
ods listing;


