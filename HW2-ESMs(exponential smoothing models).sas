
/*@author: Jackie Zhang*/

/*********************/
/* PREPPING THE DATA */
/*********************/
proc import datafile='/opt/sas/home/yzhan272/sasuser.viya/Fall1 Time Series/Ozone_Raleigh2.csv'
	out=time.Ozone_Raleigh2
	dbms=csv
	replace;
	guessingrows=max;
run;

/* Asking SAS to automatically roll daily data into monthly data by what method it should use to roll;
	in here, we use accumulate=mean */
proc timeseries data=time.Ozone_Raleigh2 plots=(series decomp sc) out=table;
	id date interval=month accumulate=mean;
	var 'Daily Max 8-hour Ozone Concentra'n;
run;

/* Separating data into training, validation (last 17-5 months), and test (last 5 months)*/
data Ozone_Training Ozone_Valid Ozone_Test Ozone_Error;
	set table;
	if year(date)<2019 then output Ozone_Training;
	else if year(date)=2019 then output Ozone_Valid;
	else if year(date)=2020 then output Ozone_Test;
	else output Ozone_Error;
run;

/* Sanity Check */
proc print data=Ozone_Training;
run;

proc print data=Ozone_Valid;
run;

proc print data=Ozone_Test;
run;

proc print data=Ozone_Error;
run;

/****************************/
/* ESM explorations */
/****************************/
/* Creation of a monthly ESM forecast withholding the last 17 months (12 months for a validation data set and 5 months for the test data set). */

/* SIMPLE EXPONENTIAL SMOOTHING MODEL -----------------*/
* Create a simple exponential smoothing model --> MAPE=12.4479581;
proc esm data=Ozone_Training print=all plot=all lead=5;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=simple;
run;

/* LINEAR TREND FOR EXPONENTIAL SMOOTHING  -----------------*/

* Double exponential smoothing --> MAPE= 12.3232828; 
proc esm data=Ozone_Training print=all plot=all;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=double;
run;

* linear exponential smoothing --> MAPE=12.4507496; 
proc esm data=Ozone_Training print=all plot=all;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=linear;
run;


* damped trend exponential smoothing --> MAPE = 11.508294; 
proc esm data=Ozone_Training print=all plot=all;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=damptrend;
run;

/* SEASONAL EXPONENTIAL SMOOTHING MODEL -----------------*/

* Additive seasonal exponential smoothing model --> MAPE=5.63910776; 
proc esm data=Ozone_Training print=all plot=all seasonality=12;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=addseasonal;
run;

* mulitplicative seasonal exponential smoothing model --> MAPE=6.36694496; 
proc esm data=Ozone_Training print=all plot=all seasonality=12;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multseasonal;
run;


* Winters additive exponential smoothing model (includes trend) -->MAPE= 5.62331348; 
proc esm data=Ozone_Training print=all plot=all seasonality=12;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=addwinters;
run;

proc esm data=table print=all plot=all seasonality=12 back= 17;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=addwinters;
run;

* Winters multiplicative exponential smoothing model (includes trend) --> MAPE=6.37211825; 
proc esm data=Ozone_Training print=all plot=all seasonality=12;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multwinters;
run;

proc esm data=table print=all plot=all seasonality=12 back= 17;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multwinters;
run;

/*****/
/* based on training, we will do add/multi seasonal, and add/multi winters on validation
	to pick the final winner*/
/*****/

/*  
add seasonal  = 0.0668245 = 6.68%
mult seasonal = 0.0578480 = 5.78%
add winters   = 0.0653094 = 6.53%
mult winters  = 0.0580973 = 5.81%

######## we are picking MULT SEASONAL as it has lowest MAPE on validation! ########
*/

/* #### add seasonal #### */
proc esm data=table print=all plot=all seasonality=12 back= 17 lead=17 outfor=Valid_and_test;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=addseasonal;
run;

/* calculate APE and AE for each */
data add_seas_valid;
set Valid_and_test;
if year(date)=2019;
abs_error=abs(error);
abs_err_obs=abs_error/abs(actual);
run;

/* MAPE and MAE for add seasonal */
proc means data=add_seas_valid mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

/* #### mult seasonal #### */
proc esm data=table print=all plot=all seasonality=12 back= 17 lead=17 outfor=Valid_and_test;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multseasonal;
run;

/* calculate APE and AE for each */
data mul_seas_valid;
set Valid_and_test;
if year(date)=2019;
abs_error=abs(error);
abs_err_obs=abs_error/abs(actual);
run;

/* MAPE and MAE for mult seasonal */
proc means data=mul_seas_valid mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

/* one step */
proc esm data=table print=all plot=all lead=12 back=17;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multseasonal;
run;


/* #### add winters #### */
proc esm data=table print=all plot=all seasonality=12 back= 17 lead=17 outfor=Valid_and_test;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=addwinters;
run;

/* calculate APE and AE for each */
data add_winters_valid;
set Valid_and_test;
if year(date)=2019;
abs_error=abs(error);
abs_err_obs=abs_error/abs(actual);
run;

/* MAPE and MAE for additive winters*/
proc means data=add_winters_valid mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;


/* #### mult winters #### */
proc esm data=table print=all plot=all seasonality=12 back= 17 lead=17 outfor=Valid_and_test;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multwinters;
run;

/* calculate APE and AE for each */
data mult_winters_valid;
set Valid_and_test;
if year(date)=2019;
abs_error=abs(error);
abs_err_obs=abs_error/abs(actual);
run;

/* MAPE and MAE for additive winters*/
proc means data=mult_winters_valid mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;


/****************************/
/* TIME PLOT, DECOMPOSITION */
/****************************/

/* Creation of easy to read and interpret visualizations of the following: 
	Actual Ozone values overlaid with the trend/cycle component for the training set. 
	Actual Ozone values overlaid with the seasonally adjusted Ozone values for the training set. 
	--> classical technique because we are using SAS
*/
proc timeseries data=Ozone_Training plots=(series decomp TCC SA sc) out=monthly OUTDECOMP=monthly_DECOMP;
	id date interval=month;
	var 'Daily Max 8-hour Ozone Concentra'n;
run;


proc export data=WORK.monthly_DECOMP
			outfile='/opt/sas/home/yzhan272/sasuser.viya/Fall1 Time Series/time_hw2.xlsx'
			dbms=xlsx
			replace;
run;

/* Time Plot of the predicted versus actual for the validation and test data. */
proc esm data=table print=all plot=all seasonality=12 back= 17 lead=17 outfor=Valid_and_test_final;
	id date interval=month;
	forecast 'Daily Max 8-hour Ozone Concentra'n / model=multseasonal;
run;

proc export data=Valid_and_test_final
			outfile='/opt/sas/home/yzhan272/sasuser.viya/Fall1 Time Series/time_hw2_final_test.xlsx'
			dbms=xlsx
			replace;
run;


/****************************/
/* MAPE ON TEST DATA */
/****************************/
/* The client’s analysts are open to either additive or multiplicative ESM’s. */
/* The client uses Mean Absolute Percentage Error (MAPE) in calculating the accuracy of its forecasts.  
	Report this measure for the 5 months of forecasted Ozone values for the test data. 
	The client is open to other measurements in addition to the MAPE as long as they are clearly stated and supported. */

/* calculate APE and AE for each on the last 5 months */
data test_final;
set Valid_and_test_final;
if year(date)=2020;
abs_error=abs(error);
abs_err_obs=abs_error/abs(actual);
run;

/* MAPE and MAE for mult seasonal on test data --> 0.0897905 = 8.98% */
proc means data=test_final mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

