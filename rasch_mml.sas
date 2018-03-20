/**************************************************************************

MML: a SAS macro that can be used to estimate item parameters 

***************************************************************************

DATA: This data must contain the items (scored 0,1, .. ,'max') (the number of response categories 'max' can differ between items).  

ITEM_NAMES: This data set must contain the variables 

	item_name: 			  item names
	item_text (optional): item text for plots 
	max: 				  maximum score on the item
	group (optional): 	  specification of item groups (OBS: grouped items must have same maximum score) 

OUT: the name (default MML) given to output files

QPOINTS: number of quadrature points to be used in the numeric integration

***************************************************************************

data set 'out_ipar' contains the item parameters (using PCM parametrization)

**************************************************************************/

%macro rasch_mml(DATA, ITEM_NAMES, OUT=MML, LAPLACE=NO); 

options nomprint nonotes;
option spool;
ods listing close; ods html close; 
title ' ';

/*-- data from previous macro --*/
data _data; 	   set data; run; 
data _item_names_; set item_names; run; 

/*-- save number of respondents as macro variable --*/
data _NULL_; 
 set &data. end=final; 
  if final then call symput('N',trim(left(_N_))); 
run;

/*-- make a numbering of the grouped items - find the maximum length of values - max(max) is the highest number of response categories --*/
proc sql noprint;
	select count(distinct(item_name)), sum(max), max(max), max(length(item_name)), max(length(item_text)), 
		length(strip(put(count(distinct(item_name)),5.))),
		length(strip(put(max(max),5.)))
			into :_nitems, :_maxtotscore, :_max_max, :_l_item_name, :_l_item_text, :_l_item_no, :_l_max
	from _item_names_;
quit;

%let _nitems=&_nitems.;

proc sort data = _item_names_ out = _item_names_unique nodupkey; by item_name; run; 
proc sort data = _item_names_unique; by item_sort; run; 

data _NULL_; 
 set _item_names_unique;
%do _i=1 %to &_nitems.; 
 if _N_=&_i. then do; 	
  call symput("_item&_i", item_name); 
  call symput("_max&_i", max); 
  call symput("_text&_i", item_text);
 end;  
%end; 
run; 

/*-- make new data set with item info - make format for a given variable by finding maximum length of the corresponding values --*/
data _item_names;
 format _item_no &_l_item_no.. _item_name $&_l_item_name.. _max &_l_max.. _item_text $&_l_item_text..;
%do _i=1 %to &_nitems.;
	_item_no   = "&_i."*1;
	_item_name = "&&_item&_i";
	_max       = "&&_max&_i"*1;
	_item_text = "&&_text&_i";
	output;
%end;
run;

/*-- make data set including item scores --*/
data _item_scores (rename=(_i=_score));
format _item_score $%eval(&_l_item_name.+&_l_max.+1).;
set _item_names;
do _i=0 to _max;
	_item_score=strip(_item_name)||'|'||strip(_i);
	output;
end;
run;

/*******************************************/
/* start of item parameter estimation part */
/*******************************************/

/*-- data set with one line for each item response (more than one line for each person) --*/
data _new_; 
 format value &_l_max.. item $&_l_item_name..;
 set _data; 
  %do _i=1 %to &_nitems.; 
	 item   = "&&_item&_i"; 
	 value  = &&_item&_i; 
	 person = mod(_N_,&N.); if person = 0 then person = &N.; *- make up for stacked data (when groupings); 
	output; 
  %end;
run;

data _new; 
set _new_; 
%do _i=1 %to &_nitems.; 
 if value = . and miss&_i. = . then delete;
%end; 
drop miss:;
run; 

/*-- sort by subject (= person) to prepare data for random effects in proc nlmixed --*/
proc sort data = _new; by person; run; 

/*-- direct output to files --*/
ods output nlmixed.parameterestimates	= _pe;
ods output nlmixed.additionalestimates	= _ae;
ods output nlmixed.fitstatistics	= _logl;

/*-- estimation of item parameters - numerical maximization using PROC NLMIXED --*/

