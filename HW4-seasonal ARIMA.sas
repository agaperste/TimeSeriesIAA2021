/*===========================================*/
/* Prepping Raleigh monthly ozone level data */
/*===========================================*/
libname time '[path to your time library]';

proc import datafile='[path to your dataset]'
	out=time.Ozone_Raleigh2
	dbms=csv
	replace;
	guessingrows=max;
run;

/* rolling daily data into monthly, by taking the mean */
proc timeseries data=time.Ozone_Raleigh2 plots=(series decomp sc) out=time.Ozone_Raleigh_monthly;
	id date interval=month accumulate=mean;
	var 'Daily Max 8-hour Ozone Concentra'n;
run;

/* separate data into training, validation, and test */
data time.Ozone_Training time.Ozone_Valid time.Ozone_Test;
	set time.Ozone_Raleigh_monthly;
	if year(date)<2019 then output time.Ozone_Training;
	else if year(date)=2019 then output time.Ozone_Valid;
	else if year(date)=2020 then output time.Ozone_Test;
run;

/* decomposition to examine seasonality and trend */
proc timeseries data=Time.Ozone_Raleigh_monthly plots=(series decomp sc) seasonality=12;
	var 'Daily Max 8-hour Ozone Concentra'n;
run;

/*================================*/
/*|  		SEASONALITY	 	 	 |*/
/*================================*/

/*====== Seaonal ADF Test ========*/
/* zero mean --> failed to reject --> seasonal random walk 
	single mean --> reject H0 --> deterministic seasonal
*/
proc arima data=time.Ozone_training;
	identify var='Daily Max 8-hour Ozone Concentra'n stationarity=(adf=2 dlag=12);
run;

/*======== dummy variables ========*/
/* AIC: -525.084 */
data time.Ozone_training_dummy;
	set time.Ozone_training;
	if month(date)=1 then seas1=1; else seas1=0;
	if month(date)=2 then seas2=1; else seas2=0;
	if month(date)=3 then seas3=1; else seas3=0;
	if month(date)=4 then seas4=1; else seas4=0;
	if month(date)=5 then seas5=1; else seas5=0;
	if month(date)=6 then seas6=1; else seas6=0;
	if month(date)=7 then seas7=1; else seas7=0;
	if month(date)=8 then seas8=1; else seas8=0;
	if month(date)=9 then seas9=1; else seas9=0;
	if month(date)=10 then seas10=1; else seas10=0;
	if month(date)=11 then seas11=1; else seas11=0;
run;

* Fit an ARIMA model and obtain a forecast; 
proc arima data=time.Ozone_training_dummy;
	identify var='Daily Max 8-hour Ozone Concentra'n 
		crosscorr=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11);
	estimate p=(12) input=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11) 
		method=ml;
run;

/*======== Trig functions ========*/
/* AIC: -524.56 */
data time.Ozone_training_trig;
	set time.Ozone_training_dummy;;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/12);
	c1=cos(2*pi*1*_n_/12);
	s2=sin(2*pi*2*_n_/12);
	c2=cos(2*pi*2*_n_/12);
	s3=sin(2*pi*3*_n_/12);
	c3=cos(2*pi*3*_n_/12);
	s4=sin(2*pi*4*_n_/12);
	c4=cos(2*pi*4*_n_/12);
run;

* Fit an ARIMA model using this sine & cosine data; 
proc arima data=time.Ozone_training_trig plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n  crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4);
	estimate q=(12) input=(s1 c1 s2 c2 s3 c3 s4 c4);
run;

/*================================*/
/*|  		   TREND   	 	 	 |*/
/*================================*/

/*====== ADF Test ========*/
/* with trend --> slope = -2.4301E-8 --> not a trend*/
proc arima data=time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n crosscorr=date stationarity=(adf=2);
	estimate input=date;
run;

/* 0 mean, no trend 
--> all large p-values --> failed to reject null of random walk 
--> we have random walk */
proc arima data=time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n stationarity=(adf=2);
/* 	ods output StationarityTests=ADF_Test DescStats=Descriptive_State; */
run;

