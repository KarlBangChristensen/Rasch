/**************************************************************************

macro to compute CML estimates, gamma polynomials, and maximum of the 
conditional log likelihood function in a Rasch model

%cml(data, item_names, out=cml, exo=NONE, ICC=YES, PLOTCAT=NO, PLOTMEAN=NO, nsimu=30);

the data set 'data' contains items, the 'ITEM_NAMES' data set that contains 
information about the items. This data set should contain the variables 

	item_name: item names
	item_text (optional): item text for plots 
	max: maximum score on the item
	group: integer specifying item groups with equal parameters. Groups have to be scored 1,2,3, ...	

indicating that the item is scored 0,1,2,..,'max'. 

Item parameter estimates are put in a file 'out_par', the maximum of the log likelihood 
is put in a file 'out_logl' and the sumscore and logarithm of the estimated gamma values 
are put in the file 'out_regr' for latent regression. Estimated values of the person 
locations are put in a file 'out_theta'. 


NOTE: item names should not be more than eight characters.

**************************************************************************/

%macro rasch_cml(data, item_names, out=cml, exo=NONE);

options nocenter nonotes nosymbolgen nostimer nomprint;
*options nocenter notes nosymbolgen nostimer mprint;
goptions reset=all;
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
	select count(distinct(item_name0)), sum(max), max(max), max(length(item_name0)), max(length(item_text)), 
		length(strip(put(count(distinct(item_name0)),5.))),
		length(strip(put(max(max),5.))), count(distinct(item_name))
			into :_nitems, :_maxtotscore, :_max_max, :_l_item_name, :_l_item_text, :_l_item_no, :_l_max,:_ngroups
	from _item_names_;
quit;

%let _nitems=&_nitems.;
%let _max_max=&_max_max.;
%let _ngroups=&_ngroups.;

proc sort data = _item_names_;
 by item_name;
run;

data _item_names_;
 set _item_names_;
  retain group 0;
  by item_name;
  if first.item_name then group = group+1;
run;

%do _g=1 %to &_ngroups;
	proc sql noprint;
		select max(max)
		into :_gmax&_g
		from _item_names_ (where=(group=&_g));
	quit;
%end;

proc sort data = _item_names_; by item_sort; run; 

data _NULL_; 
 set _item_names_;
%do _i=1 %to &_nitems.; 
 if _N_=&_i. then do; 	call symput("_item&_i", item_name0); 
 						call symput("_max&_i", max); 
						call symput("_text&_i", item_text);
						call symput("_group&_i", group);
 end;  
%end; 
run; 

data _NULL_; 
 set item_names;
%do _i=1 %to &_nitems.; 
 if _N_=&_i. then do; 	call symput("_group_&_i", item_name); 
 end;  
%end; 
run; 

data _data; 
 set _data; 
rename %do _i=1 %to &_nitems.; 	&&_group_&_i. = &&_item&_i. %end;;
run; 

%do _i=1 %to &_nitems.; %let _max&_i=&&_max&_i; %end;

/*-- data set with item info - make format for a given variable by finding maximum length of the corresponding values --*/
data _item_names;
 format _item_no &_l_item_no.. _item_name $&_l_item_name.. _max &_l_max.. _item_text $&_l_item_text..;
  %do _i=1 %to &_nitems.; _item_no   = "&_i."*1; 
						  _item_name = "&&_item&_i"; 
                          _max		 = "&&_max&_i"*1; 
						  _item_text = "&&_text&_i";
   output;	
  %end;
run;

/*-- make data set including item scores --*/
data _item_scores (rename=(_i=_score));
  format _item_score $%eval(&_l_item_name.+&_l_max.+1).;
   set _item_names;
	do _i=0 to _max; _item_score = strip(_item_name)||'|'||strip(_i); 
     output; 
    end;
run;

%let maxscore=&_maxtotscore;

