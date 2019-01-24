/**************************************************************************
macro to simulate responses to from a dichotomous Rasch model 

%rasch_simu(etafile, ppfile, estimate, outfile)

etafile : file with item parameters. Output from, e.g., %rasch_CML.
ppfile  : file with person locations one line for each value (e.g. each person). Output from, e.g., %rasch_CML (OUT_latent).
idvar   : name of the variable in the 'ppfile' that contains the person id
estimate: name of the variable in the 'ppfile' that contains the person location estimates (default MLE)
outfile : name of the output file, one line for each person (each value of 'idvar').

example:

%rasch_simu(etafile=FIT.cml_AMTS_eta, 
			ppfile=FIT.pp_AMTS_CML_outdata, 
			idvar=order,
			estimate=WLE, 
			outfile=simu);

****************************************************************************/

%macro rasch_simu(etafile, ppfile, idvar, estimate, outfile);
options nomprint nomlogic nosymbolgen nonotes nostimer;
*options mprint mlogic symbolgen notes stimer;
ods exclude all;

%let etafile=&etafile.;
%let ppfile=&ppfile.;
%let idvar=&idvar.;
%let estimate=&estimate.; 
%let outfile=&outfile.;

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
	b.*
	from _etafile a left join _ppfile b
	on a.join=b.join;
quit;
proc sql;
	create table _prob1 as select *,
	exp(theta*_score+estimate)/sum(exp(theta*_score+estimate)) as p
	from _out
	group by _item_name, &idvar.;
quit;
proc sort data=_prob1 out=_prob2;
	by &idvar. _item_no;
run;
proc transpose data=_prob2(where=(p ne .)) out=_wideprob prefix=p;
	by &idvar. _item_no;
	var p;
run;
data _wideprob;
	set _wideprob;
	%do _i=1 %to &_nitems.;
		if (_item_no=&_i.) then resp=rand('table'
		%do _k=1 %to %eval(&&max&_i+1); ,p&_k %end;
		)-1;
	%end;
run;
proc transpose data=_wideprob prefix=simu out=&outfile.;
	by &idvar.;
	var resp;
	id _item_no;
run;
options notes stimer;
ods exclude none;
%mend rasch_simu;
