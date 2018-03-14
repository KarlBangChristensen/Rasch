/**************************************************************************

ITEM_FIT: a SAS macro that can be used to calculate item fits

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

data set 'out_cfit' contains the item infit and outfit
data set 'out_outdata_all' is a copy of the input data set containing conditional mean, residual and variance on each item 

**************************************************************************/

%macro rasch_itemcfit(DATA, ITEM_NAMES, DATA_IPAR, OUT=MML); 

*options mprint notes;
options nomprint nonotes;
option spool;
ods listing close; ods html close; 
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

/*-- for each item i find highest possible sum score --*/
%do _i=1 %to &_nitems.;
proc sql noprint;
	select sum(_max)
		into :_cum_max_&_i.
			from _item_names
		where _item_no<=&_i.;
quit;
%end;

data _item_names_; 
 set _item_names; 
_item_no = _N_; 
item_name = _item_name;
run; 

/*-- data with item parameter --*/

%etatemp(DATA_IPAR=&DATA_IPAR., ITEM_NAMES=_item_names_);

/**************************************************************************************/
/* CFITTEST part (gammas for item pairs infit and oufit test statistics are computed) */
/* Corrected version of FITTEST 													  */
/**************************************************************************************/

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

/*-- gammas without item k --*/
%DO k=1 %TO &_nitems.; 
 %gamma(missindex=&_m., itemindex=&k., item_names=_item_names_miss);
%END; 

/*-- gammas with item k --*/
%gamma(missindex=&_m., item_names=_item_names_miss);

%END; 

/*-- data with all possible combinations of item no, score and xsum --*/
data _temp_; 
 %do _i=1 %to &_nitems.; 
  %do _h=0 %to &&_max&_i; 
   %do _r=0 %to &&_cum_max_&_nitems..;
    %do _m=1 %to &_miss.;
	  xsum      = &_r.; 
	  _item_no  = &_i.; 
	  _score    = &_h.;
	  _miss     = &_m.; 
  	  Parameter = compress("eta"||_item_no||'_'||_score);  
	 output; 
	%end; 
   %end; 
  %end; 
 %end; 
run;   

/*-- merge with corresponding values of eta, create new variable that is the difference between the sum score and the score of this item --*/
proc sql;
	create table _temp1_ (where = (rx >= 0)) as select
		a.*,
		b.Estimate,
		(a.xsum - a._score) as rx
			from _temp_ a left join _eta_temp b
				on a.Parameter=b.Parameter;
quit;

%let _nitems_ = %eval(&_nitems.-1);
%let n1 	  = &_nitems.; 
%let n2 	  = &_nitems_.;

/*-- compute probabilities using the gammas --*/
data _prob1_; 
 set _temp1_; 
	%do _i=1 %to &_nitems.; 
	 %do _h=0 %to &&_max&_i; 
	  %do _r=0 %to &&_cum_max_&_nitems..;
	   %do _rx=0 %to &&_cum_max_&_nitems..;
	    %do _m=1 %to &_miss.;
	     %if %symexist(_gamma&_m._&n2._&_rx._&_i.) %then %do;
		  %if %symexist(_gamma&_m._&n1._&_r.) %then %do; 
 		   if _item_no = &_i. and _score = &_h. and xsum = &_r. and rx = &_rx. and _miss = &_m. then do; 
		   _prob = exp(Estimate) * &&_gamma&_m._&n2._&_rx._&_i. / &&_gamma&_m._&n1._&_r.; 
		   end;
		  %end;
         %end;  
		%end; 
	   %end;  
	  %end; 
	 %end; 
	%end; 
if xsum = 0 and _score ne 0 	then _prob = 0; 
else if xsum = 0 and _score = 0 then _prob = 1; 
%do _i=1 %to &_nitems.; 
 %do _j=0 %to &&_max&_i.; 
  if _item_no = &_i. and xsum = (&&_cum_max_&_nitems..-&_j.) and _score < (&&_max&_i-&_j.)	then _prob = 0; 
 %end; 
%end; 
run; 

/*-- macro variable that is the largest number of possible scores --*/
proc sql noprint; 
	select max(_max)
	 into :maxmax
	from _item_names;
quit; 

/*-- probabilities for each possible sum score for each item --*/
proc sort data = _prob1_ out = _prob1_ (drop = rx) nodupkey; 
 by _item_no xsum _miss Parameter _score; 
run; 

proc transpose data = _prob1_ out = _prob1_t; 
 by _item_no xsum _miss; 
 var _prob; 
 id _score; 
run;

data _prob1_t_1; 
 set _prob1_t; 
%do _i=1 %to &_nitems.; 
 if _item_no = &_i. then do; 
  _&&_max&_i = 1 %do _h=0 %to %eval(&&_max&_i-1); -max(0,_&_h.)%end;;
 end; 
%end; 
run; 

/*-- calculating means and variances --*/
data _mean_var1; 
 set _prob1_t_1; 
