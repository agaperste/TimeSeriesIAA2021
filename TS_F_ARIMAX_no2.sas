/* ==================================================
	ARIMA on my no2 
	-starting file: AQ_weather_final_pred.csv
	-which contains 
		date (till 6/14/20), 
		no2, (last 14 days left blank)
		prcp, tmax (fully filled in)
   ==================================================*/

/*===========================================================================
prep validation scoring data, mainly adding 04/20/2020-05/17/2020 co2 pred 
-->time.AQ_weather_good_validation
===========================================================================*/
proc timeseries data=time.AQ_weather_final_pred plots=(series decomp sc) out=AQ_weather_valid_pred;
	id date interval=day;
	var ozone TMAX PRCP NO2;
run;

proc expand data=AQ_weather_valid_pred out=AQ_weather_valid_pred2;
	id date;
run;

data AQ_weather_valid_pred3;
	set AQ_weather_valid_pred2;
	if month(date)=2 and day(date)=29 then delete;
	if date > '01mar2020'd then covid = 1; else covid = 0;
run;

/* predicting 04/20-5/17 no2 for UCM model */
data AQ_weather_valid_pred4;
	set AQ_weather_valid_pred3;
	if date >= '18MAY2020'd then delete;
	if date >= '20APR2020'd then no2= .;
run;

data AQ_weather_valid_pred4;
	set AQ_weather_valid_pred4;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/365);
	c1=cos(2*pi*1*_n_/365);
	s2=sin(2*pi*2*_n_/365);
	c2=cos(2*pi*2*_n_/365);
	s3=sin(2*pi*3*_n_/365);
	c3=cos(2*pi*3*_n_/365);
	s4=sin(2*pi*4*_n_/365);
	c4=cos(2*pi*4*_n_/365);
	s5=sin(2*pi*4*_n_/365);
	c5=cos(2*pi*4*_n_/365);
run;


proc arima data=AQ_weather_valid_pred4 plot=all;
	identify var=no2 crosscor=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5) nlag=60;
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5) p=3 q=3 method=ML;
	forecast lead=28 out=AQ_weather_valid_pred5;
run;

/* taking the predicted no2 and append only those to end of no2 for later usage*/
data AQ_weather_valid_pred6 (keep=no2_pred no2);
	set AQ_weather_valid_pred5(rename=(forecast=no2_pred));
run;

data AQ_weather_valid_pred7;
	merge AQ_weather_valid_pred4 AQ_weather_valid_pred6;
run;

data temp1;
	set AQ_weather_valid_pred7 (keep=date no2);
	if date >= '20APR2020'd then delete;
run;
data temp2;
	set AQ_weather_valid_pred7 (keep=date no2_pred);
	if date < '20APR2020'd then delete;
run;
data temp3;
	set temp2(rename=(no2_pred=NO2));
run;
proc append base=temp1 data=temp3;
run;

data time.AQ_weather_good_validation;
	merge AQ_weather_valid_pred7 temp1(rename=(no2=no2_pred));
	by date;
run;

/*===========================================================================
	time.AQ_weather_good_test
	-adding/replacing predicted no2 values to the end of no2 for scoring test
===========================================================================*/

/* prep test scoring data, mainly adding 05/18/2020-05/31/2020 co2 pred */
proc timeseries data=time.AQ_weather_final_pred plots=(series decomp sc) out=AQ_weather_test_pred;
	id date interval=day;
	var ozone TMAX PRCP NO2;
run;

proc expand data=AQ_weather_test_pred out=AQ_weather_test_pred2;
	id date;
run;

data AQ_weather_test_pred3;
	set AQ_weather_test_pred2;
	if month(date)=2 and day(date)=29 then delete;
	if date > '01mar2020'd then covid = 1; else covid = 0;
run;

/* predicting 5/18-5/31 no2 for UCM model */
data AQ_weather_test_pred4;
	set AQ_weather_test_pred3;
	if date >= '01JUN2020'd then delete;
	if date >= '18MAY2020'd then no2= .;
run;