/*-- check score distribution --*/
%do _sc=0 %to &maxscore; %let _n&_sc=0; %end;
data _NULL_; 
	set &data; 
	t=0 %do _i=1 %to &_nitems; +&&_item&_i %end;; 
	%do _sc=0 %to &maxscore; if t=&_sc then call symput("_n&_sc",1); %end; 
run;

/**********************************/
/* item parameter estimation part */
/**********************************/

/* make table - code dummy variables, for 10 items with 4 response categories there are 1048576 (11 items: 4194304 
cells) in order to avoid an error message ("ERROR: The requested table is too large to process.") due to the fact 
that PROC FREQ tries to build tables in physical memory we use PROC SQL */

proc sql;
	create table _t0 as select 
	%do _i=1 %to &_nitems; &&_item&_i , %end;
	count(*) as count
	from &data.
	group by %do _i=1 %to &_nitems-1; &&_item&_i , %end; &&_item&_nitems
	;
quit;

data _t0; set _t0; length _all_ 3; run;

/* create (potentially very large) data set with all possible response patterns */
data _patterns;
	%do _i=1 %to &_nitems; length &&_item&_i 3; %end;
	%do _i=1 %to &_nitems; do &&_item&_i=0 to &&_max&_i; %end;
	output;
	%do i=1 %to &_nitems.; end; %end;
run;

data _table; merge _t0 _patterns; by %do _i=1 %to &_nitems; &&_item&_i %end;; if n=. then n=0; run;

data _table; set _table; length t 3; t=&_item1 %do _i=2 %to &_nitems; +&&_item&_i %end;; run;

%do _it=1 %to &_nitems; 
	data _table; 
		set _table;
		%do _cat=1 %to &&_max&_it; length v&_it&_cat 3; %end; 
		%do _cat=1 %to &&_max&_it; v&_it&_cat=(&&_item&_it=&_cat); %end; 
	run;
%end;

data _table;
	set _table;
	%do _sc=0 %to &maxscore; length n&_sc 3; %end;
	%do _sc=0 %to &maxscore; n&_sc=(t=&_sc); %end;
run;

/* margins of collapsed table */
data _gtable;
	set _table;
	%do _g=1 %to &_ngroups;
		%do _cat=1 %to &&_gmax&_g;
			gv&_g&_cat=0 %do _i=1 %to &_nitems; 
				%if &&_group&_i=&_g %then %do; + v&_i.&_cat %end; 
			%end;;
		%end;
	%end;
run;

/* fit poisson model */
data _gtable; set _gtable; if count=. then count=0.00000000001; run;

