/**************************************************************************
macro to estimate item parameters in a Rasch measurement model using
pairwise conditional estimation

%rasch_PW(data, item_names, out=cml, exo=NONE, ICC=YES, PLOTCAT=NO, PLOTMEAN=NO, nsimu=30);

the data set 'data' contains items, the 'ITEM_NAMES' data set that contains 
information about the items. This data set should contain the variables 

	item_name: item names
	item_text (optional): item text for plots 
	max: maximum score on the item
	group: integer specifying item groups with equal parameters. Groups have to be scored 1,2,3, ...	

indicating that the item is scored 0,1,2,..,'max'. 

Item parameter estimates are put in a file 'out_par', the maximum of the log likelihood 
is put in a file 'out_logl' 

NOTE: item names should not be more than eight characters.

**************************************************************************/

%macro rasch_PW(data, item_names, out=PW, exo=NONE);

options nomprint nonotes;
*options mprint notes;
option spool;
ods exclude all; 
title ' ';


*********************************
* save stuff as macro variables *
*********************************;

/*-- data from previous macro --*/
data _data; 	   set data; run; 
data _item_names_; set item_names; run; 

/*-- save number of respondents as macro variable --*/
data _NULL_; 
 set _data end=final; 
  if final then call symput('N',trim(left(_N_))); 
run;

/*-- make a numbering of the grouped items - find the maximum length of values - max(max) is the highest number of response categories --*/
proc sql noprint;
	select count(distinct(item_name)), sum(max), max(max), max(length(item_name)), max(length(item_text)), 
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

proc sort data = _item_names_; by item_sort; run; 

data _NULL_; 
 set _item_names_;
%do _i=1 %to &_nitems.; 
 if _N_=&_i. then do; 	call symput("_item&_i", item_name); 
 						call symput("_max&_i", max); 
						call symput("_text&_i", item_text);
						call symput("_group&_i", group);
 end;  
%end; 
run; 

%do _i=1 %to &_nitems.; %let _max&_i=&&_max&_i; %end;

data _data; 
 set _data;
  id = _N_; 
run; 

/*-- loop over all item pairs - k(k-1)/2 contingency tables --*/
%do _i=1 %to &_nitems.; 
	%do _j=&_i+1 %to &_nitems.;
		proc freq data=_data; 
			table &&_item&_i*&&_item&_j / sparse out=_table&_i._&_j noprint; 
		run;
	%end; 
%end;
data _pw; 
	set %do _i=1 %to &_nitems.; %do _j=&_i.+1 %to &_nitems.; _table&_i._&_j %end; %end;;
	%do _i=1 %to &_nitems.; %do _j=&_i.+1 %to &_nitems.; 
		t&_i._&_j=0;
		if &&_item&_i ne '.' and &&_item&_j ne '.' then t&_i._&_j=&&_item&_i+&&_item&_j;
	%end; %end;
run;
data _pw;
	set _pw;
	%do _i=1 %to &_nitems.; %do _h=1 %to &&_max&_i; 
		_v&_i._&_h=0; 
		if &&_item&_i=&_h then _v&_i._&_h=1; 
	%end; %end;
run;

/*-- fit poisson model --*/
ods output genmod.parameterestimates=_pf;
proc genmod data=_pw; 
	class %do _i=1 %to &_nitems.; %do _j=&_i+1 %to &_nitems; t&_i._&_j %end; %end;;
	model count=%do _it=1 %to &_nitems.; %do _cat=1 %to &&_max&_it; _v&_it._&_cat %end; %end;
	%do _i=1 %to &_nitems.; %do _j=&_i+1 %to &_nitems; t&_i._&_j %end; %end;/d=p noint link=log maxiter=10000; 
	*repeated subject = person / covb;
run;

/*-- standardize parameters - create output data set with parameter estimates --*/
data _par _par0; 
	set _pf; 
	keep parameter estimate StdErr LowerWaldCL UpperWaldCL; 
	if (parameter in (%do _it=1 %to &_nitems; %do _cat=1 %to &&_max&_it; "_v&_it._&_cat" %end; %end;)); 
