%let samplesize=300;
%let seed=1862;
data dich10;
	do id=1 to &samplesize.;
		theta=rannor(&seed.);
		%let beta=-2.5; A01=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta=-2.2; A02=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta=-2.0; A03=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta=-1.5; A04=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta=-0.5; A05=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta= 0.5; A06=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta= 1.5; A07=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta= 2.0; A08=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta= 2.2; A09=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		%let beta= 2.5; A10=ranbin(&seed.,1,exp(theta-&beta.)/(1+exp(theta-&beta.)));
		output;
	end;
	keep ID A01-A10;
run;
proc export data=dich10 outfile='c:\dropbox\FIT\dich10.xlsx' dbms=xlsx;
run;
data in;
input item_name $ @@;
datalines;
A01 A02 A03 A04 A05 A06 A07 A08 A09 A10
;
run;
data in;
	set in;
	item_no=_n_; 
	item_text='x';
	max=1; 
	group=_n_;
run;
data dich10;
	set dich10;
	score=sum(of A01-A10);
	if score in (0,10) then delete;
run;
%rasch_data(	data=dich10,
	            item_names=in);
%rasch_PW( 		data=dich10,
	           	item_names=in,
				out=PW);
%rasch_ppar(	DATA=dich10, 
				ITEM_NAMES=in, 
				DATA_IPAR=PW_ipar, 
				out=pp);
%rasch_itemfit(	DATA=dich10, 
				ITEM_NAMES=in, 
				DATA_IPAR=PW_ipar, 
				DATA_POPPAR=pp_outdata, 
				NCLASS=2,
				PPAR=WLE, 
				OUT=fit);
title 'WLE, 2 class intervals';
proc print data=fit_fitresid noobs;
run;
proc print data=fit_chisq noobs;
run;
proc print data=fit_Ftest noobs;
run;
%rasch_itemfit(	DATA=dich10, 
				ITEM_NAMES=in, 
				DATA_IPAR=PW_ipar, 
				DATA_POPPAR=pp_outdata, 
				NCLASS=2,
				PPAR=MLE, 
				OUT=fit);
title 'MLE, 2 class intervals';
proc print data=fit_fitresid noobs;
run;
proc print data=fit_chisq noobs;
run;
proc print data=fit_Ftest noobs;
run;
*;
%rasch_itemfit(	DATA=dich10, 
				ITEM_NAMES=in, 
				DATA_IPAR=PW_ipar, 
				DATA_POPPAR=pp_outdata, 
				NCLASS=3,
				PPAR=WLE, 
				OUT=fit);
title 'WLE, 3 class intervals';
proc print data=fit_fitresid noobs;
run;
proc print data=fit_chisq noobs;
run;
proc print data=fit_Ftest noobs;
run;
%rasch_itemfit(	DATA=dich10, 
				ITEM_NAMES=in, 
				DATA_IPAR=PW_ipar, 
				DATA_POPPAR=pp_outdata, 
				NCLASS=3,
				PPAR=MLE, 
				OUT=fit);
title 'MLE, 3 class intervals';
proc print data=fit_fitresid noobs;
run;
proc print data=fit_chisq noobs;
run;
proc print data=fit_Ftest noobs;
run;
