/* 
Good Candidate:
1. TMAX- highly correlated, highly related
2. PRECIPITATION- high-ish correlation, correlated in the literature (comparatively)
3. CO (precursor)
4. NO2 (precursor)
5. WSF2 - low wind speeds required for formation of ozone
*/

/* 
-------------------------------------
     Imputations and Leap Years             
------------------------------------- 
*/

proc timeseries data=time.AQ_weather_merged plots=(series decomp sc) out=AQ_weather_merged;
	id date interval=day;
	var ozone TMAX PRCP CO NO2 WSF2;
run;

proc expand data=AQ_weather_merged out=time.AQ_weather_merged_imputed;
	id date;
run;

data time.AQ_weather_merged_imputed;
	set time.AQ_weather_merged_imputed;
	if month(date)=2 and day(date)=29 then delete;
run;

data time.AQ_weather_merged_imputed;
	set time.AQ_weather_merged_imputed;
	tmax1=lag1(TMAX);
	tmax2=lag2(TMAX);
	tmax3=lag3(TMAX);
	tmax4=lag4(TMAX);
	tmax5=lag5(TMAX);
	tmax6=lag6(TMAX);
	tmax7=lag7(TMAX);
	prcp1=lag1(PRCP);
	prcp2=lag2(PRCP);
	prcp3=lag3(PRCP);
	prcp4=lag4(PRCP);
	prcp5=lag5(PRCP);
	prcp6=lag6(PRCP);
	prcp7=lag7(PRCP);
	co1=lag1(CO);
	co2=lag2(CO);
	co3=lag3(CO);
	co4=lag4(CO);
	co5=lag5(CO);
	co6=lag6(CO);
	co7=lag6(CO);
	no21=lag1(NO2);
	no22=lag2(NO2);
	no23=lag3(NO2);
	no24=lag4(NO2);
	no25=lag5(NO2);
	no26=lag6(NO2);
	no27=lag7(NO2);
	wsf21=lag1(WSF2);
	wsf22=lag2(WSF2);
	wsf23=lag3(WSF2);
	wsf24=lag4(WSF2);
	wsf25=lag5(WSF2);
	wsf26=lag6(WSF2);
	wsf27=lag7(WSF2);
	if date > '01mar2020'd then covid = 1; else covid = 0;
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
              ARIMAX            
------------------------------------- 
*/

*most of what was selected is co and no, because those are what contribute to ozone formation; 
*so is not supposed to contribute to ozone formation apparently according to the literature;

*selection using bic;
proc glmselect data=time.AQ_train;
	model ozone= tmax tmax1 tmax2 tmax3 tmax4 tmax5 tmax6 tmax7 
	prcp prcp1 prcp2 prcp3 prcp4 prcp5 prcp6 prcp7
	co co1 co2 co3 co4 co5 co6 co7
	no2 no21 no22 no23 no24 no25 no26 no27
	wsf2 wsf21 wsf22 wsf23 wsf24 wsf25 wsf26 wsf27 covid/selection=backward select=BIC;
run;

*selection using aicc instead of aicc ;
proc glmselect data=time.AQ_train;
	model ozone= tmax tmax1 tmax2 tmax3 tmax4 tmax5 tmax6 tmax7 
	prcp prcp1 prcp2 prcp3 prcp4 prcp5 prcp6 prcp7
	co co1 co2 co3 co4 co5 co6 co7
	no2 no21 no22 no23 no24 no25 no26 no27
	wsf2 wsf21 wsf22 wsf23 wsf24 wsf25 wsf26 wsf27 covid/selection=backward select=AICC;
run;


*NEXT STEP: TO CAPTURE SEASONALITY: TRY TO PUT IN THE TRIG FUNCTIONS ALONGSIDE THE VARIABLES THAT WERE SELECTED FOR USING BIC AND AICC;
/* BIC's AIC = -16324.5*/
proc arima data=time.AQ_train;
identify var=ozone crosscorr=(tmax prcp co no2 wsf2 covid);
estimate input =((3) tmax /(1) prcp /(1) co (1,6) no2 /(1) wsf2) p=1 q=3 method=ML;
forecast lead=0 out=residreg;
run;

