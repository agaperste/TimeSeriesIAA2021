/* 
UCM can handle back and lead.. so I think we can use the whole data? 
 */

proc sgplot data=time.AQ_weather_merged_imputed;
	series x=date y=ozone;
run;


/* Fitting a level 
	level's p-val in final estimate of free params table <0.001 --> significant --> stochastic 
*/
proc ucm data=time.AQ_weather_merged_imputed plots=all;
	level;
	irregular;
	model ozone;
	forecast back=42 lead=28;
run;

/* Fitting a level, slope and season component 
	slope and season both are not significant in both tables??
*/
proc ucm data=time.AQ_weather_merged_imputed plots=all;
	level;
	slope;
	season length=365 type=trig keeph=1 to 4;
	irregular;
	model ozone;
	estimate back=42 plot=(acf pacf wn); 
	forecast back=42 lead=28;
run;

/* level and season */
proc ucm data=time.AQ_weather_merged_imputed;
	level plot=smooth;
	season length=365 type=trig keeph=1 to 4 plot=smooth;
	irregular;
	model ozone;
	estimate back=42 plot=(acf pacf wn); 
	forecast back=42 lead=28;
run;

/* 
sp=1 sq=1 MAPE=0.0961926 with covid OKAY white noise
sp1 sq1 no keeph MAPE=0.1023427
p=1 q=1, MAPE=0.0961926 okay white noise

*** no p,q *** MAPE=0.1128938 meh white noise [note: other MAPE a little outdated] 
*/
/* using time.AQ_weather_good_validation because it has predicted no2 for validation period
 */
proc ucm data=time.AQ_weather_good_validation; *time.AQ_weather_merged_imputed;
	level plot=smooth;
	season variance = 0 noest length=365 type=trig plot=smooth keeph=1 to 18;
	irregular plot=smooth;
	model ozone = tmax prcp no2_pred covid;
	estimate back=28 plot=(acf pacf wn); 
	forecast back=28 lead=28;
	ods output PostSamplePrediction=validation_scoring; *time.aq_ucm_forecast_V1;
run;


/* ===== SCORING ======= */
data validation_scoring (keep=obs actual predict abs_error abs_err_obs);
	set validation_scoring;
    /* Generate fit statistics */
    abs_error = abs(predict-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 

proc means data=validation_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;


/* FINAL TEST SET modeling and scoring ------ */
/*
sp=1 sq=1, MAPE = 0.3511553, w/o covid, horrible white noise
sp=1 sq=1, MAPE = 0.2761179, with covid, but but still very bad white noise

*** no p q ***, MAPE = 0.2419281
*/

data temp_cmp;
	set time.aq_pred_final;
	if date >='01JUN2020'd then delete;
	if date >= '18MAY2020'd then ozone=.;
run;
/* !! if we are using predicted no2 all the way, then MAPE = 0.0999813 */


/* using time.AQ_weather_good_test because it has predicted no2 value for last 14 days*/
proc ucm data=temp_cmp; *time.AQ_weather_good_test; *time.AQ_weather_merged_imputed;
	level plot=smooth;
	season variance = 0 noest length=365 type=trig keeph=1 to 18 plot=smooth;
	irregular plot=smooth;
	model ozone = tmax prcp no2_pred covid;
	estimate back=14 plot=(acf pacf wn); 
	forecast back=14 lead=14 out=forecast;
	ods output PostSamplePrediction=test_scoring; *time.AQ_UCM_forecast;
run;

data test_scoring (keep=obs actual predict abs_error abs_err_obs);
	set test_scoring;
    /* Generate fit statistics */
    abs_error = abs(predict-actual);
    abs_err_obs=abs_error/abs(actual);
    format abs_error abs_err_obs percent8.2;
run; 

proc means data=test_scoring mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;