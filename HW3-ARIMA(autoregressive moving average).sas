/* @author: Jackie Zhang */

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

/*=========================*/
/* Check for Stationarity */
/*=========================*/

/********************************************/
/* Augmented Dickey-Fuller tests up to lag 2*/
/********************************************/

/* trend --> slope = -2.4301E-8 --> not a trend*/
proc arima data=time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n crosscorr=date stationarity=(adf=2);
	estimate input=date;
run;

/* 0 mean, no trend 
--> all large p-values --> failed to reject null of random walk 
--> we have random walk*/
proc arima data=time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n stationarity=(adf=2);
	ods output StationarityTests=ADF_Test DescStats=Descriptive_State;
run;

/* export results to Excel */
proc export data=ADF_Test
outfile='[path you want to export to]/TSHW3_stationarity_before.xlsx'
dbms=xlsx
replace;
run;
proc export data=Descriptive_State
outfile='[path you want to export to]/TSHW3_desc_before.xlsx'
dbms=xlsx
replace;
run;

/* take first diffrence */
proc arima data=time.Ozone_Training plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n(1) stationarity=(adf=2);
	ods output StationarityTests=ADF_Test_2 DescStats=Descriptive_State_2;
run;

/* export results to Excel */
proc export data=ADF_Test_2
outfile='[path you want to export to]/TSHW3_stationarity_after.xlsx'
dbms=xlsx
replace;
run;
proc export data=Descriptive_State_2
outfile='[path you want to export to]/TSHW3_desc_after.xlsx'
dbms=xlsx
replace;
run;

/*=======================*/
/* Check for White Noise */
/*=======================*/

/* without fitting AR or MA, check the white noise plot
	--> not white noise */
proc arima data=time.Ozone_Raleigh_monthly plot=all;
	identify var='Daily Max 8-hour Ozone Concentra'n(1) stationarity=(adf=2) nlag=24;
	estimate method=ml outest=outest;
	ods output ResidualCorrPanel=Residual_Correlation;
run;

/* export residuals to Excel */
proc export data=Residual_Correlation
outfile='[path you want to export to]/TSHW3_Residual_Correlation.xlsx'
dbms=xlsx
replace;
run;