/* model 2 AICC adapted AIC = -16157.9 
p=2 q=4, or (1,4) did not converge
*/
proc arima data=time.AQ_train;
identify var=ozone crosscorr=(tmax prcp co no2 wsf2 covid);
estimate input =((1) tmax 1$/(1) prcp 1$/(1) co 1$/(1) no2 1$/(1) wsf2 covid) p=1 q=3 method=ML;
forecast lead=0 out=residreg;
run;

/* three times is the charm 
	p=2 q=4 AIC = -16287.6 
	p=1 q=3 AIC = -16282.6
	p=1 q=4 AIC = -16287.5 best white noise
*/
proc arima data=time.AQ_train;
identify var=ozone crosscorr=(tmax prcp co no2 covid);
estimate input =(tmax (1) prcp (6) co  (1) no2 covid) p=1 q=4 method=ML;
forecast lead=0 out=residreg;
run;

/* model 4 AIC = -16309.9 good white noise*/
proc arima data=time.AQ_train;
identify var=ozone crosscorr=(tmax prcp no2 covid);
estimate input =(tmax prcp no2 covid) p=1 q=4 method=ML;
forecast lead=0 out=residreg;
run;

/* checking VIF */
proc reg data=time.AQ_train;
	model ozone = tmax prcp no2 covid /vif;
run;

data residreg2;
set residreg;
time = _n_;
run;
proc sgplot data=residreg2;
	series x=time y=residual;
run;

proc arima data=residreg;
	identify var=residual stationarity=(adf=2);
run;

/* Scoring training on validation -------------*/
data AQ_train_pred;
	set time.AQ_train;
run;

proc append base=AQ_train_pred data=time.AQ_validation force;
run;

data AQ_train_pred;
	set AQ_train_pred;
	if date >= '20APR2020'd then ozone= .;
run;

/* inserting in predicted no2 as a new column/variale */
data temp_no2 (keep=no2_pred no2);
	set time.aq_no2_prediction_v(rename=(forecast=no2_pred));
run;

data AQ_train_pred_2;
	merge AQ_train_pred temp_no2;
run;

proc arima data=AQ_train_pred_2;
	identify var=ozone crosscorr=(tmax prcp no2_pred covid);
	estimate input =(tmax prcp no2_pred covid) p=1 q=4 method=ML;

	forecast lead=28;
	ods output Forecasts= forecast; *TIME.aq_arimax_forecast_V1;
run;

data validation_scoring (keep=date actual forecast abs_error abs_err_obs);
	merge time.AQ_validation (rename=(ozone=actual))
		forecast;
    /* Generate fit statistics */
    abs_error = abs(Forecast-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 

/*  
model 2 MAPE = 0.0960884
model 3 MAPE = 0.0918418
model 4 MAPE = 0.0929509

model 4 with no2_pred MAPE=0.0998763
*/
proc means data=validation_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

/* ====== Scoring on TEST -------------*/
data AQ_valid_pred;
	set time.AQ_weather_merged_imputed;
	if date >= '18MAY2020'd then ozone= .;
run;

/* inserting in predicted no2 as a new column/variale */
data temp_no2 (keep=no2_pred no2);
	set time.aq_no2_prediction_t(rename=(forecast=no2_pred));
run;

data AQ_valid_pred_2;
	merge AQ_valid_pred temp_no2;
run;

proc arima data=AQ_valid_pred_2;
	identify var=ozone crosscorr=(tmax prcp no2_pred covid);
	estimate input =(tmax prcp no2_pred covid) p=1 q=4 method=ML;
	forecast lead=14;
	ods output Forecasts=forecast ; *time.AQ_ARIMAX_forecast;
run;

data test_scoring (keep=date actual forecast abs_error abs_err_obs);
	merge time.ozone_daily_test (rename=('Daily Max 8-hour Ozone Concentra'n=actual))
		forecast;
    /* Generate fit statistics */
    abs_error = abs(Forecast-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 

/*  
model 2 MAPE = can't converge
model 3 MAPE = 0.3677495
model 4 MAPE = 0.3677495

model 4 using predicted NO2 MAPE: 0.3381326
*/
proc means data=test_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;
