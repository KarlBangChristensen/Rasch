/**************************************************************************

ETATEMP: a SAS macro that can be used to create a temporary data set wiht eta parameters

***************************************************************************

INPUT: DATA_IPAR
	   ITEM_NAMES

**************************************************************************/

%macro etatemp(DATA_IPAR, ITEM_NAMES); 

%local DATA_IPAR ITEM_NAMES;

data _beta0_; 
 set &DATA_IPAR.; 
  _item_name = substr(item_name,1,index(item_name,"|")-1); 
  _score     = compress(cat("score",substr(item_name,index(item_name,"|")+1))); 
  _score0    = 1*substr(item_name,index(item_name,"|")+1); 
run; 

data _item_names_; 
 set &item_names.; 
_item_no = _N_; 
run; 

proc sql noprint; 
	create table _beta1_ as 
		select 	j.*, i._item_no
			from _item_names_ i left join _beta0_ j
				on i.item_name = j._item_name;
quit;

*-- _beta data is created; 
data _eta0_ (drop = _score Label rename = (_score0 = _score)) _beta (drop = _score0); 
 set _beta1_; 
Label = _item_name; 
run; 

proc sort data = _eta0_; by _item_no _score; run; 

*-- _eta_temp data is created; 
data _eta_temp (drop = StandardError item_name); 
 set _eta0_
	 _eta0_ (where = (_score=1)); 
by _item_no _score; 
 if first._item_no then do; Estimate = 0; _score = 0; end; 
retain _variable;
 if Estimate ne 0 then _variable=_variable-Estimate; 
 else _variable=Estimate; 
Estimate = _variable; 
drop _variable; 
 *if Estimate = 0 then _score = 0; 
_label = strip(_item_name)||'|'||strip(_score);
Parameter = compress(cat("eta",_item_no,"_",_score));
run; 

%mend; 
