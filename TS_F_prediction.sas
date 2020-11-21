/*=====================
	 UCM predictions
=====================*/

proc ucm data=time.AQ_weather_good_final;
	level plot=smooth;
	season variance = 0 noest length=365 type=trig keeph=1 to 18 plot=smooth;
	irregular plot=smooth;
	model ozone = tmax prcp no2_pred covid;
	estimate back=14 plot=(acf pacf wn); 
	forecast lead=14 out=time.AQ_ozone_june_forecast;
run;