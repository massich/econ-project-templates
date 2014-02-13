/*** This `1' computes the IV estimates and confidence intervals for table 3 
and stores the results in "iv_estimation_i.dta" ***/

// Header do-`1' with path definitions, those end up in global macros.
include src/library/stata/project_paths
log using `"${PATH_OUT_ANALYSIS}/log/`1'_`2'.log"', replace

// Delete these lines -- just to check whether everything caught correctly.
adopath
macro list

set output error

# delimit ;

version 10.1 ;

/* COMPUTES ANDERSON-RUBIN (1949) CONFIDENCE INTERVALS 
INCLUDING CLUSTERING EFFECTS 
Warning: May take some time to run  */


set more off;
set mat 800;
set graphics on;

	drop _all ;

	local v1 = " ";
	local v2 = " lat";
	local v3 = " ";    
	local v4 = " asia africa other";
	local v5 = " asia africa other lat";
	local v6 = " edes1975 ";
	local v7 = " malaria ";

	local if3 = " if neoeuro==0 " ;

	local depvar   = "loggdp" ;
	local instd    = "risk"  ;
	local insts    = "logmort0" ;

	local range    = "-20(.01)20";
	local range2a   = -5 ;
	local range2b   = +5 ;


	/***DIFFERENT DATASET SPECIFICATIONS FOR FIRST STAGE AND IV ESTIMATION:
		1 = PANEL_A: Original mortality data (64 countries)
		2 = PANEL_B: Only countries with non-conjectured mortality rates (rest: 28 countries)
		3 = PANEL_C: Original data (64 countries) with campaign and laborer indicators
		4 = PANEL_D: Only countries with non-conjectured mortality rates and campaign and laborer indicators 
		5 = PANEL_E: As Panel D with new data provided by AJR
	***/
	
