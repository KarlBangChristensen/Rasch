/**************************************************************************

PPAR: a SAS macro that can be used to estimate person parameters 

***************************************************************************

DATA: This data must contain the items (scored 0,1, .. ,'max') (the number of response categories 'max' can differ between items).  

ITEM_NAMES: This data set must contain the variables 

	item_name: 			  item names
	item_text (optional): item text for plots 
	max: 				  maximum score on the item
	group (optional): 	  specification of item groups (OBS: grouped items must have same maximum score) 

DATA_IPAR: The output data set from macro %rasch_ipar 

OUT: the name (default MML) given to output files

***************************************************************************

data set 'out_ppar' contains population parameter estimates
data set 'out_outdata' is a copy of the input data set containing an estimate of the location of each person

**************************************************************************/

%macro rasch_ppar(DATA, ITEM_NAMES, DATA_IPAR, OUT=PPAR); 

*options mprint notes;
options nomprint nonotes;
option spool;
ods exclude all; 
title ' ';

data _item_names_; set &item_names.; item_name = upcase(item_name); run; 

/*-- macro to sort items by ending digits (if any) --*/
%macro itemsort(ds, var);
%local ds var;  
proc sort data = &ds.; by &var.; run; 
data &ds.; 
 set &ds.; 
if anydigit(reverse(compress(&var.)))=1	 then item_sort = 1*substr(compress(&var.), length(compress(&var.))-notdigit(reverse(compress(&var.)))+2); 
								   		 else item_sort = _N_; 
run; 
proc sort data = &ds. /*out = &ds. (drop = item_sort)*/; by item_sort; run; 
%mend itemsort; 
%itemsort(_item_names_, item_name);

/*-- make macro variables again on the original data set --*/ 
data _data;
 set &data.;
 order=_n_;
run;

/*-- save number of respondents as macro variable --*/
data _NULL_; 
 set &data. end=final; 
  if final then call symput('N',trim(left(_N_))); 
run;

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
 if _N_=&_i. then do; 	call symput("_item&_i", item_name); 
 						call symput("_max&_i", max); 
						call symput("_text&_i", item_text);
 end;  
%end; 
run; 

%do _i=1 %to &_nitems.;
 %let _max&_i=&&_max&_i;
%end;

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

/*************************************************/
/* estimation of person parameters - MLE and WLE */
/*************************************************/

/*-- temporary data set with eta parameters --*/

%etatemp(DATA_IPAR=&DATA_IPAR., ITEM_NAMES=_item_names_);

/*-- store etas as macro variables --*/
%do _i=1 %to &_nitems.;
	%let _eta&_i.0=0;
	%do _h=1 %to &&_max&_i.;
		proc sql noprint;
			select estimate
				into :_eta&_i.&_h.
					from _eta_temp
						where _item_no=&_i. and _score=&_h.;
		quit; 
	%end;
%end;

/*-- make data set including item scores --*/
data _item_scores (rename = (_i = _score));
 format _item_score $%eval(&_l_item_name.+&_l_max.+1).;
 set _item_names;
  do _i=0 to _max;
	_item_score=strip(_item_name)||'|'||strip(_i);
	output;
  end;
run;

/*-- create variable that describes pattern of missing values, with a digit for each item (0=missing, 1=non-missing) --*/
data _miss1 (where=(totscore ne .));
 set _data;
 format miss_pattern $&_nitems..;
	totscore 	 = sum(&_item1.*(&_item1.^=.) %do _i=2 %to &_nitems.; ,&&_item&_i..*(&&_item&_i..^=.) %end;);
	miss_n   	 = sum((&_item1.=.)	%do _i=2 %to &_nitems.; ,(&&_item&_i=.)	%end;);
	miss_pattern = strip(put(1-(&_item1.=.),1.)) %do _i=2 %to &_nitems.; ||strip(put(1-(&&_item&_i..=.),1.)) %end;;
run;

/*-- count different patterns of missing values --*/
proc sql noprint;
	select count(distinct(miss_pattern)) 
	into :_miss
	from _miss1;
quit;

%let _miss=&_miss;

/*-- macro variables with distinct missingness patterns and number of missings --*/
proc sql noprint;
	select distinct(miss_pattern), miss_n
	into :_miss1 - :_miss&_miss, :_missn1 - :_missn&_miss
	from _miss1;
quit;

/*-- data containing codes for missingness patterns --*/
data _miss_patterns;
	format pattern $&_nitems..;
	%do _m=1 %to &_miss.;
		pattern = "&&_miss&_m";
		output;
	%end;
run;

/*-- calculate gamma-values for each missingness pattern --*/
%DO _m=1 %TO &_miss.;

