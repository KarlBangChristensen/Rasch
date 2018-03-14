/**************************************************************************

rasch_itemfit: 

a SAS macro that can be used to calculate item fit statistics
using the unconditional residual 

Y_iv=X_iv-E_iv 

used in RUMM and WINSTEPS. Note that rasch_itemcfit is likely 
to be a better choice

Uses the macro rasch_etatemp

***************************************************************************

DATA: The data - contains the items scored 0,1, .. ,'max' 
(the number of response categories 'max' can differ between items).  

ITEM_NAMES: This data set must contain the variables 

	item_name: 			  item names
	item_text (optional): item text for plots 
	max: 				  maximum score on the item
	group (optional): 	  specification of item groups (OBS: grouped items must have same maximum score) 

DATA_IPAR: The output data set from macro %rasch_ipar, &out_ipar 

DATA_POPPAR: The output data set from macro %rasch_ppar, &out_outdata

NCLASS: The number of class intervals

OUT: the name (default MML) given to output files

***************************************************************************

data set 'out_fit' contains the item infit and outfit

**************************************************************************/

%macro rasch_itemfit(DATA, ITEM_NAMES, DATA_IPAR, DATA_POPPAR, NCLASS, OUT=MML); 

%let nclass=&nclass;

*options mprint notes;
options nomprint nonotes;
option spool;
ods listing close; ods html close; 
title ' ';

data _item_names_; 
	set &item_names.; 
	item_name = upcase(item_name); 
run; 

/*-- macro to sort items by ending digits (if any) --*/
%macro itemsort(ds, var);
	%local ds var;  
	proc sort data = &ds.; 
		by &var.; 
	run; 
	data &ds.; 
 		set &ds.; 
		if anydigit(reverse(compress(&var.)))=1	then 
			item_sort = 1*substr(compress(&var.), length(compress(&var.))-notdigit(reverse(compress(&var.)))+2); 
		else item_sort = _N_; 
	run; 
	proc sort data = &ds. /*out = &ds. (drop = item_sort)*/; 
		by item_sort; 
	run; 
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
	select 
		count(distinct(item_name)), 
		sum(max), 
		max(max), 
		max(length(item_name)), 
		max(length(item_text)), 
		length(strip(put(count(distinct(item_name)),5.))),
		length(strip(put(max(max),5.)))
	into 
		:_nitems, 
		:_maxtotscore, 
		:_max_max, 
		:_l_item_name, 
		:_l_item_text, 
		:_l_item_no, 
		:_l_max
	from _item_names_; 
quit;

%let _nitems=&_nitems.;

proc sort data = _item_names_ out = _item_names_unique nodupkey; 
	by item_name; 
run; 
proc sort data = _item_names_unique; 
	by item_sort; 
run; 

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

%do _i=1 %to &_nitems.;
	%let _max&_i=&&_max&_i;
%end;

/*-- make new data set with item info - make format for a given variable by finding maximum length of the corresponding values --*/
data _item_names;
	format 
		_item_no &_l_item_no.. 
		_item_name $&_l_item_name.. 
		_max &_l_max.. 
		_item_text $&_l_item_text..;
	%do _i=1 %to &_nitems.;
		_item_no   = "&_i."*1;
		_item_name = "&&_item&_i";
		_max       = "&&_max&_i"*1;
		_item_text = "&&_text&_i";
	output;
	%end;
run;

data _item_names_; 
	set _item_names; 
	_item_no = _N_; 
	item_name = _item_name;
run; 

/*-- data with item parameter --*/

%etatemp(DATA_IPAR=&DATA_IPAR., ITEM_NAMES=_item_names_);

data &DATA_POPPAR.; 
	set &DATA_POPPAR.;
	order = _N_; 
run; 


proc sql noprint;
 	select count(distinct(MLE))
	into :n_theta
	from &DATA_POPPAR.
	where MLE ne .;
quit;
%let n_theta=&n_theta;

proc sql noprint;
	select distinct(MLE)
	into :theta_esti1 -:theta_esti&n_theta
	from &DATA_POPPAR.
	where MLE ne .;
quit;

data _prob1;
	set _eta_temp;
	%do _i=1 %to &n_theta.;
		theta_esti=&&theta_esti&_i;
	output;
	%end;
run;

data _prob2; 
	set _prob1; 
	MLE = theta_esti*1;
run; 

proc sql;
	create table _prob3 as select 
		*,
		exp(_score*MLE+estimate)/(sum(exp(_score*MLE+estimate))) as _prob
	from _prob2
	group by _item_no, MLE
	order by _item_no, _score, MLE;
quit;