OPTIONS MPRINT;
%let LAPLACE=&LAPLACE;
%if %trim(%upcase(&LAPLACE))='NO' %then %do;
proc nlmixed data=_new;
%end;
%else %do;
proc nlmixed data=_new QPOINTS=1; 
%end;
 PARMS %do _i=1 %to &_nitems.; %do _h=1 %to &&_max&_i; eta&_i._&_h.=0, %end; %end; sigma=1; *- initialize values of estimates to 0;
 BOUNDS 0<sigma; *- restriction on the residual standard error;
*-- the likelihood; *- denominator ~ normalizing constant;
 _theta=0+epsilon;
 %do _i=1 %to &_nitems.; 
  _denom=1 %do _k=1 %to &&_max&_i; +exp(&_k.*_theta+eta&_i._&_k.) %end;;
  if item="&&_item&_i" and value=0 then ll=-log(_denom); *- eta parameter is 0 when score is 0, so numerator is 1; 
  %do _h=1 %to &&_max&_i; 
	if item="&&_item&_i" and value=&_h then ll=(&_h.*_theta+eta&_i._&_h.)-log(_denom);
  %end; 
 %end;
 MODEL value~general(ll);
 RANDOM epsilon ~ normal(0,sigma*sigma) subject=person;
*-- estimate thresholds (partial credit model parametrization of item parameters);
 %do _i=1 %to %eval(&_nitems.-1); 
  %do _h=1 %to &&_max&_i; 
	ESTIMATE "&&_item&_i|&_h." -eta&_i._&_h. %if &_h.>1 %then %do; +eta&_i._%eval(&_h.-1) %end;; 
  %end; 
 %end;
 %do _h=1 %to &&_max&_nitems; 
	ESTIMATE "&&_item&_nitems..|&_h." -eta&_nitems._&_h. %if &_h.>1 %then %do; +eta&_nitems._%eval(&_h.-1) %end;; 
 %end; 
run;

OPTIONS NOMPRINT;

/*-- create data set with item parameter estimates --*/
proc sql noprint; 
	create table _ipar (rename = (item_name1 = item_name)) as 
		select 	i.item_sort,
				cats(compress(i.item_name0),'|',substr(j.label,index(j.label,'|')+1)) length = 15 as item_name1, 
				substr(substr(j.label,1,index(j.label,'|')-1),anydigit(substr(j.label,1,index(j.label,'|')-1))) as group, 
				j.estimate, 
				j.standarderror,
				j.Lower as LowerCL, 
				j.Upper as UpperCL
			from _item_names_ i left join _ae j
				on i.item_name = substr(j.label,1,index(j.label,'|')-1)
					order by input(cat(input(substr(i.item_name0,anydigit(i.item_name0)),5.),input(substr(j.label,index(j.label,'|')+1),5.)),10.); 
quit; 

proc sort data = _ipar out = &out._ipar (drop = item_sort group); by item_sort; run; 

/*-- create data set with population parameter estimates --*/
data &out._ppar; 
 set _pe; 
 if parameter='mu' or parameter='sigma';
run;

/*-- create file with log likelihood value --*/
data &out._logl; set _logl; 
 if Descr='-2 Log Likelihood'; 
run;


/*****************************************/
/* end of item parameter estimation part */
/*****************************************/

/******************************/
/* delete temporary data sets */
/******************************/

ods output Datasets.Members=_mem;

proc datasets; 
run; 
quit;

data _mem; 
 set _mem; 
  _underscore=substr(name,1,1); 
run;

data _mem; 
 set _mem(where=(_underscore='_')); 
run;

data _null_; 
 set _mem end=final; 
  if final then call symput('_nd',trim(left(_N_))); 
run;

%put clean-up deleting &_nd temporary data sets;

proc sql noprint;
	select distinct(name)
	into :_var1-:_var&_nd.
	from _mem;
quit;

/*
proc datasets;
	delete %do _d=1 %to &_nd; &&_var&_d %end;;
run; 
quit;
*/
%put but not really;

option notes;
title ' ';

ods html;

%mend rasch_mml;