%do _i=0 %to %eval(&maxmax.); 
 if _&_i. = . then _&_i. = 0; 
%end; 
 retain _mean;  _mean  = 0;
 retain _mean2; _mean2 = 0; 
%do _i=0 %to %eval(&maxmax.); 
 _mean  = _mean + _&_i.*&_i.;
 _mean2 = _mean2 + (&_i.**2)*_&_i.; 
%end; 
 _var = _mean2 - _mean**2;  
run; 

data _data1; 
 set _miss1; 
  xsum = &_item1 %do _i=2 %to &_nitems.; + &&_item&_i %end;; 
%do _m=1 %to &_miss.;
 if miss_pattern = "&&_miss&_m" then _miss = &_m.; 
%end; 
*order = _N_; 
run; 	

/*-- calculating residuals for each item --*/
%DO i=1 %TO &_nitems.; 
proc sql noprint; 
	create table _z&i. 
		as select a.*,
		b._mean as _mean&i., b._var as _var&i.,
		( a.&&_item&i - b._mean ) / sqrt( b._var ) as _z&i.
	from _data1 a left join _mean_var1 (where = (_item_no = &i.)) b
		on a.xsum = b.xsum and a._miss = b._miss; 	
quit; 

proc sort data = _z&i; by order; run; 

/*-- calculating infit and outfit test statistics --*/
proc sql noprint;
	create table _z&i._ as
   		select "&&_item&i               " as item,
		sum(_var&i.*(_z&i.**2)) / sum(_var&i.) as infit, 
		(1/count(_z&i.)) * sum(_z&i.**2) as outfit
      		from  _z&i.; 
quit; 

%END; 

/*-- data with infit and outfit test statistics for each item --*/
data _cfit;  
set %do i=1 %to &_nitems.; 
		_z&i._
	%end;;
run; 

/*-- format correction --*/
proc sql noprint;
   select max(length(item)) into :maxlengthitem
      from _cfit; 
quit; 

%let maxlengthitem = &maxlengthitem.; 

data &out._cfit (rename = (item1 = item));
length item1 $&maxlengthitem..; 
 set _cfit;
item1 = substr(item, 1, &maxlengthitem.); 
drop item; 
run; 

/*-- residuals output data set --*/
data &out._cresiduals; 
merge %do i=1 %to &_nitems.; 
		_z&i. (keep = order _z&i. rename = (_z&i. = &&_item&i))
	  %end;;
by order;
run;

/*-- overall output data set --*/
data &out._outdata_all (drop = xsum order %do _i=1 %to &_nitems.; _var&_i. _mean&_i. _z&_i. %end; miss_pattern totscore miss_n _miss); 
retain	%do _i=1 %to &_nitems.; &&_item&_i %end;
		R
		;
format  %do _i=1 %to &_nitems.; E&_i %end;
		%do _i=1 %to &_nitems.; Res&_i %end; 
		%do _i=1 %to &_nitems.; V&_i %end; 
		; 
merge %do i=1 %to &_nitems.; 
		_z&i. 
	  %end;;
by order;
R = xsum;
%do _i=1 %to &_nitems.; 
	Res&_i. = _z&_i.;    
	E&_i.   = _mean&_i.; 
	V&_i.   = _var&_i.;
%end; 
run; 


/**********************************************/
/* asymptotic distribution of test statistics */
/**********************************************/

/*-- macro variables: variances for each item and each score (same for all pesons with same score) --*/
data _NULL_; 
 set &out._outdata_all; 
  %do _r=0 %to &&_cum_max_&_nitems..; 
   %do i=1 %to &_nitems.; 
    if R = &_r. then do; call symput("_V_&_r._&i.", V&i.); end; 
   %end; 
  %end; 
run; 

/*-- third and fourth moments, and variance of squared residual --*/
data _mean_var2; 
 set _mean_var1; 
%do _i=0 %to %eval(&maxmax.); 
 if _&_i. = . then _&_i. = 0; 
%end; 
 retain _meanZ4; _meanZ4 = 0; 
 retain _meanZ2; _meanZ2 = 0; 
%do _i=0 %to %eval(&maxmax.); 
 _meanZ4 = _meanZ4 + ((&_i.-_mean)**4)*_&_i.;
 _meanZ2 = _meanZ2 + ((&_i.-_mean)**2)*_&_i.;
%end; 
if _var > 0 then _Zsqvar = 1/(_var)**2 * (_meanZ4 - _meanZ2**2);
run; 

/*-- macro variables: variance of squared residual --*/
data _NULL_; 
 set _mean_var2; 
  %do _r=0 %to &&_cum_max_&_nitems..; 
   %do i=1 %to &_nitems.; 
    if xsum = &_r. and _item_no = &i. then do; call symput("_Zvar_&_r._&i.", _Zsqvar); end; 
   %end; 
  %end; 
run; 

