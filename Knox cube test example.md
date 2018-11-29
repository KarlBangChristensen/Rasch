# Knox cube test example

This example illustrates the use of the SAS macros using the Knox Cube test data. The Knox Cube Test measures short term memory (Wright,  B.D.  and  M.H.  Stone,  1979.  Best  test design  Rasch  Measurement. Chicago, IL: Mesa Press). 

```
* Knox cube test data (N=35, I=18);
data knox;
input name $ 1-7 gender $ i1-i18;
datalines;
Richard M 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 
Tracie  F 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
Walter  M 1 1 1 1 1 1 1 1 1 0 0 1 0 0 0 0 0 0 
Blaise  M 1 1 1 1 0 0 1 0 1 0 0 0 0 0 0 0 0 0 
Ron     M 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
William M 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
Susan   F 1 1 1 1 1 1 1 1 1 1 1 1 1 0 1 0 0 0 
Linda   F 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
Kim     F 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
Carol   F 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 
Pete    M 1 1 1 0 1 1 1 1 1 0 0 0 0 0 0 0 0 0 
Brenda  F 1 1 1 1 1 0 1 0 1 1 0 0 0 0 0 0 0 0 
Mike    M 1 1 1 1 1 0 0 1 1 1 1 1 0 0 0 0 0 0 
Zula    F 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 
Frank   M 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 
Dorothy F 1 1 1 1 1 1 1 1 1 0 1 0 0 0 0 0 0 0 
Rod     M 1 1 1 1 0 1 1 1 1 1 0 0 0 0 0 0 0 0 
Britton F 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 0 0 0 
Janet   F 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 
David   M 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 0 0 0 
Thomas  M 1 1 1 1 1 1 1 1 1 1 1 0 1 0 0 0 0 0 
Betty   F 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 
Bert    M 1 1 1 1 1 1 1 1 1 1 0 0 1 1 0 0 0 0 
Rick    M 1 1 1 1 1 1 1 1 1 1 1 0 1 0 0 1 1 0 
Don     M 1 1 1 0 1 1 0 0 0 0 0 0 0 0 0 0 0 0 
Barbara F 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
Adam    M 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 
Audrey  F 1 1 1 1 1 1 1 1 1 0 1 0 0 0 0 0 0 0 
Anne    F 1 1 1 1 1 1 0 0 1 1 1 0 0 1 0 0 0 0 
Lisa    F 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 
James   M 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 
Joe     M 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 
Martha  F 1 1 1 1 0 0 1 0 0 1 0 0 0 0 0 0 0 0 
Elsie   F 1 1 1 1 1 1 1 1 1 1 0 1 0 1 0 0 0 0 
Helen   F 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
;
run;
```
include macros from GitHub
```
filename r url 'https://raw.githubusercontent.com/KarlBangChristensen/Rasch/master/rasch_include_all.sas';
%include r;
```
will look only at the non-extreme items
```
data in;
input item_no item_name $ item_text $ max group;
datalines;
1 i4 x 1 1
2 i5 x 1 2
3 i6 x 1 3
4 i7 x 1 4
5 i8 x 1 5
6 i9 x 1 6
7 i10 x 1 7
8 i11 x 1 8
9 i12 x 1 9
10 i13 x 1 10
11 i14 x 1 11
12 i15 x 1 12
13 i16 x 1 13
14 i17 x 1 14
;
run;
```
check data and fit Rasch model using conditional maximum likelihood (CML)
```
%rasch_data(	data=knox,
            	item_names=in);
%rasch_CML( 	data=knox,
            	item_names=in,
		out=CML);
```
the item parameters are put in the data set CML_ipar. Estimate the person locations using
```
%rasch_ppar(	DATA=knox, 
		ITEM_NAMES=in, 
		DATA_IPAR=cml_ipar, 
		out=pp_cml);
```
this generates an output data set pp_cml_outdata
```
%rasch_itemfit(	DATA=knox, 
		ITEM_NAMES=in, 
		DATA_IPAR=cml_ipar, 
		DATA_POPPAR=pp_cml_outdata, 
		NCLASS=3, 
		OUT=fitcml);
```

