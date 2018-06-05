/**************************************************************************
macro to simulate responses to from a polytomous Rasch model 

%simu(etafile=CML_eta, ppfile=, outfile=, estimate=MLE)

etafile : file with item parameters. Output from, e.g., CML.
ppfile  : file with person locations one line for each value (each 
		  kind of person). 
outfile : name of the output file, one line for each person.
estimate: MLE (the default) or WLE

****************************************************************************/

%macro rasch_simu(etafile, ppfile, outfile, estimate=MLE);
*options nomprint nomlogic nosymbolgen nonotes nostimer;
*options mprint mlogic symbolgen notes stimer;
options mprint;
*;
data &ppfile.;
	set &ppfile.;
	theta=&estimate.;
run;
* number of items;
proc sql noprint;
	select count(unique(_item_no)) into :_nitems from &etafile.;
quit;
%let _nitems=&_nitems.;
* number of response options, item names;
proc sql noprint;
	select max(_score) 
	into :max1-:max&_nitems 
	from &etafile. 
	order by _item_no;
quit;
proc sql noprint;
	select unique(_item_name) 
	into :item1-:item&_nitems. 
	from &etafile. 
	group by _item_no
	order by _item_no;
quit;
* simulate;
data &etafile;
	set &etafile;
	join=1;
run;
data &ppfile;
	set &ppfile;
	join=1;
run;
proc sql;
	create table _out as select a.*,
	b.theta
	from &etafile. a left join &ppfile. b
	on a.join=b.join;
quit;
proc sql;
	create table _prob1 as select *,
	exp(theta*score+eta)/sum(exp(theta*score+eta)) as prob
	from _out
	group by item, theta;
quit;
proc sort data=_prob1;
	by item theta;
run;
proc transpose data=_prob1 out=_prob1_t;
	by item theta;
	id score;
	var prob;
run;
data &outfile;
	set _prob1_t;
	%do i=1 %to &_nitems.;
		if item="&&item&i" then do;
			resp=rand('table' %do score=0 %to &&max&i; ,_&score. %end;)-1;
		end;
	%end;
run;
options notes stimer;
%mend rasch_simu;

* libname FIT 'p:\fit';
* %rasch_simu(etafile=FIT.cml_eta,  ppfile=FIT.pp_CML_outdata, estimate=MLE, outfile=teest);
