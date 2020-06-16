/*************************************************************************************
SAS macro for computing the Yen (1981) Q3 and the two versions of it (Q3,max and Q3,*) 
discussed by Christensen, Makransky & Horton (2017). 

Yen (1984). Effects of local item dependence on the fit and equating performance 
of the three-parameter logistic model. Applied Psychological Measurement, 8, 125-145. 
https://doi.org/10.1177/014662168400800201

Christensen, Makransky, Horton (2017). Critical Values for Yen’s Q3: Identification 
of Local Dependence in the Rasch Model Using Residual Correlations. Applied 
Psychological Measurement, vol 41, 178-194, 2017. 
https://doi.org/10.1177/0146621616677520
*************************************************************************************/
%macro rasch_Q3(name);
	options nomprint nonotes;
	ods exclude all;
	*;
	proc contents data=&name._residuals(drop=order MLE WLE);
		ods output Contents.DataSet.Variables=_items;
	run;
	proc sql noprint;
		select count(variable) into :_nitems from _items;
	quit;
	%let _nitems=&_nitems;
	proc sql noprint;
		select variable into :_item1-:_item&_nitems. from _items;
	quit;
	%do _i=1 %to &_nitems;
		%let _item&_i=&&_item&_i;
	%end;
	proc corr data=&name._residuals(drop=order MLE WLE);
		ods output Corr.PearsonCorr=_corr;
		var 
		%do _i=1 %to &_nitems; &&_item&_i %end;
		;
	run;
	data _corr_long; 
		set _corr;
		item1='                                  ';
		item2='                                  ';
		%do _it1=1 %to &_nitems; 
			%do _it2=%eval(&_it1)+1 %to &_nitems;
				if Variable="&&_item&_it1" then do;
					item1="&&_item&_it1"; 
					item2="&&_item&_it2"; 
					corr=&&_item&_it2; 
					output;
				end;
			%end; 
		%end;
		keep item1 item2 corr;
	run;
	ods exclude none;
	title 'average correlation';
	proc sql;
		select mean(corr) into :_averagecorr from _corr_long where (corr ne .);
	quit;
	title 'maximum correlation Q3_max';
	proc sql;
		select max(corr) into :_Q3_max from _corr_long;
	quit;
	title 'maximum correlation - average Q3_star';
	proc sql;
		select max(corr)-mean(corr) into :_Q3_star from _corr_long;
	quit;
/*
	proc datasets noprint;
		delete _corr_long _corr;
	quit;
*/
%mend rasch_Q3;
