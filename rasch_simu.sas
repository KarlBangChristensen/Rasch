/**************************************************************************
macro to simulate responses to from a dichotomous Rasch model 

%rasch_simu(etafile, ppfile, estimate, outfile)

etafile : file with item parameters. Output from, e.g., %rasch_CML.
ppfile  : file with person locations one line for each value (e.g. each person). Output from, e.g., %rasch_CML (OUT_latent).
estimate: name of the variable in the 'ppfile' that contains the person location estimates (default MLE)
outfile : name of the output file, one line for each person.

example:

%rasch_simu(etafile=FIT.cml_AMTS_eta, ppfile=pp2, estimate=WLE, outfile=simu);

****************************************************************************/

%macro rasch_simu(etafile, ppfile, outfile, estimate=MLE);
options nomprint nomlogic nosymbolgen nonotes nostimer;
*options mprint mlogic symbolgen notes stimer;
ods exclude all;
%let etafile=etafile;
%let ppfile=ppfile;
%let estimate=WLE; 
%let outfile=simu;

data _ppfile;
	set &ppfile.;
	theta=&estimate.;
	join=1;
run;
data _etafile;
	set &etafile;
	join=1;
run;
* number of items;
proc sql noprint;
	select count(unique(_item_no)) into :_nitems from _etafile;
quit;
%let _nitems=&_nitems.;
* number of response options, item names;
proc sql noprint;
	select max(_score) 
	into :maxmax
	from _etafile;
quit;
%let maxmax=&maxmax.;
proc sql noprint;
	create table _maxscores as select _item_no, max(_score) as max
	from _etafile 
	group by _item_no;
quit;
proc sql noprint;
	select max into :max1-:max&_nitems 
	from _maxscores;
quit;
proc sql noprint;
	create table _itemnames as select _item_no, _item_name
	from _etafile
	order by _item_no;
quit;
proc sql noprint;
	select unique(_item_name) 
	into :item1-:item&_nitems. 
	from _itemnames;
quit;
* all prob long format;
proc sql;
	create table _out as select a.*,
	b.theta
	from _etafile a left join _ppfile b
	on a.join=b.join;
quit;
proc sql;
	create table _prob1 as select *,
	exp(theta*_score+estimate)/sum(exp(theta*_score+estimate)) as p
	from _out
	group by _item_name, theta;
quit;
proc sort data=_prob1 out=_prob2;
	by theta _item_no;
run;
proc transpose data=_prob2(where=(prob ne .)) out=_wideprob prefix=p;
	by theta _item_name;
	var prob;
run;
data _wideprob;
	set _wideprob;
	resp=rand('table',p1,p2)-1;
run;
proc transpose data=_wideprob out=&outfile.;
	by theta;
	var resp;
	id _item_name;
run;
options notes stimer;
ods exclude none;
%mend rasch_simu;
