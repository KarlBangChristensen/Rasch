/**************************************************************************
macro to simulate responses to from a polytomous Rasch model 

%simu(pfile=work.itempar, max=, thetafile=, outfile=)

pfile: this file contains the item parameters. Structure

		ITEM    NAME $   PAR1  PAR2 ... PAR'max'
		 1      item1    2.3   3.1  ...
		 2      item2    1.1   0.3  ...

thetafile: a file with the theta values. Structure

		THETA
		0.01
		0.09
		3.21
		:
outfile: is the name of the output file



CHANGE TO READ OUTPUT FROM OTHER MACROS!!

'ipar' type input

****************************************************************************/

%macro rasch_simu(pfile, max, thetafile, outfile);
*options nomprint nomlogic nosymbolgen nonotes nostimer;
*options mprint mlogic symbolgen notes stimer;

/* calculate number of items - save names as macro variables */
data _null_; set &pfile end=last;
array par (&max) par1-par&max;
call symput('_item'||trim(left(put(item,4.))), name);
do i=1 to &max; 
call symput ('_eta'||trim(left(put(item,4.)))||'_'||left(i),left(par(i))); 
end;
if last then call symput('_nitems',trim(left(put(item,4.))));
run;

data &outfile;
set &thetafile;
%do _it=1 %to &_nitems;
 _denom=1 %do _h=1 %to &max; +exp(theta*&_h+&&_eta&_it._&_h) %end;;
 _prob0=1/_denom; 
 %do _h=1 %to &max; _prob&_h=exp(theta*&_h+&&_eta&_it._&_h)/_denom; %end;
 &&_item&_it=rand('table',_prob0 %do _h=1 %to &max; ,_prob&_h %end;)-1;
%end;
drop _denom _prob0-_prob&max;
run;
options notes stimer;
%mend rasch_simu;
