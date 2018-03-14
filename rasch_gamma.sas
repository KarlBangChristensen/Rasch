/**************************************************************************

GAMMA: a SAS macro that can be used to calculate the gamma polynomials

***************************************************************************

missindex=m : calculate gamma function corresponding to missingness 
			  pattern m
itemindex=k : the gamma polynomial evaluated without item k

Moreover, the macro needs: ITEM_NAMES
						   ETA_TEMP

**************************************************************************/

%macro gamma(missindex=%str(), itemindex=%str(), ITEM_NAMES=_item_names, ETA_TEMP=_eta_temp); 

%local missindex _m 
       itemindex k _nitems_
	   _item_names _eta_temp; 

%let _m=&missindex; 

%if &itemindex. = %str() %then %do; 
 %let wherestr = %str();  
 %let k = %str(); 
%end; 
%else %do; 
 %let k = _&itemindex.;
 %if &_nitems.>1 %then %let wherestr = %str((where = (_item_name ne "&&_item&itemindex."))); 
 				 %else %let wherestr = %str(); 
%end; 

proc sql noprint;
	select count(distinct(_item_name)), sum(_max), max(_max)
		into :_nitems_, :_maxscore_, :_max_max_
	from &item_names. &wherestr.;
quit;

%let _nitems_=&_nitems_; 

%IF &_nitems_.>0 %THEN %DO;

proc sql noprint;
	select distinct(_item_name), _max
		into :_item_1-:_item_&_nitems_., :_max_1-:_max_&_nitems_.
	from &item_names. &wherestr.;
quit;
			
%do _i=1 %to &_nitems_.; 
 %let _max_&_i = &&_max_&_i; 
%end; 

data _item_names_miss_;
 format _item_name 		$&_l_item_name.. 
		_item_no_new 	&_l_item_no..;
%do _i=1 %to &_nitems_.;
	_item_no_new = "&_i."*1;
	_item_name	 = "&&_item_&_i";
	_max		 = "&&_max_&_i"*1;
 output;
%end;
run;

proc sql;
	create table _item_names_ as select 
		a.*,
		b._item_no
	from _item_names_miss_ a left join &item_names. b
		on a._item_name=b._item_name;
quit;

/*-- merge with eta parameter estimates --*/
proc sql;
	create table _eta_temp_ as select 
		a._item_no_new as _item_no,
		b.parameter,
		b.estimate,
		b._score
	from _item_names_ a left join &eta_temp. b
		on a._item_name=b._item_name;
quit;

/*-- for each item i find highest possible sum score --*/
%DO _i=1 %TO &_nitems_.;
%DO _j=1 %TO &_i.;
	proc sql noprint;
		select sum(_max)
			into :_cum_max_&_i.
				from _item_names_
			where _item_no_new<=&_i.;
	quit;
%END;
%END;

/*-- first compute gamma values for item 1, considering the set-up with item 1 alone --*/
%global _gamma_1_0&k.; 
%let _gamma_1_0&k.=1; *-- conditionally on r=0;

%DO _totscore=1 %TO &_max_1.; *-- for each value of total score; 
	proc sql noprint;
		select exp(estimate)
			into :_gamma_1_&_totscore.&k.
				from _eta_temp_
					where _item_no=1 and _score=&_totscore.;
	quit;
%END;
					
data _gamma&_m._1&k.; 
%do _totscore=0 %to &_max_1.;
		index1 = 1; *- item index in gamma function; 
		index2 = &_totscore.; *- rindex in gamma function; 
		gamma  = &&_gamma_1_&_totscore.&k.;
	output;
%end;
run;

/*-- iteratively compute gamma values for the remaining items --*/
%IF &_nitems_.>1 %THEN %DO;
%DO _i=2 %TO &_nitems_.;

%let _index1=%eval(&_i.-1); *-- indices to match item parameter estimates with relevant gamma values;	
	
%DO _totscore=0 %TO &&_cum_max_&_i..; *-- for each item, go through possible total scores; 						
	data _eta_&_i._&_totscore.;
	 set _eta_temp_ (where=(_item_no=&_i. and _score<=&&_max_&_i.. and _score>=&_totscore.-&&_cum_max_&_index1..));
	  index1   = &_index1.;
	  index2   = %eval(&_totscore.)-_score;
	  max	   = (&&_max_&_i..)*1;
	  totscore = (&_totscore.)*1;
	run;

/*-- calculate gamma values, store as macro variables --*/
%global _gamma&_m._&_i._&_totscore.&k.;
	proc sql noprint;
		select sum(exp(a.estimate)*b.gamma) 
			into :_gamma&_m._&_i._&_totscore.&k.
		from _eta_&_i._&_totscore. a left join _gamma&_m._&_index1.&k. b
			on a.index1=b.index1 and a.index2=b.index2;
	quit; 
%END;

/*-- gamma values as macro variables --*/					
data _gamma&_m._&_i.&k.;
 %do _totscore=0 %to &&_cum_max_&_i..;
  index1 = &_i.;
  index2 = &_totscore.;
	%if &_totscore.=0 %then %do; 
		gamma = 1; 
	%end;
	%else %do; 
		gamma = &&_gamma&_m._&_i._&_totscore.&k.; 
	%end;
	 output;
 %end;
run;

%END; *- (end for each item); 
%END; *- (only if none of items within missingness pattern is strictly greater than 0);
%END; *- (end more than zero items);

%mend gamma; 
