/**************************************************************************
macro to compute the person separation index in a Rasch measurement model

%rasch_PSI(item_names, outdata, latent);

item_names: data set that contains information about the items. This data 
set should contain the variables 

	item_name: item names
	item_text (optional): item text for plots 
	max: maximum score on the item
	group: integer specifying item groups with equal parameters. Groups have to be scored 1,2,3, ...	

outdata: the name of the output data set

latent: the name of the variable containing the person location estimate.

**************************************************************************/

%macro rasch_PSI(item_names, outdata, latent);
	proc sql noprint;
		select count(item_name)
		into :nitems
		from &item_names.;
	quit;
	%let nitems=&nitems.;
	proc sql noprint;
		select unique(item_name)
		into :item1-:item&nitems.
		from &item_names.;
	quit;
	data _outdata;
		set &outdata;
		r=sum(of
		%do _i=1 %to &nitems;
			&&item&_i
		%end;);
	run;
	proc sql;
		create table PSI as select 
		a.wle,
		b.wle_se
		from _outdata a left join &latent b 
		on a.r=b.totscore
		where r notin (0 &nitems.);
	quit;
	proc sql noprint;
		select var(wle), mean(wle_se**2)
		into :var_theta, :mean_var_theta
		from PSI;
	quit; 
	data PSI;
		PSI=%sysevalf((&var_theta.-&mean_var_theta.)/&var_theta.);
	run;
%mend rasch_PSI;