/*-- merging these to original data --*/
data _outdata_zvar; 
 set &out._outdata_all; 
  %do _r=0 %to &&_cum_max_&_nitems..; 
   if R = &_r. then do; %do i=1 %to &_nitems.; _Zsqvar&i. = &&_Zvar_&_r._&i.; %end; end; 
  %end; 
run; 

/*-- number of persons with score r and sum of variances and squared residuals, respectively, for each item (same for all pesons with same score) --*/
data _outdata_zvar_; 
 set _outdata_zvar; 
  %do i=1 %to &_nitems.;
   Ressq&i. = Res&i.**2; 
  %end; 
run; 

proc summary data = _outdata_zvar_; 
 class R; 
 var %do i=1 %to &_nitems.; V&i. %end; %do i=1 %to &_nitems.; Ressq&i. %end;;  
 output out = _no_r (rename = (_FREQ_ = _n_r))  sum=; 
run; 

/*-- asymptotic variance of relevant variable --*/
data _NULL_; 
 set _no_r;
  %do _r=0 %to &&_cum_max_&_nitems..; 
   if R = &_r. then do; call symput("_n_&_r",compress(_n_r)); 
						%do i=1 %to &_nitems.; call symput("_Yvar_&_r._&i.", compress(&&_Zvar_&_r._&i./(_n_r)));	
											   call symput("_Zsum_&_r._&i.", Ressq&i.); %end;				 
   end; 
  %end; 
 if R = . then do; 
  %do i=1 %to &_nitems.; call symput("_sumV_&i",compress(V&i.)); %end; 
 end; 
run; 

/*-- output for simulation study --*/
data &out._yvars; 
 %do _r=0 %to &&_cum_max_&_nitems..;
  %do i=1 %to &_nitems.; 
   %if %symexist(_n_&_r.) %then %do; 
    R    	  = &_r.; 
	n_r		  = &&_n_&_r.; 
    Y&i. 	  = 1/(&&_n_&_r.) * (&&_Zsum_&_r._&i.); 
	_Yvar_&i. = &&_Yvar_&_r._&i.; 
   %end; 
  %end; 
  output; 
 %end;
run; 

/*-- relevant weights --*/
data _NULL_; 
  %do _r=0 %to &&_cum_max_&_nitems..; 
   %do i=1 %to &_nitems.;
    %if %symexist(_n_&_r.) %then %do; 
     call symput("_w_&_r.", compress(&&_n_&_r./&N.));
     call symput("_u_&_r._&i.", compress(&&_n_&_r.*&&_V_&_r._&i./&&_sumV_&i.)); 
	%end; 
   %end; 
  %end; 
run; 

/*-- computing the 'weighted variables' to take sum over --*/
data _asymptotic; 
 %do _r=0 %to &&_cum_max_&_nitems..; 
  %if %symexist(_n_&_r.) %then %do;
    %do i=1 %to &_nitems.;
     R             = &_r.; 
     _infitvar&i.  = (&&_u_&_r._&i.)**2 * &&_Yvar_&_r._&i.; 
     _outfitvar&i. = (&&_w_&_r.)**2 * &&_Yvar_&_r._&i.;
	 *_outfitvar&i. = ( &&_u_&_r._&i. * &&_sumV_&i. / ( &&_V_&_r._&i. * &N. ) )**2 * &&_Yvar_&_r._&i.;
    %end;
   output;   
  %end;
 %end; 
run; 

/*-- variances of asymptotic distributions --*/
proc sql noprint;
	select sum(_infitvar1), sum(_outfitvar1) %do i=2 %to &_nitems.; , sum(_infitvar&i.), sum(_outfitvar&i.) %end; 
		into :infitvar_1, :outfitvar_1 %do i=2 %to &_nitems.; , :infitvar_&i., :outfitvar_&i. %end; 
	from _asymptotic;
quit;

%do i=1 %to &_nitems.; %let infitvar_&i. = &&infitvar_&i.; %let outfitvar_&i. = &&outfitvar_&i.; %end; 

/*-- length of item_name (not group) for final output --*/
proc sql noprint;
	select max(length(item_name))
		into :_l_item_name
	from &item_names.; 
quit;

/*-- merging quantiles on data --*/
data &out._cfit;
retain item infit infit_sd outfit outfit_sd infit_P5 infit_P95 outfit_P5 outfit_P95; 
 set &out._cfit;
  %do i=1 %to &_nitems.;
   if item = "&&_item&i" then do; 	
	infitvar = &&infitvar_&i.;
    outfitvar = &&outfitvar_&i.;
   end;
  %end; 
run;  

data &out._cfit;
 set &out._cfit;
  t_in  = (infit**(1/3)-1)*(3/sqrt(infitvar))+sqrt(infitvar)/3; 
  t_out = (outfit**(1/3)-1)*(3/sqrt(outfitvar))+sqrt(outfitvar)/3;
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

ods html file='bent2.html';

%mend rasch_itemcfit;