proc genmod data=_gtable; 
	ods output estimates=_est;
	ods output parameterestimates=_pf;
	model count=
		%do _g=1 %to &_ngroups; %do _cat=1 %to &&_gmax&_g; 
			gv&_g&_cat 
		%end; %end;
 		%do _sc=1 %to %eval(&maxscore-1); 
			%if &&_n&_sc=1 %then %do; n&_sc %end; 
		%end;
		/d=p noint link=log maxiter=1000
	;
	/* ESTIMATE statements to estimate item parameters (eta's) */
	%do _it=1 %to &_nitems; 
		%do _c=1 %to %eval(&&_max&_it-1); 
			estimate "eta&_it&_c" gv%eval(&&_group&_it)&_c %eval(&_maxtotscore) 
				%do _i0=1 %to &_nitems; gv%eval(&&_group&_i0)%eval(&&_max&_i0) -&_c %end;
			;
		%end; 
		estimate "eta&_it.&&_max&_it" gv%eval(&&_group&_it)%eval(&&_max&_it) %eval(&_maxtotscore-&&_max&_it) 
			%do _i0=1 %to %eval(&_it-1); gv%eval(&&_group&_i0)%eval(&&_max&_i0) -&_c %end;
			%do _i0=%eval(&_it+1) %to &_nitems; gv%eval(&&_group&_i0)%eval(&&_max&_i0) -&_c %end;
		;
	%end; 
	/* ESTIMATE statements to estimate threshold parameters (beta's) */
	%do _it=1 %to &_nitems;
		%if %eval(&&_max&_it.)=1 %then %do;
			estimate "beta&_it.1" gv%eval(&&_group&_it)1 -%eval(&_maxtotscore-1)
			%do _i0=1 %to %eval(&_it-1); gv%eval(&&_group&_i0)%eval(&&_max&_i0) 1 %end;
			%do _i0=%eval(&_it+1) %to &_nitems; gv%eval(&&_group&_i0)%eval(&&_max&_i0) 1 %end;
			;
		%end; 
		%if %eval(&&_max&_it.)>1 %then %do; 
			estimate "beta&_it.1" gv%eval(&&_group&_it)1 -%eval(&_maxtotscore) %do _i0=1 %to &_nitems; gv%eval(&&_group&_i0)%eval(&&_max&_i0) 1 %end;;
			%do _c=2 %to %eval(&&_max&_it-1); 
				estimate "beta&_it&_c" 
					gv%eval(&&_group&_it)&_c -%eval(&_maxtotscore) 
					gv%eval(&&_group&_it)%eval(&_c-1) %eval(&_maxtotscore) 
					%do _i0=1 %to &_nitems; gv%eval(&&_group&_i0)&&_max&_i0. 1 %end;;
			%end;
			estimate "beta&_it.&&_max&_it" 
				gv%eval(&&_group&_it)%eval(&&_max&_it) - %eval(&_maxtotscore-1) 
				gv%eval(&&_group&_it)%eval(&&_max&_it-1) %eval(&_maxtotscore) 
				%do _i0=1 %to %eval(&_it-1); gv%eval(&&_group&_i0)%eval(&&_max&_i0) 1 %end;
				%do _i0=%eval(&_it+1) %to &_nitems; gv%eval(&&_group&_i0)%eval(&&_max&_i0) 1 %end;
				;
		%end; 
	%end;
run;

/* create output data set with parameter estimates and 95% confidence intervals */
data _par_ci; 
	length item $ &_l_item_name;
	set _est;
	%do _it=1 %to &_nitems; 
		%do _cat=1 %to &&_max&_it; 
			if label="eta&_it&_cat" then do; item="&&_item&_it"; cat="&_cat"; end;
			if label="beta&_it&_cat" then do; item="&&_item&_it"; cat="&_cat"; end;
		%end; 
	%end;
	Estimate      = LBetaEstimate/&_maxtotscore;
	StandardError = StdErr/&_maxtotscore;
	LowerCL       = LBetaLowerCL/&_maxtotscore;
	UpperCL       = LBetaUpperCL/&_maxtotscore;
	keep item cat label estimate LowerCL UpperCL StandardError;
	label StandardError = "Standard Error"; 
run;

/* save item parameter estimates (eta's and beta's) as macro variables */
data _null_; 
	set _par_ci; 
	%do _it=1 %to &_nitems; 
		call symput("_eta_&_it._0",trim(left(0))); 
		call symput("_beta_&_it._0",trim(left(0))); 
		%do _cat=1 %to &&_max&_it; 
			if label="eta&_it&_cat" then call symput("_eta_%eval(&_it)_%eval(&_cat)",trim(left(estimate)));
			if label="beta&_it&_cat" then call symput("_beta_%eval(&_it)_%eval(&_cat)",trim(left(estimate)));
		%end; 
	%end;
run;


/*-- output files with format as needed for input to other macros --*/
data &out._ipar;
retain item_name;  
 set _par_ci (where = (substr(Label,1,1)="b"));
  item_name = compress(item||"|"||cat);  
  drop item label cat; 
run;

/*****************************************/
/* end of item parameter estimation part */
/*****************************************/


/*****************************************/
/* likelihood and regression file part   */
/*****************************************/

data _item_names_; set item_names; item_name = upcase(item_name0); run; 

/*-- data with item parameter --*/
%etatemp(DATA_IPAR=&out._ipar, ITEM_NAMES=_item_names_);

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

data _item_names_miss (where=(_miss='1')); 
 set _item_names (drop = _item_text); 
  %do _i=1 %to &_nitems.;
   if _item_name = "&&_item&_i" then _miss = substr("&&_miss&_m",&_i.,1);
  %end;