local T = `2' ; //This is necessary for case distinction
 

	input beta fstat pval inci;
	. . . . . ;
	end; 
	save `"${PATH_OUT_ANALYSIS}/`1'/ci"',replace;
	

	use `"${PATH_IN_DATASET_1}/ajrcomment"',replace;
	
	/*** Define panel specific input ***/
		
		if inlist(`T',2,4,5) {;
				keep if source0==1;
		};
		if inlist(`T',3,4,5) local dummies = "campaign slave" ;  

		replace `insts' = log(285) if inlist(short,"HKG") & `T'==5 ;
		replace `insts' = log(189) if inlist(short,"BHS") & `T'==5 ;
		replace `insts' = log(14.1) if inlist(short,"AUS") & `T'==5 ;
		replace `insts' = log(95.2) if inlist(short,"HND") & `T'==5 ;
		replace `insts' = log(84) if inlist(short,"GUY") & `T'==5 ;
		replace `insts' = log(20) if inlist(short,"SGP") & `T'==5 ;
		replace campaign = 0 if inlist(short,"HND") & `T'==5 ;

		replace `insts' = log(106.3) if inlist(short,"TTO") & `T'==5 ;
		replace `insts' = log(350) if inlist(short,"SLE") & `T'==5 ;


	save `"${PATH_OUT_ANALYSIS}/`1'/ajrdata_temp.dta"', replace ;

	
	forva N = 1(1)7 {;
		
	use `"${PATH_OUT_ANALYSIS}/`1'/ci"', replace;
	save `"${PATH_OUT_ANALYSIS}/`1'/ci_`N'"', replace ;

	local controls = " `v`N'' `dummies' " ;

	use `"${PATH_OUT_ANALYSIS}/`1'/ajrdata_temp.dta"', replace ;


	if inlist(`N',3) { ; keep `if`N'' ; } ;


	reg `instd' `insts' `controls'  , cluster(`insts') ;
	test `insts' ;
	scalar firstf`N' = r(F) ;
	scalar firstt`N' = sqrt(firstf`N') ;

	ivreg `depvar' (`instd' = `insts') `controls'  , cluster(`insts');
	mat b = e(b);

	mat point`N' = _b[`instd'] ;
	mat se`N' = _se[`instd'] ;

	scalar betahat = b[1,1];
	local j = e(N_clust) ;
	local n = e(N);
	local k = e(df_m) ;

	qui for V in any `depvar' `instd' `insts' :
		qui reg V `controls'  \
		qui predict Vr, resid ;

	keep `depvar' `instd' `insts' `controls'  `depvar'r `instd'r `insts'r ;

	reg `instd'r `insts'r , cluster(`insts'r) ;
	test `insts'r ;
	scalar firstfr`N' = r(F)*(`n'-`k'-1)/(`n'-1) ;

	save `"${PATH_OUT_ANALYSIS}/`1'/tempdata"', replace;
	drop _all;



	forvalues X = `range' { ;
		use `"${PATH_OUT_ANALYSIS}/`1'/tempdata"', replace;

		scalar beta0 = `X';

		g u = `depvar'r - beta0*`instd'r ;

	/* trick is to put controls here even though other variables are orthogonal */

		reg u `insts'r `controls'  , cluster(`insts'r) noc  ;
		test `insts' ;
		scalar f = r(F);

		drop _all;
		qui set obs 1;
		g fstat = f ;  
		g beta = beta0;
		g pval = Ftail(1,`j'-1 ,fstat);
		g inci = pval>=0.05;

		keep beta fstat pval inci;
		append using `"${PATH_OUT_ANALYSIS}/`1'/ci_`N'"', keep(beta fstat pval inci);
		qui save `"${PATH_OUT_ANALYSIS}/`1'/ci_`N'"', replace;
		};

	forvalues X = -10000(20000)10000 { ;
		use `"${PATH_OUT_ANALYSIS}/`1'/tempdata"', replace;

		scalar beta0 = `X';
		g u = `depvar'r - beta0*`instd'r ;

		reg u `insts'r `controls'  , cluster(`insts'r) noc  ;
		test `insts' ;
		scalar f = r(F);

		drop _all;
		qui set obs 1;
		g fstat = f ;  /* adjustment needed since controls taken out */
		g beta = beta0;
		g pval = Ftail(1,`j'-1 ,fstat);
		g inci = pval>=0.05;

		keep beta fstat pval inci;
		append using `"${PATH_OUT_ANALYSIS}/`1'/ci_`N'"', keep(beta fstat pval inci);
		qui save `"${PATH_OUT_ANALYSIS}/`1'/ci_`N'"', replace;
		};


	drop if beta==.;
	compress;
	*list;
	sort beta ;

	scalar crit`N' = invFtail(1,`j'-1,0.05) ;

	g crit`N' = invFtail(1,`j'-1,0.05) ;

	mat wlow`N' = point`N' - sqrt(crit`N')*se`N' ;
	mat whi`N' = point`N' + sqrt(crit`N')*se`N' ;


	*set output proc;

	noisily disp "`N'" ;

	scalar list firstt`N' firstf`N' firstfr`N' ;

	su fstat ;
	 scalar maxf`N' = r(max) ;

	list fstat if abs(beta)==10000;
	su fstat if abs(beta)==10000 ;
	  scalar asyf`N' = r(max) ;

	drop if abs(beta)>5000 ;

	mat stat`N' = ( crit`N' \ asyf`N' \ maxf`N' ) ;


	set output error;

	keep if  (inci[_n-1] == 0 & inci[_n]==1) |
			 (inci[_n-1] == 1 & inci[_n]==0) ;
	set obs 2 ;
	replace beta = 998 if beta==. ;
	replace beta = round(beta,.01) ;
	mkmat beta, mat(cilm`N') ;
	*set output proc;
	*mat list cilm`N', format(%5.2f);

	} ;



	mat point = point1, point2, point3, point4, point5, point6, point7 ;
	 mat coln point = 1 2 3 4 5 6 7 ;
	 mat pointT = point';
	 
	mat se = se1, se2, se3, se4, se5, se6, se7 ;
	 mat coln se = 1 2 3 4 5 6 7 ;

	mat wald = wlow1, wlow2, wlow3, wlow4, wlow5, wlow6, wlow7 \
	 whi1, whi2, whi3, whi4, whi5, whi6, whi7 ;
	 mat rown wald = low_wald high_wald ;
	 mat coln wald = 1 2 3 4 5 6 7 ;
	 mat waldT = wald';

	mat cilm = cilm1, cilm2, cilm3, cilm4, cilm5, cilm6, cilm7 ;
	 mat rown cilm = low_ar high_ar ;
	 mat coln cilm = 1 2 3 4 5 6 7 ;
	 mat cilmT = cilm';

	mat stat = stat1, stat2, stat3, stat4, stat5, stat6, stat7;
	 mat rown stat = crit asy_f max_f ;
	 mat coln stat = 1 2 3 4 5 6 7;
	 mat statT = stat';
	 
	 
	/*** Now construct strings for confidence intervals ***/

	svmat pointT,names(pointT_) ;
		format pointT_1 %4.2f ;

	svmat waldT,names(waldT_) ;
		format waldT_1 %4.2f ;
		format waldT_2 %4.2f ;
		tostring waldT_1,generate(waldT_1_str) force u ;
		tostring waldT_2,generate(waldT_2_str) force u ;
	g str waldT_ci = "[" + waldT_1_str + "," + waldT_2_str + "]" ;

	svmat cilmT,names(cilmT_) ;
		format cilmT_1 %4.2f ;
		format cilmT_2 %4.2f ;
		tostring cilmT_1,generate(cilmT_1_str) force u ;
		tostring cilmT_2,generate(cilmT_2_str) force u ;
	g str cilmT_ci = "" ;

	svmat statT,names(statT_);
	
	replace cilmT_ci = "[" + cilmT_1_str + "," + cilmT_2_str + "]" if statT_1 < statT_2 ;
	replace cilmT_ci = "(-$\infty$,+$\infty$)" if statT_1 > statT_3 & statT_1 > statT_2 ; 
	replace cilmT_ci = "\begin{tabular}[c]{@{}c@{}}(-$\infty$," + cilmT_1_str + "] U \\\ [" + cilmT_2_str + ",+$\infty$)\end{tabular}" if statT_1 > statT_2 & statT_1 > statT_2 & statT_1 < statT_3; 
			 
	keep pointT_1 waldT_ci cilmT_ci ;

	save `"${PATH_OUT_ANALYSIS}/iv_estimation_`T'"',replace;