proc sql;
  	create table _mean_var as select distinct 
	_item_no,
	MLE,
	sum(_score*_prob) as _mean,
	sum((_score**2)*_prob)-(sum(_score*_prob))**2 as _var
	from _prob3 
	group by _item_no, MLE
	order by _item_no, MLE;
quit;

proc sql;
  	create table mean_var2 as select distinct 
	_item_no,
	MLE,
	sum(_score*_prob) as _EX,
	sum((_score**2)*_prob) as _EX2,
	sum((_score**3)*_prob) as _EX3,
	sum((_score**4)*_prob) as _EX4,
	sum((_score**2)*_prob)-(sum(_score*_prob))**2 as _VX
	from _prob3 
	group by _item_no, MLE
	order by _item_no, MLE;
quit;

proc sql;
  	create table _prob4 as select 
	estimate,
	_score,
	_item_no,
	MLE,
	_prob,
	sum(_score*_prob) as _mean,
	sum((_score**2)*_prob)-(sum(_score*_prob))**2 as _var
	from _prob3 
	group by _item_no, MLE
	order by _item_no,_score, MLE;
quit;

proc sql;
  	create table _prob5 as select unique
	_item_no,
	MLE,
	_mean,
	_var,
	sum((_score-_mean)**4*_prob) as _kurt,
	_var**2 as _var2
	from _prob4 
	group by _item_no, MLE
	order by _item_no, MLE;
quit;

* kurtosis;
data %do _i=1 %to &_nitems.; _kurt&_i.(keep=MLE _kurt&_i.) %end;;
	set _prob5;
	%do _i=1 %to &_nitems.;
		if _item_no=&_i. then do; 
			_kurt&_i.=_kurt;
			output _kurt&_i.; 
		end;
	%end;
run;

* variances and squared variances;
data %do _i=1 %to &_nitems.; _var&_i.(keep=MLE _v_&_i. _v2_&_i.) %end;;
	set _prob5;
	%do _i=1 %to &_nitems.;
		if _item_no=&_i. then do;
			_v_&_i.=_var;
			_v2_&_i.=_var2;
			output _var&_i.; 
		end;
	%end;
run;

* data matrix with residuals;
%do _i=1 %to &_nitems.;
	%if &_i.=1 %then %do;
		proc sql;
			create table _z1 as select 
				a.*,
				b._mean as _mean1 format=8.6,
				b._var as _var1 format=8.6
			from &DATA_POPPAR. a left join _mean_var b
			on a.MLE=b.MLE
			where b._item_no=1;
		quit; 
	%end;
	%else %do;
		proc sql;
			create table _z&_i. as select 
				a.*,
				b._mean as _mean&_i.,
				b._var as _var&_i.
			from _z%eval(&_i.-1) a left join _mean_var b
			on a.MLE=b.MLE
			where b._item_no=&_i.;
		quit; 
	%end;
%end;
proc sql;
	create table _residuals as select 
		order,
		MLE
		%do _i=1 %to &_nitems.;
			, _var&_i.
			, (&&_item&_i-_mean&_i.) as _y&_i.
			, (&&_item&_i-_mean&_i.)/sqrt(_var&_i.) as _z&_i.
		%end;
	from _z&_nitems.;
quit;

* merge kurtosis, variances and squared variances;
%do _i=1 %to &_nitems.;
	proc sql;
		create table _residuals&_i. as select
			a.*, 
			b._v_&_i., b._v2_&_i.,
			c._kurt&_i.
		from _residuals a 
		left join _var&_i. b on a.MLE=b.MLE
		left join _kurt&_i. c on a.MLE=c.MLE;
	quit;
%end;

* code class intervals for chi-square item fit statistic;
proc freq data=_z&_nitems;
	ods output Freq.Table1.OneWayFreqs=_classintervals;
	table MLE;
run;
data _classintervals; 
	set _classintervals; 
	classinterval=floor(&nclass*cumpercent/100-.00001)+1;
run;
proc sort data=_z&_nitems.;
	by MLE;
run;
proc sort data=_classintervals;
	by MLE;
run;
data _chisq; 
	merge _z&_nitems. _classintervals;
	by MLE;
run;
proc sql;
	create table _chisq2 as select 
	classinterval
	%do _i=1 %to &_nitems.;
		, sum(&&_item&_i) as X&_i
		, sum(_mean&_i.) as E&_i
		, sum(_var&_i.) as V&_i
	%end;
	from _chisq
	group by classinterval
	order by classinterval
	;
quit;
proc sql;
	create table _chisq3 as select 
	sum((X1-E1)*(X1-E1)/V1) as chisq1
	%do _i=2 %to &_nitems.;
		, sum((X&_i-E&_i)*(X&_i-E&_i)/V&_i.) as chisq&_i
	%end;
	from _chisq2
	;