run;  

data _NULL_; 
 set _item_names_miss end=_end; 
  if _end then call symput("_nitems_", compress(_N_)); 
run; 

/*-- macro variables with max total score for particalr missing data --*/
proc sql noprint;
	select max(totscore)
	into :_maxtotscore&_m.
	from _miss1 (where = (miss_pattern = "&&_miss&_m"));
quit;

/*-- gammas without item k --*/
/*%DO k=1 %TO &_nitems.; 
 %gamma(missindex=&_m., itemindex=&k., item_names=_item_names_miss);
%END;*/ 

/*-- gammas with item k --*/
%gamma(missindex=&_m., item_names=_item_names_miss);

data _gammafile&_m.; 
 set _gamma&_m._&_nitems_.;  
  id = compress("gamma"||index2); 
run; 

proc transpose data = _gammafile&_m. (drop = index1 index2) out = _gammafile&_m.; 
 id id; 
run; 

data _gammafile&_m. (drop = _NAME_);
retain %do _sc=0 %to &&_maxtotscore&_m.; gamma&_sc. lgamma&_sc. %end;; 
 set _gammafile&_m.;
%do _sc=0 %to &&_maxtotscore&_m.;	lgamma&_sc. = log(gamma&_sc.); 
									call symput("_g&_m._&_sc.", gamma&_sc.);
%end; 
run; 

%END;

/*-- compute maximum of log likelihood - save value as macro variable --*/
%do _m=1 %to &_miss.; 
data _llf&_m.;
 set _miss1 (where = (miss_pattern = "&&_miss&_m"));
  %do _it=1 %to &_nitems.; %do _cat=1 %to &&_max&_it; v&_it&_cat=(&&_item&_it=&_cat); %end; %end;
  sc=%do _i=1 %to %eval(&_nitems.-1); max(0, &&_item&_i.)+ %end; max(0, &&_item&_nitems.);
  denom=0 %do _sc=0 %to &&_maxtotscore&_m.; +&&_g&_m._&_sc.*(sc=&_sc.) %end;;
  pr=exp(0 %do _it=1 %to &_nitems; %do _cat=1 %to &&_max&_it; +v&_it&_cat*&&_eta_&_it._&_cat %end; %end;) / denom;
  lp=log(pr); 
 *keep lp; 
run;
%end; 

data _llf; 
 set %do _m=1 %to &_miss.; _llf&_m. %end;; 
run; 

proc means data=_llf sum; var lp; output out=_loglfile sum=logl; run;

data &out._logl (rename = (logl = Value)); 
 retain Description; 
  set _loglfile (keep = logl); 
   Description = "-2 Log Likelihood"; 
   call symput('ll',trim(left(logl))); 
run;

/* create regression file */
/*data &out._regr;
	set &data.;
	t=0 %do _i=1 %to &_nitems; +&&_item&_i %end;; 
	%do _sc=0 %to (&_maxtotscore); lg&_sc=log(&&gam&_sc); %end; 
run;*/

/************************************************/
/* end of likelihood and regression file part   */
/************************************************/

/*-- output files with format as needed for input to other macros --*/
data &out._eta;
 set _eta_temp;
run;

/******************************/
/* delete temporary data sets */
/******************************/

ods output Datasets.Members=_mem;
proc datasets; run; quit;

data _mem; set _mem; _underscore=substr(name,1,1); run;
data _mem; set _mem(where=(_underscore='_')); run;
data _null_; set _mem end=final; if final then call symput('_nd',trim(left(_N_))); run;

%put clean-up deleting &_nd temporary data sets;
proc sql noprint;
	select distinct(name)
	into :_var1-:_var&_nd.
	from _mem;
quit;
proc datasets;
	delete %do _d=1 %to &_nd; &&_var&_d %end;;
run; quit;

goptions reset=all;
*ods html;

/*****************************/
/* end of macro              */
/*****************************/
%mend;