data AQ_weather_test_pred4;
	set AQ_weather_test_pred4;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/365);
	c1=cos(2*pi*1*_n_/365);
	s2=sin(2*pi*2*_n_/365);
	c2=cos(2*pi*2*_n_/365);
	s3=sin(2*pi*3*_n_/365);
	c3=cos(2*pi*3*_n_/365);
	s4=sin(2*pi*4*_n_/365);
	c4=cos(2*pi*4*_n_/365);
	s5=sin(2*pi*4*_n_/365);
	c5=cos(2*pi*4*_n_/365);
run;


proc arima data=AQ_weather_test_pred4 plot=all;
	identify var=no2 crosscor=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5) nlag=60;
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5) p=3 q=3 method=ML;
	forecast lead=14 out=AQ_weather_test_pred5;
run;

/* taking the predicted no2 and append only those to end of no2 for later usage*/
data AQ_weather_test_pred6 (keep=no2_pred no2);
	set AQ_weather_test_pred5(rename=(forecast=no2_pred));
run;

data AQ_weather_test_pred7;
	merge AQ_weather_test_pred4 AQ_weather_test_pred6;
run;

data temp1;
	set AQ_weather_test_pred7 (keep=date no2);
	if date >= '18MAY2020'd then delete;
run;
data temp2;
	set AQ_weather_test_pred7 (keep=date no2_pred);
	if date < '18MAY2020'd then delete;
run;
data temp3;
	set temp2(rename=(no2_pred=NO2));
run;
proc append base=temp1 data=temp3;
run;

data time.AQ_weather_good_test;
	merge AQ_weather_test_pred7 temp1(rename=(no2=no2_pred));
	by date;
run;

/*===========================================================================
	time.AQ_weather_good_final
	-adding/replacing predicted no2 values to the end of no2 for predicting june
===========================================================================*/

/* prep test scoring data, mainly adding 06/01/2020-06/14/2020 co2 pred */
proc timeseries data=time.AQ_weather_final_pred plots=(series decomp sc) out=AQ_weather_final_pred;
	id date interval=day;
	var ozone TMAX PRCP NO2;
run;

proc expand data=AQ_weather_final_pred out=AQ_weather_final_pred2;
	id date;
run;

data AQ_weather_final_pred3;
	set AQ_weather_final_pred2;
	if month(date)=2 and day(date)=29 then delete;
	if date > '01mar2020'd then covid = 1; else covid = 0;
run;

/* predicting 5/18-5/31 no2 for UCM model */
data AQ_weather_final_pred4;
	set AQ_weather_final_pred3;
	if date >= '01JUN2020'd then no2= .;
run;

data AQ_weather_final_pred4;
	set AQ_weather_final_pred4;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/365);
	c1=cos(2*pi*1*_n_/365);
	s2=sin(2*pi*2*_n_/365);
	c2=cos(2*pi*2*_n_/365);
	s3=sin(2*pi*3*_n_/365);
	c3=cos(2*pi*3*_n_/365);
	s4=sin(2*pi*4*_n_/365);
	c4=cos(2*pi*4*_n_/365);
	s5=sin(2*pi*4*_n_/365);
	c5=cos(2*pi*4*_n_/365);
run;


proc arima data=AQ_weather_final_pred4 plot=all;
	identify var=no2 crosscor=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5) nlag=60;
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4 s5 c5) p=3 q=3 method=ML;
	forecast lead=14 out=AQ_weather_final_pred5;
run;

/* taking the predicted no2 and append only those to end of no2 for later usage*/
data AQ_weather_final_pred6 (keep=no2_pred no2);
	set AQ_weather_final_pred5(rename=(forecast=no2_pred));
run;

data AQ_weather_final_pred7;
	merge AQ_weather_final_pred4 AQ_weather_final_pred6;
run;

data temp1;
	set AQ_weather_final_pred7 (keep=date no2);
	if date >= '18MAY2020'd then delete;
run;
data temp2;
	set AQ_weather_final_pred7 (keep=date no2_pred);
	if date < '18MAY2020'd then delete;
run;
data temp3;
	set temp2(rename=(no2_pred=NO2));
run;
proc append base=temp1 data=temp3;
run;

data time.AQ_weather_good_final;
	merge AQ_weather_final_pred7 temp1(rename=(no2=no2_pred));
	by date;
run;