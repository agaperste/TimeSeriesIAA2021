/*=====================
	 VALIDATION
=====================*/
data time.aq_arima_forecast_V1;
	set time.aq_arima_forecast_V1 (rename=(forecast=arima_forecast));
run;

data time.aq_arimax_forecast_V1;
	set time.aq_arimax_forecast_V1 (rename=(forecast=arimax_forecast));
run;

data time.aq_ucm_forecast_V1;
	set time.aq_ucm_forecast_V1 (rename=(predict=ucm_forecast));
run;

/* ===== ARIMA, ARIMAX, UCM ==== */
data temp;
	merge time.aq_arima_forecast_V1(keep=arima_forecast) 
		time.aq_arimax_forecast_V1(keep=arimax_forecast) 
		time.aq_ucm_forecast_V1(keep=ucm_forecast actual);
run;

data temp2;
	set temp;
	average = (arima_forecast + arimax_forecast + ucm_forecast)/3;
	abs_error = abs(average-actual);
	abs_err_obs = abs_error/abs(actual);
run;

/* 
MAPE = 0.1580392
*/
proc means data=temp2 mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

/* ===== ARIMAX, UCM ==== */
data temp;
	merge time.aq_arimax_forecast_V1(keep=arimax_forecast) 
		time.aq_ucm_forecast_V1(keep=ucm_forecast actual);
run;

data temp2;
	set temp;
	average = (arimax_forecast + ucm_forecast)/2;
	abs_error = abs(average-actual);
	abs_err_obs = abs_error/abs(actual);
run;


/* 
MAPE = 0.1046550
*/
proc means data=temp2 mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

/*=====================
	 TEST
=====================*/
data time.aq_arima_forecast;
	set time.aq_arima_forecast (rename=(forecast=arima_forecast));
run;

data time.aq_arimax_forecast;
	set time.aq_arimax_forecast (rename=(forecast=arimax_forecast));
run;

data time.aq_ucm_forecast;
	set time.aq_ucm_forecast (rename=(predict=ucm_forecast));
run;

/* ===== ARIMAX, UCM ==== */
data temp3;
	merge time.aq_arimax_forecast(keep=arimax_forecast) 
		time.aq_ucm_forecast(keep=ucm_forecast actual);
run;

data temp4;
	set temp3;
	average = (arimax_forecast + ucm_forecast)/2;
	abs_error = abs(average-actual);
	abs_err_obs = abs_error/abs(actual);
run;


/* 
MAPE = 0.2872692

*/
proc means data=temp4 mean;
	var abs_error abs_err_obs;
	label abs_error = MAE abs_err_obs = MAPE;
run;

