/**************************************************************************
macro to simulate responses to from a polytomous Rasch model 

%simu(etafile=CML_eta, latfile=, outfile=, estimate=MLE)

etafile : file with item parameters. Output from, e.g., %rasch_CML.
latfile : file with person locations one line for each value (each 
	  kind of person), e.g. output-file OUT_latent from %rasch_CML.
outfile : name of the output file, one line for each person.
estimate: MLE or WLE (the default).

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
	into :maxmax
	from &etafile. 
quit;
%put maxmax is &maxmax.;
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
	exp(theta*_score+estimate)/sum(exp(theta*_score+estimate)) as prob
	from _out
	group by _item_name, theta;
quit;

proc sort data=_prob1;
	by theta _item_name;
run;
proc transpose data=_prob1(where=(prob ne .)) out=_prob1_t prefix=p;
	by theta _item_name;
	var prob;
run;
data _prob1_t;
	set _prob1_t;
	resp=rand('table' %do sc=1 %to %eval(&maxmax+1); ,p&sc. %end;)-1;
run;
data &outfile.;	
	merge 
	%do i=1 %to &_nitems.;
		_prob1_t(where=(_item_name="&&item&i") rename=(resp=&&item&i);
	%end;
	by theta;
run;
data &outfile;
	set _prob1_t;
	%do i=1 %to &_nitems.;
		if _item_name="&&item&i" then do;
			&&item&i=rand('table' %do sc=1 %to %eval(&&max&i+1); ,p&sc. %end;)-1;
		end;
		output;
	%end;
run;
options notes stimer;
%mend rasch_simu;

libname FIT 'p:\fit';
%rasch_simu(etafile=FIT.cml_eta,  ppfile=FIT.pp_CML_latent, estimate=MLE, outfile=teest);