%let _miss&_m=&&_miss&_m;

	data _item_names1 (where=(_miss='1'));
		format _item_name $&_l_item_name..;
		%do _i=1 %to &_nitems;
			_miss=substr("&&_miss&_m",&_i,1);
			_item_name="&&_item&_i";
			output;
		%end;
	run;

	proc sql;
	create table _item_names2 as select 
	b._item_name,
	b._max
	from _item_names1 a left join _item_names b
	on a._item_name=b._item_name;
	quit;

	/* information on items separately for each missingness pattern */

	proc sql noprint;
	select count(distinct(_item_name)), sum(_max), max(_max)
	into :_nitems_, :_maxscore_, :_max_max_
	from _item_names2;
	quit;

	%let _nitems_=&_nitems_.;

	proc sql noprint;
	select distinct(_item_name), _max
	into :_item_1-:_item_&_nitems_, :_max_1-:_max_&_nitems_
	from _item_names2;
	quit;
			
	data _item_names3;
	format _item_name $&_l_item_name.. _item_no_new &_l_item_no..;
	%do _i=1 %to &_nitems_.;
		_item_no_new="&_i."*1;
		_item_name="&&_item_&_i";
		_max="&&_max_&_i"*1;
		output;
	%end;
	run;

	proc sql;
	create table _item_names_miss&_m. as select 
	a.*,
	b._item_no
	from _item_names3 a left join _item_names b
	on a._item_name=b._item_name;
	quit;

/*-- gammas without item k --*/
%DO k=1 %TO &_nitems.; 
 %gamma(missindex=&_m., itemindex=&k., item_names=_item_names_miss&_m.);
%END; 

/*-- gammas with item k --*/
%gamma(missindex=&_m., item_names=_item_names_miss&_m.);

/*-- for each item i find highest possible sum score --*/
%do _i=1 %to &_nitems.;
proc sql noprint;
	select sum(_max)
		into :_cum_max_&_i.
			from _item_names_miss&_m.
		where _item_no_new<=&_i.;
quit;
%end;

data _null_; set _gamma&_m._&_nitems_.; call symput('_gamma'||strip(index2),gamma);	
run;

/*-- estimation of the person parameters (separately for each value of the total score) --*/
%DO _totscore=0 %TO &&_cum_max_&_nitems_..;
				
data _test; totscore=&_totscore.; run;

/*-- MLE --*/
proc nlmixed data=_test tech=newrap; 
 ods output parameterestimates=_mle&_m._&_totscore.;
 parms theta=0;
 _denom=0 %do _t=0 %to &&_cum_max_&_nitems_..; %if %symexist(_gamma&_t) %then %do; +exp(theta*&_t)*&&_gamma&_t %end; %end;;
/*- log likelihood for total score -*/
 logl=theta*&_totscore.-log(_denom); 
 model totscore ~ general(logl);
run;

/*-- WLE --*/
proc nlmixed data=_test tech=newrap; 
 ods output parameterestimates=_wle&_m._&_totscore.;
 parms theta=0;
 _denom=0 %do _t=0 %to &&_cum_max_&_nitems_..; %if %symexist(_gamma&_t) %then %do; +exp(theta*&_t)*&&_gamma&_t %end ;%end;;
/*- response probabilities and item means under the model -*/
 _testinfo=0 %do _i=1 %to &_nitems.; 
  %do _score=0 %to &&_max&_i;
	+(exp(&_score.*theta+&&_eta&_i.&_score.)/
	(0 %do _h=0 %to &&_max&_i;+exp(&_h.*theta+&&_eta&_i.&_h.) %end;
	))*
	(&_score.-(0 %do _l=0 %to &&_max&_i;
		+&_l.*(exp(&_l.*theta+&&_eta&_i.&_l.)/
		(0 %do _k=0 %to &&_max&_i; +exp(&_k.*theta+&&_eta&_i.&_k.) %end;
	))
	%end;
	))**2
  %end;
 %end;
 ;
/*- weighted log likelihood for total score -*/
 logl=theta*&_totscore.-log(_denom)+0.5*log(_testinfo); 
 model totscore ~ general(logl);
run;

%END;

/*-- put estimates of person locations in a single dataset, first MLE --*/
%DO _totscore=0 %TO &&_cum_max_&_nitems_..;

%if &_totscore.=0 %then %do; 
 data _mle&_m.; 
  set _mle&_m._0; 
  totscore=0; 
  pattern="&&_miss&_m";
  miss_n="&&_missn&_m";
 run;
%end;
%else %do;
data _mle&_m.; 
 set _mle&_m. _mle&_m._&_totscore. (in=a); 
  if a then do;
	totscore=&_totscore.*1;
	pattern="&&_miss&_m";
	miss_n="&&_missn&_m";
 end;	
run;
%end;
%END;
	
%if &_m.=1 %then %do; 
 data _mle_temp; 
  set _mle1;
 run;
%end;
%else %do;	
 data _mle_temp; 
  set _mle_temp _mle&_m.; 
 run;