quit;

* output data set with item chi-square fit statistics;
data &out._chisq;
	set _chisq3;
	item='                             ';
	%do _i=1 %to &_nitems;
		item="&&_item&_i";
		chisq=chisq&_i;
		df=&nclass-1;
		p=1-PROBCHI(chisq,df);
		output;
	%end;
	keep item chisq df p;
run;

* output data set with item residuals;
data &out._residuals(rename=(%do _i=1 %to &_nitems.; _z&_i.=&&_item&_i %end;));
 	set _residuals(keep=MLE order %do _i=1 %to &_nitems.; _z&_i. %end;);
run;

* F-test item fit statistics;
proc sort data=&out._residuals;
	by MLE;
run;
data _Ftest; 
	merge &out._residuals _classintervals;
	by MLE;
run;
%do _i=1 %to &_nitems;
	ods output ANOVA.ANOVA.&&_item&_i...ModelANOVA=_Ftest&_i;
	proc anova data=_Ftest;
		class classinterval;
		model &&_item&_i=classinterval;
	run; quit;
	data _Ftest&_i;
		set _Ftest&_i;
		rename dependent=item;
	run;
%end;
data &out._F_test;
	set _Ftest1-_Ftest&_nitems.;
	keep item DF Fvalue ProbF;
run;

* compute infit and outfit;
proc sql noprint;
 	select 
	sum(_y1**2)/sum(_var1) %do _i=2 %to &_nitems.; 
		, sum((_y&_i.)**2)/sum(_var&_i.)
	%end; 
	into :_wmean1 %do _i=2 %to &_nitems.; , :_wmean&_i.	%end;
	from _residuals;
quit;
proc sql noprint;
	select (1/count(_z1))*sum(_z1**2) %do _i=2 %to &_nitems.; , 
		(1/count(_z&_i.))*sum((_z&_i.)**2) 
	%end; 
	into :_mean1 %do _i=2 %to &_nitems.; , :_mean&_i. %end;
	from _residuals;
quit;
* compute infit and outfit variances;
%do _i=1 %to &_nitems.;
	proc sql;
		select 
			sum(_kurt&_i.-_v2_&_i.)/sum(_var&_i.)**2,
			/*sum(_kurt&_i./_v2_&_i)/(&N.**2)-1/(&N.)*/
			sum(_kurt&_i./_v2_&_i-1)/(count(_kurt&_i.)**2)

		into :_infitvar&_i., :_outfitvar&_i.
		from _residuals&_i.;
	quit;
%end;
* output data set with infit and outfit test statistics for each item;
data &out._infit_outfit;
	format item $&_l_item_name..;
	%do _i=1 %to &_nitems.;
		item="&&_item&_i";
		infit=&&_wmean&_i;
		infitvar=&&_infitvar&_i;
		infit_t=(infit**(1/3)-1)*(3/sqrt(infitvar))+(sqrt(infitvar)/3);
		outfit=&&_mean&_i;
		outfitvar=&&_outfitvar&_i;
		outfit_t=(outfit**(1/3)-1)*(3/sqrt(outfitvar))+(sqrt(outfitvar)/3);
		output;
	%end;
run;

* output data set with person fit statistics;
data _out_temp1(keep=order infit outfit);
	set _residuals;
	infit_num=sum(
		_y1**2 
		%do _i=2 %to &_nitems.; ,_y&_i.**2 %end;
		);
	infit_denom=sum(_var1 %do _i=2 %to &_nitems.; ,_var&_i. %end;);
	infit=infit_num/infit_denom;
	outfit=sum(_z1**2 %do _i=2 %to &_nitems.; ,(_z&_i.)**2 %end;)/&_nitems.;
run;

proc sql;
	create table &out._personfit as select
		a.*,
		b.infit,
		b.outfit
	from &DATA_POPPAR. a left join _out_temp1 b
	on a.order=b.order
	order by order;
quit;

data &out._personfit;
	 set &out._personfit (drop=order);
run; 

* FitResid;

proc sql noprint;
	select count (MLE) into :N from _residuals;
quit;
%let N=&N;
data _null_;
	f=(&N*%eval(&_nitems.)-&N %do _i=1 %to &_nitems.; 
		-&&_max&_i 
	%end; +1)/&_nitems.;
	call symput('f',f);
run;
%let f=&f.;
data &out._FitResid;
	set &out._infit_outfit;
	FitResid=&f.*(log(&N.)+log(outfit)-log(&f.))/(&N.*sqrt(outfitvar));
run;

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

ods html;

%mend rasch_itemfit;