run;

proc transpose data=_par (keep = parameter estimate LowerWaldCL UpperWaldCL) out=_par; 
	id parameter; 
run;

data _par_s (keep = s); 
 set _par (where = (_NAME_ = "Estimate")); 
 	s=(0 %do _it=1 %to &_nitems; +_v&_it._&&_max&_it/(&_nitems.*&&_max&_it)%end;); output; output; output;
run; 

/*-- standardize parameters and save as macro variables --*/
data _par _parH; 
	merge 	_par
			_par_s; 
	%do _it=1 %to &_nitems; %do _cat=1 %to &&_max&_it; 
		eta&_it._&_cat=_v&_it._&_cat-&_cat*s; 
	%end; %end;
	keep %do _it=1 %to &_nitems; %do _cat=1 %to &&_max&_it; eta&_it._&_cat %end; %end; _NAME_;
run;

/*-- output file with item parameters using beta parametrization --*/
*-- i.e. transform estimate and CI; 
data _par (rename = (_NAME_ = _name)); 
	set _par; 
	%do _it=1 %to &_nitems.; 
		item=&_it; 
		max = "&&_max&_it.";
		eta&_it._0=0; 
		step&_cat=.; 
		%do _cat=1 %to &&_max&_it.; 
			step&_cat=-(eta&_it._&_cat-eta&_it._%eval(&_cat-1)); 
		%end; 
		output;
	%end;
	keep  max _NAME_ item step1-step&_max_max; *!;
run;

data _par;
 set _par;
      %do _cat=1 %to &_max_max.;
         if 1*max < &_cat. then step&_cat. = .;
      %end;
run; 

proc sort data = _par; by item; run; 

proc transpose data = _par out = _par1; 
 by item; 
 id _name;
run;

data _ipar; 
 set _par1 (rename = (LowerWaldCL = UpperCL UpperWaldCL = LowerCL));
%do _i=1 %to &_nitems.; 
* if ((1*substr(_NAME_, anydigit(_NAME_))) > &&_max&_i.) then delete; 
 if item = &_i. then do; 
  item_name = compress("&&_item&_i"||"|"||substr(_NAME_, anydigit(_NAME_))); 
  item_no   = &_i.; 
  item_r    = 1*substr(_NAME_, anydigit(_NAME_));
 end; 
%end; 
drop _NAME_ item; 
run; 

data _par0;
 set _par0; 
  item_no   = 1*substr(Parameter, anydigit(Parameter), index(substr(Parameter, 2), "_")-2); 
  item_r    = 1*substr(Parameter, index(substr(Parameter, 2), "_")+2);
run;

data _ipar (drop = item_no item_r where = (Estimate ne .)); 
 retain item_name Estimate StandardError LowerCL UpperCL; 
  merge _ipar
  		_par0 (rename = (StdErr = StandardError) keep = StdErr item_no item_r)
		; 
 by item_no item_r; 
label 	StandardError = "Standard Error" 
		LowerCL 	  = "LowerCL"
		UpperCL 	  = "UpperCL"
		;
run; 
  		
/*-- create data set with item parameter estimates --*/
proc sql noprint; 
	create table &out._ipar (drop = item_name rename = (item_name1 = item_name)) as 
		select 	cats(compress(i.item_name0),'|',substr(j.item_name,index(j.item_name,'|')+1)) length = 15 as item_name1, 
				i.item_sort, 
				substr(j.item_name,index(j.item_name,'|')+1) as score,
				j.*
			from item_names i left join _ipar j
				on i.item_name = substr(j.item_name,1,index(j.item_name,'|')-1); 
quit; 

proc sort data = &out._ipar out = &out._ipar (drop = item_sort score); by item_sort score; run; 

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
	delete %do _d=1 %to &_nd; &&_var&_d %end;

;
run; 
quit;

option notes;
title ' ';

ods exclude none; 
/*****************************/
/* end of macro              */
/*****************************/
%mend rasch_PW;
