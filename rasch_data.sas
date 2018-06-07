/**************************************************************************
DATA: This data must contain the items (scored 0,1, .. ,'max'), but the 
number of response categories 'max' can differ between items.  

ITEM_NAMES: This data set must contain the variables 

	item_name: item names
	item_text (optional): item text for plots 
	max: maximum score on the item
	group: specification of item groups (OBS: items in same group must 
	have same maximum score) 


data set 'data' contains grouped version of DATA
data set 'item_names' contains grouped version of ITEM_NAMES

**************************************************************************/

%macro rasch_data(DATA, ITEM_NAMES, OUT=MML); 

options nomprint nonotes;
ODS EXCLUDE ALL;
title ' ';

/*-- if data sets specified within library, put in work library and refer to this for the remainder --*/
%if %index(&item_names.,.) > 0 %then %do; 
 data %substr(&item_names.,%index(&item_names.,.)+1); 
  set &item_names.; 
 run; 
  %let ITEM_NAMES = %substr(&item_names,%index(&item_names.,.)+1); 
%end; 

%if %index(&data.,.) > 0 %then %do; 
 data %substr(&data.,%index(&data.,.)+1); 
  set &data.; 
 run; 
  %let DATA = %substr(&data,%index(&data.,.)+1); 
%end; 

/*-- save number of respondents as macro variable --*/
data _NULL_; 
 set &data. end=final; 
  if final then call symput('N',trim(left(_N_))); 
run;

/*-- delete item duplicates if any, and only take out the ones with the largest max value --*/
proc sort data = &item_names. out = _&item_names.; 	
 by item_name descending max; 
run; 
proc sort data = _&item_names. nodupkey; 
 by item_name; 
run;

/*-- only take out variables of DATA that are contained in ITEM_NAMES --*/
data _NULL_; 
 set _&item_names. end=_N; 
  if _N then do; call symput("_no",_N_); 
  end; 
run; 

data _NULL_; 
 set _&item_names.; 
  %do _i=1 %to &_no.; 
   if _N_=&_i. then do; call symput("_keep&_i.", item_name); call symput("_max&_i.", compress(max)); 
   end;
  %end; 
run;  

data _&data.; 
 set &data.; 
  keep 	%do _i=1 %to &_no.; &&_keep&_i %end;
		;	
run; 

/*-- create macro that checks if variable is in data --*/
%macro varexist(ds,var);
 %local ds var dsid rc;
 %let dsid = %sysfunc(open(&ds));
 %if (&dsid.) %then %do;
  %if %sysfunc(varnum(&dsid.,&var.)) 	%then 1;
 										%else 0;
 %let rc = %sysfunc(close(&dsid.));
 %end;
 %else 0;
%mend varexist; 

/*-- check to see if group is variable of data set or not --*/
data _&item_names.  (drop = item_name0) 
	 _&item_names.0 (keep = item_name item_name0 max %if %varexist(&item_names.,item_text)=1 %then %do; item_text %end;); *-- data set that contains the mapping between group names and item names;  
retain item_name0; 
 set _&item_names.; 
  item_name0 = upcase(item_name); 
%if %varexist(&item_names.,group) = 1 %then %do; 
  item_name  = cat('group',strip(put(group,12.))); 
%end; %else %do; 
  item_name  = cat('group',strip(put(_N_,12.))); 
%end; 
run; 

/* check that 'max' is the same within item groups */
%IF %varexist(&item_names.,group) = 1 %THEN %DO; 
proc means data=&item_names. min max;
	var max;
	class group;
	ods output summary=_check;
run;

%let _ERROR=;
data _null_; 
	set _check; 
	if max_Min < max_Max then call symput('_ERROR','ERROR: All items in a group must have the same number of categories'); 
run;
%put; %put &_ERROR; %put; 
%END;

/*-- macro to sort items by ending digits (if any) --*/
%macro itemsort(ds, var);
%local ds var;  
proc sort data = &ds.; by &var.; run; 
data &ds.; 
 set &ds.; 
if anydigit(reverse(compress(&var.)))=1	 then do; item_sort0 = 1*substr(compress(&var.), length(compress(&var.))-notdigit(reverse(compress(&var.)))+2); 
												  sort_name0 = substr(compress(&var.), 1, anydigit(compress(&var.))-1); 
										 end; 
								   		 else do; item_sort0 = _N_; 
										 		  sort_name0 = &var.; 
										 end; 
run; 
proc sort data = &ds.; by sort_name0 item_sort0; run; 
data &ds. (drop = sort_name0 item_sort0); 
 set &ds.; 
  item_sort = _N_; 
run; 
%mend; 

%itemsort(_&item_names.0, item_name0);
%itemsort(_&item_names., item_name);

/*-- stack columns of DATA such that it fits with groups --*/
proc transpose data = _&data. out = _tdata; 
run; 