%end;

/*-- put estimates of person locations in a single dataset, first WLE --*/
%DO _totscore=0 %TO &&_cum_max_&_nitems_..;

%if &_totscore.=0 %then %do; 
 data _wle&_m.; 
  set _wle&_m._0; 
   totscore=0; 
   pattern="&&_miss&_m";
   miss_n="&&_missn&_m";
 run;
%end;
%else %do;
data _wle&_m.; 
 set _wle&_m. _wle&_m._&_totscore. (in=a); 
  if a then do;
	totscore=&_totscore.*1;
	pattern="&&_miss&_m";
	miss_n="&&_missn&_m";
  end;	
run;
%end;
	
%END;

%if &_m.=1 %then %do; 
 data _wle_temp; 
  set _wle1;
 run;
%end;
%else %do;	
 data _wle_temp; 
  set _wle_temp _wle&_m.; 
 run;
%end;

%END;
	
/*-- create the data set '_mle' with person parameter estimates --*/
proc sql;
	create table _mle as select
		totscore label='Total score',
	 	estimate label='MLE',
		StandardError label='SE(MLE)',
		miss_n,
		pattern
	from _mle_temp
	order by pattern, totscore;
quit;

data _mle;
	set _mle;
	by pattern;
	if first.pattern or last.pattern then do; estimate=.; StandardError=.; end;
run;

proc sql;
	create table _outdat0 as select 
	a.*,
	b.estimate format=8.4,
	b.StandardError format=8.4
	from _miss1 a left join _mle b
	on a.miss_pattern=b.pattern and a.totscore=b.totscore
	order by order;
quit;

data _empty; 
 miss_n='0'; 
run;

data _mle; 
 set _mle _empty; 
run;

proc sort data=_mle; 
 by pattern;
run;

data _latent_mle (drop=pattern miss_n);
 set _mle (where=(miss_n='0'));
  by pattern;
   if first.pattern or last.pattern then do;
	estimate=.;
	StandardError=.;
   end;
run;

/*-- create the data set '_wle' with person parameter estimates --*/
proc sql;
	create table _wle as select
		totscore label='Total score',
		estimate label='WLE',
		StandardError label='SE(WLE)',
		miss_n,
		pattern
	from _wle_temp
		order by pattern, totscore;
quit;

proc sql;
	create table _outdat1 (drop=miss_pattern totscore miss_n) as select 
	a.*,
	b.estimate format=8.4 as EstimateWLE,
	b.StandardError format=8.4 as StandardErrorWLE
	from _outdat0 a left join _wle b
	on a.miss_pattern=b.pattern and a.totscore=b.totscore
	order by order;
quit;

proc sql noprint;
select count(*)
into :nrow
from _outdat1;
quit;

%let nrow=&nrow;

proc sql noprint;
select order, Estimate, StandardError, EstimateWLE, StandardErrorWLE
into :order1-:order&nrow., :MLE1-:MLE&nrow., :seMLE1-:seMLE&nrow., :WLE1-:WLE&nrow., :seWLE1-:seWLE&nrow.
from _outdat1;
quit;

data thet;
format MLE seMLE WLE seWLE 8.4;
%do i=1 %to &nrow.;
	order = &&order&i;
	MLE   = &&MLE&i;
	seMLE = &&seMLE&i;
	WLE   = &&WLE&i;
	seWLE = &&seWLE&i;
	 output;
%end;
run;

proc sql;
	create table _outdata as select a.*,
		b.MLE, b.seMLE, b. WLE, b. seWLE
	from _outdat1 a left join thet b
		on a.order=b.order;
quit;	

data &out._outdata; 
 set _outdata; 
  keep 	MLE seMLE WLE seWLE order 
		%do _i=1 %to &_nitems.; &&_item&_i %end;
		;	
run; 

data _empty; 
 miss_n='0'; 
run;

data _wle; 
 set _wle _empty; 
run;

proc sort data=_wle; 
 by pattern;
run;

data _latent_wle (drop=pattern miss_n);
 set _wle (where=(miss_n='0'));
  by pattern;
run;

/*-- Join data with the two types of person location estimates --*/
proc sql;
	create table &out._latent as select 
		a.totscore,
		a.estimate as mle,
		a.StandardError as mle_se,
		b.estimate as wle,
		b.StandardError as wle_se
	from _latent_mle a left join _latent_wle b
		on a.totscore=b.totscore
		where a.totscore^=.;
quit;

data &out._latent; 
 set &out._latent;  
run; 

/*******************************************/
/* end of person parameter estimation part */
/*******************************************/


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

proc datasets;
	delete %do _d=1 %to &_nd; &&_var&_d %end; beta eta_temp;
run;
quit;

option notes;
title ' ';

ods exclude all; 
%mend rasch_ppar;
