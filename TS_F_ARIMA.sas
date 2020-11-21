/* 
-------------------------------------
     Imputations and Leap Years             
------------------------------------- 
*/

/* ozone training ----------------- */
proc timeseries data=time.AQ_weather_merged plots=(series decomp sc) out=temp;
	id date interval=day;
	var ozone;
run;

/* by default, the EXPAND procedure fits cubic spline curvees to the nonmissing values of variables to 
	form continuous-time approximations of the input series. 
	Output series are then generated from the spline approximations.
 */
proc expand data=temp out=time.AQ_weather_merged_imputed;
	id date;
run;

data time.AQ_weather_merged_imputed;
	set time.AQ_weather_merged_imputed;
	if month(date)=2 and day(date)=29 then delete;
run;

data time.AQ_weather_merged_imputed;
	set time.AQ_weather_merged_imputed;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/365);
	c1=cos(2*pi*1*_n_/365);
	s2=sin(2*pi*2*_n_/365);
	c2=cos(2*pi*2*_n_/365);
	s3=sin(2*pi*3*_n_/365);
	c3=cos(2*pi*3*_n_/365);
	s4=sin(2*pi*4*_n_/365);
	c4=cos(2*pi*4*_n_/365);
run;

/* 
-------------------------------------
     Train, Validate, and Test             
------------------------------------- 
*/
data time.AQ_train time.AQ_validation time.AQ_test;
	set time.AQ_weather_merged_imputed;
	if date < '20Apr2020'd then output time.AQ_train;
	else if date < '18May2020'd then output time.AQ_validation;
	else output time.AQ_test;
run;

proc print data=time.AQ_train (obs=5);
run;


/* 
-------------------------------------
      Seasonal ARIMA            
------------------------------------- 
*/

/* modeling seasonality using Fourier  */
proc arima data=time.AQ_train plot=all;
	identify var=ozone crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4);
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4) 
	method=ML;
	forecast out=trig lead=0;
run;

/* look at its residuals, we have stationarity */
data trig2;
set trig;
time = _n_;
run;
proc sgplot data=trig2;
	series x=time y=residual;
run;

proc arima data=trig;
	identify var=residual stationarity=(adf=2);
/* 	identify var=residual stationarity=(adf=2 dlag=12); */
run;

/* Now that it is stationary...find best AR and MA terms  */

proc arima data=Time.AQ_train plot=all;
	identify var=ozone nlag=60 minic P=(0:60) Q=(0:60);
run; 
/* (1,4); */

proc arima data=Time.AQ_train plot=all;
	identify var=ozone nlag=60 scan P=(0:60) Q=(0:60);
run;
/* (2, 1) (1, 4) (0, 59) (60, 0)*/

proc arima data=Time.AQ_train plot=all;
	identify var=ozone nlag=60 esacf P=(0:60) Q=(0:60);
run;
/*  
1	4
2	4
5	6
11	11
12	11
0	59
*/

/*  AIC
1,4 --> -15878.5
2,1 --> -15879.6
2,4 --> -15876.8
*/
proc arima data=time.AQ_train plot=all;
	identify var=ozone  crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4) nlag=60;
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4) p=2 q=1 method=ML;
	forecast out=trig lead=0;
run;

/* Scoring training on validation -------------*/
data temp;
	set time.AQ_validation (keep=date);
run;

data ozone_daily_training_pred;
	set time.AQ_train (keep=date ozone);
run;

proc append base=ozone_daily_training_pred data=temp force;
run;

data ozone_daily_training_pred;
	set ozone_daily_training_pred;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/365);
	c1=cos(2*pi*1*_n_/365);
	s2=sin(2*pi*2*_n_/365);
	c2=cos(2*pi*2*_n_/365);
	s3=sin(2*pi*3*_n_/365);
	c3=cos(2*pi*3*_n_/365);
	s4=sin(2*pi*4*_n_/365);
	c4=cos(2*pi*4*_n_/365);
run;

proc arima data=ozone_daily_training_pred plot=all;
	identify var=ozone  crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4) nlag=60;
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4) p=2 q=4 method=ML;
	forecast out=forecast lead=28; *time.aq_arima_forecast_V1;
run;


data validation_scoring (keep=date actual forecast abs_error abs_err_obs);
	merge time.AQ_train (rename=(ozone=actual))
		forecast;
    /* Generate fit statistics */
    abs_error = abs(Forecast-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 

/* MAPE  
p=1 q=4 --> 0.1774266
p=2 q=1 --> 0.1775043
p=2 q=4 --> 0.1773832
*/
proc means data=validation_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;


/* Scoring on test -------------*/
data AQ_valid_pred;
	set time.AQ_weather_merged_imputed;
	if date >= '18MAY2020'd then ozone= .;
run;


data AQ_valid_pred;
	set AQ_valid_pred;
	pi=constant("pi");
	s1=sin(2*pi*1*_n_/365);
	c1=cos(2*pi*1*_n_/365);
	s2=sin(2*pi*2*_n_/365);
	c2=cos(2*pi*2*_n_/365);
	s3=sin(2*pi*3*_n_/365);
	c3=cos(2*pi*3*_n_/365);
	s4=sin(2*pi*4*_n_/365);
	c4=cos(2*pi*4*_n_/365);
run;


proc arima data=AQ_valid_pred plot=all;
	identify var=ozone  crosscorr=(s1 c1 s2 c2 s3 c3 s4 c4) nlag=60;
	estimate input=(s1 c1 s2 c2 s3 c3 s4 c4) p=2 q=4 method=ML;
	forecast lead=14;
	ods output forecasts = validation_scoring; *time.AQ_ARIMA_forecast;
run;

data validation_scoring (keep=date actual forecast abs_error abs_err_obs);
	merge time.AQ_test (rename=(ozone=actual))
		validation_scoring;
    /* Generate fit statistics */
    abs_error = abs(Forecast-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 

/* 
having 4, 12, and 24 fourier yields the same MAPE
MAPE = 0.4699725

*/
proc means data=validation_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;