/* take first diffrence --> we got stationarity */
proc arima data=time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n(1) stationarity=(adf=2);
/* 	ods output StationarityTests=ADF_Test_2 DescStats=Descriptive_State_2; */
run;

/*================================*/
/*|  		   AR MA   	 	 	 |*/
/*================================*/

* MINIC --> BIC(12,11) = -46.984; 
proc arima data=Time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n nlag=12 minic P=(0:12) Q=(0:12);
run;

* SCAN --> (p+d, q) = (2,1) or (6, 0); 
proc arima data=Time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n nlag=12 scan P=(0:12) Q=(0:12);
run;

* ESACF -->(p+d, q) = (2,1),(3, 1),(5,2),(10,2), (9,5), (1,7), (11,2), (12,1),(0,12); 
proc arima data=Time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n nlag=12 esacf P=(0:12) Q=(0:12);
run;

/*================================*/
/*|  		model fitting  	 	  |*/
/*================================*/

proc arima data=time.Ozone_training_dummy;
	identify var='Daily Max 8-hour Ozone Concentra'n 
		crosscorr=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11);
	estimate p=2 q=(1,12) input=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11) 
		method=ml;
run;

/* AIC
	(2,1): -516.231, good white noise --> winner!
	(2,1)(0,1): -526.783, but better ACF and PACF graphs --> winner?
	(3,1): -515.295, even better white noise
	(5,2): -510.074, solid white noise
	(0,12): -525.084, good white noise
	(1, 12): -537.166, decent white noise
 */


data temp;
input date;
datalines;
1
2
3
4
5
6
7
8
9
10
11
12
;
run;

data Ozone_training_superV;
set time.Ozone_training (keep=date 'Daily Max 8-hour Ozone Concentra'n);
run;

proc append base=Ozone_training_superV data=temp force;
run;

data Ozone_training_superV;
	set Ozone_training_superV;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/12);
	c1=cos(2*pi*1*_n_/12);
	s2=sin(2*pi*2*_n_/12);
	c2=cos(2*pi*2*_n_/12);
	s3=sin(2*pi*3*_n_/12);
	c3=cos(2*pi*3*_n_/12);
	s4=sin(2*pi*4*_n_/12);
	c4=cos(2*pi*4*_n_/12);
run;

/*  */
/* data Ozone_training_superV; */
/* 	set Ozone_training_superV; */
/* 	if date=1 then seas1=1; else seas1=0; */
/* 	if date=2 then seas2=1; else seas2=0; */
/* 	if date=3 then seas3=1; else seas3=0; */
/* 	if date=4 then seas4=1; else seas4=0; */
/* 	if date=5 then seas5=1; else seas5=0; */
/* 	if date=6 then seas6=1; else seas6=0; */
/* 	if date=7 then seas7=1; else seas7=0; */
/* 	if date=8 then seas8=1; else seas8=0; */
/* 	if date=9 then seas9=1; else seas9=0; */
/* 	if date=10 then seas10=1; else seas10=0; */
/* 	if date=11 then seas11=1; else seas11=0; */
/* run; */



* Fit an ARIMA model using this sine & cosine data; 
proc arima data=Ozone_training_superV plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n  crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4);
	estimate p=2 q=(1,12) input=(s1 c1 s2 c2 s3 c3 s4 c4);
	forecast lead=12 out=forecast nooutall;
run;

/* proc arima data=Ozone_training_superV; */
/* 	identify var='Daily Max 8-hour Ozone Concentra'n  */
/* 		crosscorr=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11); */
/* 	estimate p=2 q=(1,12) input=(seas1 seas2 seas3 seas4 seas5 seas6 seas7 seas8 seas9 seas10 seas11)  */
/* 		method=ml; */
/* run; */

/*================================*/
/*|  	      Scoring   	     |*/
/*================================*/

data validation_scoring (keep=date actual forecast abs_error abs_err_obs);
	merge time.Ozone_valid (rename=('Daily Max 8-hour Ozone Concentra'n=actual))
		forecast;
    /* Generate fit statistics */
    abs_error = abs(Forecast-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 


/* MAPE  
(2,1) = 0.0585077 
(2,1)(0,1) = 0.0739214
*/

proc means data=validation_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

/* TODO need to roll train+valid and score on test dataset */