data _tdata; 
 set _tdata; 
 item_name0 = upcase(_NAME_);
run; 

proc sort data = _tdata; 		 					by item_name0; run; 
proc sort data = _&item_names.0 out = _item_names0; by item_name0; run; 

/* merge group no on transposed DATA */
data _tdatagroup; 
 merge	_tdata		
		_item_names0 (keep = item_name item_name0)
		; 
by item_name0;
%if %varexist(_tdata,_LABEL_)=1 %then %do; 
 drop _LABEL_; 
%end; 
run;

proc sort data = _tdatagroup; by item_name; run; 

data _tdatagroup0; 
set _tdatagroup; 
	by item_name;
		if first.item_name then count = 0;
			count+1; 
 if anydigit(substr(item_name,length(item_name),1)) > 0 then do;
  sortby = 1*substr(item_name,notdigit(item_name,-length(item_name))+1);
 end; 
run; 

/*-- macro variable containing the maximum no of items in one group --*/
proc sql noprint;
   select max(count) into :maxcount
      from  _tdatagroup0; 
quit; 

proc sort data = _tdatagroup0; by sortby; run; 

%do i=1 %to &maxcount.; 
data _tdatagroup&i.; 
 set _tdatagroup0 (where = (count = &i.)); 
run; 

proc transpose data = _tdatagroup&i. (drop = sortby count) out = _datagroup&i. (drop = _NAME_); 
 id item_name; 
run;

data _NULL_; 
 set _datagroup&i.; 
array x{*} _NUMERIC_; call symput("dimx", dim(x)); 
run; 

data _datagroup&i.; 
 set _datagroup&i.; 
array x{*} _NUMERIC_; 
%do _i=1 %to &dimx.;
if x[&_i.] = . 	then miss&_i. = 1; 
  				else miss&_i. = 0; 
%end; 
run; 
%end;

/*-- new DATA with variables corresponding to groups instead of items --*/
data _data; 
set	%do i=1 %to &maxcount.; 
	_datagroup&i. 
	%end; 
	;
run; 

data data; 				set _data; *nobs = &N.; run; 
data item_names; 		set _&item_names.0; run; 

/*-- how many items --*/
proc sql noprint;
	select count(distinct(item_name))
			into :_nitems
	from &item_names.;
quit;

/*-- relevant notifications concerning data --*/
data _&data.; set _&data.; x = 1; run; 

%do i=1 %to &_no.;
proc summary data = _&data. missing; 
 class &&_keep&i; 
 var x; 
output out = _test&i._ (rename=(_FREQ_ = freq_obs)) sum=; 
run; 

data _NULL_; 
 set _test&i._ (where = (_TYPE_ ne 0)) end=max; 
if _N_ = 1 and &&_keep&i = . then do; call symput("notify_&i", 1); 
									  call symput("outtext&i", cat(" There are ", freq_obs, " missing observations for the item ")); 
									  call symput("notify", 1);  
end; 
%do k=0 %to &&_max&i.;
 if &&_keep&i = &k. then do; call symput("out&i&k", 1); end; 
%end;  
run; 

data _NULL_; 
 set _test&i._ (where = (&&_keep&i ne .)) end=max;
if max then do; if _N_ ne (&&_max&i.+1) then do; call symput("notify_&i", 1); call symput("notify&i", 1); 
												 call symput("notify", 1);   end; 
				if _N_ > &&_max&i.+1 then do;    call symput("toomany&i", compress(_N_-1)); 
      											 call symput("notify", 1);   end; 
				if _N_ < (&&_max&i. + 1 %if %symexist(notify&i) %then %do; + &&notify&i. %end;) then do; call symput("outfirst&i", 1); 
																										 call symput("notify", 1); end;
end;
run; 

%if %symexist(notify_&i) %then %do;
%put ------------------------------------------------------------------------------------------------;
%put "%sysfunc(compress(&&_keep&i))":; %end; 

%if %symexist(outtext&i) %then %do; %let outtext&i = %sysfunc(cat(&&outtext&i));
%end; 
%if %symexist(outtext&i) %then %do; %put &&outtext&i "%sysfunc(compress(&&_keep&i))"; %end;  

%if %symexist(outfirst&i) %then %put  The max specified for the item "%sysfunc(compress(&&_keep&i))" is &&_max&i., but; 
%do k=0 %to &&_max&i.; 
%if %symexist(out&i&k) %then; %else %put - there are no observations of &k;  
%end;

%if %symexist(toomany&i) %then %put There are observations above the specified maximum for "%sysfunc(compress(&&_keep&i))".
The maximum in the data is %sysfunc(compress(&&toomany&i)).;  

%if &i. = &_nitems. %then 
%put ------------------------------------------------------------------------------------------------;
%end;

/*-- delete temporary data sets --*/

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

%put ; 
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
quit;*/

ODS EXCLUDE NONE;

%mend; 
