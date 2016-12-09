﻿
------------------------------
-- 2: Create risk-framework --
------------------------------

--Now calculated at municipality-level
--TO DO: build structure where each component is rated on its lowest level, and the aggregate score is built up dynamically

------------------------
-- 2.1: Vulnerability --
------------------------

--Maybe take LOG of GDP?
--NOTE: High score = high vulnerability


drop table if exists "MW_datamodel"."vulnerability_scores";

with 
--Poverty (Higher poverty = more vulnerable >> DO NOT switch scale around)
poverty as (
	select t0.pcode_level2
		,t1.poverty_incidence as poverty
	from "MW_datamodel"."Geo_level2" 	t0
	left join "MW_datamodel"."Indicators_2_TOTAL"	t1 on t0.pcode_level2 = t1.pcode
	), 
poverty_minmax as (
	select min(poverty) as min
		,max(poverty) as max
	from poverty
	),
poverty_score as (
	select t0.*
		,((poverty - min) / ( max - min)) * 10 as poverty_score
	from poverty t0
	left join poverty_minmax t1 on 1=1
	)

--Life expectancy (Higher = less vulnerable >> DO switch scale around)
,life_exp as (
	select t0.pcode_level2
		,t1.life_expectancy as life_exp
	from "MW_datamodel"."Geo_level2" 	t0
	left join "MW_datamodel"."Indicators_2_TOTAL"	t1 on t0.pcode_level2 = t1.pcode
	), 
life_exp_minmax as (
	select min(life_exp) as min
		,max(life_exp) as max
	from life_exp
	),
life_exp_score as (
	select t0.*
		,((max - life_exp) / ( max - min)) * 10 as life_exp_score
	from life_exp t0
	left join life_exp_minmax t1 on 1=1
	)

--Infant mortality (Higher = more vulnerable >> DO NOT switch scale around)
,infant_mort as (
	select t0.pcode_level2
		,t1.infant_mortality as infant_mort
	from "MW_datamodel"."Geo_level2" 	t0
	left join "MW_datamodel"."Indicators_2_TOTAL"	t1 on t0.pcode_level2 = t1.pcode
	), 
infant_mort_minmax as (
	select min(infant_mort) as min
		,max(infant_mort) as max
	from infant_mort
	),
infant_mort_score as (
	select t0.*
		,((infant_mort - min) / ( max - min)) * 10 as infant_mort_score
	from infant_mort t0
	left join infant_mort_minmax t1 on 1=1
	)

--(Semi)permanent construction materials (Higher = less vulnerable >> DO switch scale around)
,construction as (
	select t0.pcode_level2
		,t1.construction_semipermanent as construction
	from "MW_datamodel"."Geo_level2" 	t0
	left join "MW_datamodel"."Indicators_2_TOTAL"	t1 on t0.pcode_level2 = t1.pcode
	), 
construction_minmax as (
	select min(construction) as min
		,max(construction) as max
	from construction
	),
construction_score as (
	select t0.*
		,((max - construction) / ( max - min)) * 10 as construction_score
	from construction t0
	left join construction_minmax t1 on 1=1
	)

--Food consumption score (Higher = less vulnerable >> DO switch scale around)
,fcs as (
	select t0.pcode_level2
		,t1.fcs as fcs
	from "MW_datamodel"."Geo_level2" 	t0
	left join "MW_datamodel"."Indicators_2_TOTAL"	t1 on t0.pcode_level2 = t1.pcode
	), 
fcs_minmax as (
	select min(fcs) as min
		,max(fcs) as max
	from fcs
	),
fcs_score as (
	select t0.*
		,((max - fcs) / ( max - min)) * 10 as fcs_score
	from fcs t0
	left join fcs_minmax t1 on 1=1
	)

--JOINING ALL
select t0.pcode_level2
	,poverty_score,poverty
	,life_exp_score,life_exp
	,infant_mort_score,infant_mort
	,construction_score,construction
	,fcs_score,fcs
	,(10-power(coalesce((10-poverty_score)/10*9+1,1) 
			* coalesce((10-life_exp_score)/10*9+1,1) 
			* coalesce((10-infant_mort_score)/10*9+1,1)
			* coalesce((10-construction_score)/10*9+1,1)
			* coalesce((10-fcs_score)/10*9+1,1)
			,cast(1 as float)/cast((
				case when poverty_score is null then 0 else 1 end +
				case when life_exp_score is null then 0 else 1 end +
				case when infant_mort_score is null then 0 else 1 end +
				case when construction_score is null then 0 else 1 end +
				case when fcs_score is null then 0 else 1 end)
		as float)))/9*10 as vulnerability_score
into "MW_datamodel"."vulnerability_scores"
from "MW_datamodel"."Geo_level2" t0
left join poverty_score t2		on t0.pcode_level2 = t2.pcode_level2
left join life_exp_score t3		on t0.pcode_level2 = t3.pcode_level2
left join infant_mort_score t4		on t0.pcode_level2 = t4.pcode_level2
left join construction_score t5		on t0.pcode_level2 = t5.pcode_level2
left join fcs_score t6			on t0.pcode_level2 = t6.pcode_level2
;


------------------
-- 2.2: Hazards --
------------------

drop table if exists "MW_datamodel"."hazard_scores";

with 
haz_risk as (
	select t0.pcode_level2
		,log(case when flood_phys_exp = 0 then 0.00001 else flood_phys_exp end) as flood_phys_exp
--		,log(case when cyclone_phys_exp = 0 then 0.00001 else cyclone_phys_exp end) as cyclone_phys_exp
		,log(case when earthquake7_phys_exp = 0 then 0.00001 else earthquake7_phys_exp end) as earthquake7_phys_exp
--		,log(case when tsunami_phys_exp = 0 then 0.00001 else tsunami_phys_exp end) as tsunami_phys_exp
		,log(case when drought_phys_exp = 0 then 0.00001 else drought_phys_exp end) as drought_phys_exp
	from "MW_datamodel"."Geo_level2" 	t0
	left join "MW_datamodel"."Indicators_2_TOTAL"	t1 on t0.pcode_level2 = t1.pcode
	), 
haz_risk_minmax as (
	select min(flood_phys_exp) as min_flood
		,max(flood_phys_exp) as max_flood
--		,min(cyclone_phys_exp) as min_cyclone
--		,max(cyclone_phys_exp) as max_cyclone
		,min(earthquake7_phys_exp) as min_earthquake
		,max(earthquake7_phys_exp) as max_earthquake
--		,min(tsunami_phys_exp) as min_tsunami
--		,max(tsunami_phys_exp) as max_tsunami
		,min(drought_phys_exp) as min_drought
		,max(drought_phys_exp) as max_drought
	from haz_risk
	), 
haz_risk_score as (
	select t0.*
		,case when max_flood = min_flood then null else ((flood_phys_exp - min_flood) / (max_flood - min_flood)) * 10 end as flood_score
--		,case when max_cyclone = min_cyclone then null else ((cyclone_phys_exp - min_cyclone) / (max_cyclone - min_cyclone)) * 10 end as cyclone_score
		,case when max_earthquake = min_earthquake then null else ((earthquake7_phys_exp - min_earthquake) / (max_earthquake - min_earthquake)) * 10 end as earthquake_score
--		,case when max_tsunami = min_tsunami then null else ((tsunami_phys_exp - min_tsunami) / (max_tsunami - min_tsunami)) * 10 end as tsunami_score
		,case when max_drought = min_drought then null else ((drought_phys_exp - min_drought) / (max_drought - min_drought)) * 10 end as drought_score
	from haz_risk t0
	left join haz_risk_minmax t1 on 1=1
	)
--select * from haz_pe_score

--JOINING ALL
select t1.pcode_level2
	,flood_score,flood_phys_exp
--	,cyclone_score,cyclone_phys_exp
	,earthquake_score,earthquake7_phys_exp
--	,tsunami_score,tsunami_phys_exp
	,drought_score,drought_phys_exp
	,(10 - power(coalesce((10-flood_score)/10*9+1,1) 
--		* coalesce((10-cyclone_score)/10*9+1,1) 
		* coalesce((10-earthquake_score)/10*9+1,1)
--		* coalesce((10-tsunami_score)/10*9+1,1) 
		* coalesce((10-drought_score)/10*9+1,1)
		,cast(1 as float)/cast(3 as float))
		)/cast(9 as float)*cast(10 as float) as hazard_score
into "MW_datamodel"."hazard_scores"
from "MW_datamodel"."Geo_level2" t0
left join haz_risk_score t1	on t0.pcode_level2 = t1.pcode_level2
;




----------------------------------
-- 2.3: Lack of Coping capacity --
----------------------------------

drop table if exists "MW_datamodel"."coping_capacity_scores";

with
--travel time: higher travel time is lower coping capacity, so higher (Lack of Coping Capacity) score
travel as (
	select t0.pcode_level2
		,sum(log(case when t1.traveltime = 0 then 0.1 else t1.traveltime end) * t1.population) / sum(t1.population) as travel
	from "MW_datamodel"."Geo_level2" t0
	left join "MW_datamodel"."Indicators_3_TOTAL" t1 on t0.pcode_level2 = t1.pcode_parent
	group by 1
	),
travel_minmax as (
	select min(travel) as min
		,max(travel) as max
	from travel
	),
travel_score as (
	select t0.*
		,((travel - min) / (max - min)) * 10 as travel_score
	from travel t0
	join travel_minmax t1 on 1=1
	)

--health density (# of facilities per 10,000 people): more facilities means higher coping capacity, so lower score
,hospitals as (
	select t0.pcode_level2
		,sum(log(case when health_density = 0 then 0.1 else health_density end) * t1.population) / sum(t1.population) as hospitals
	from "MW_datamodel"."Geo_level2" t0
	left join "MW_datamodel"."Indicators_3_TOTAL" t1 on t0.pcode_level2 = t1.pcode_parent
	group by 1
	),
hospitals_minmax as (
	select min(hospitals) as min
		,max(hospitals) as max
	from hospitals
	),
hospitals_score as (
	select t0.*
		,(cast((max - hospitals) as numeric) / cast((max - min) as numeric)) * 10 as hospitals_score
	from hospitals t0
	join hospitals_minmax t1 on 1=1
	)

--Mobile access: higher access means higher coping capacity, so lower score
,mobile as (
	select t0.pcode_level2
		,mobile_access as mobile
	from "MW_datamodel"."Geo_level2" t0
	left join "MW_datamodel"."Indicators_2_TOTAL" t1 on t0.pcode_level2 = t1.pcode
	),
mobile_minmax as (
	select min(mobile) as min
		,max(mobile) as max
	from mobile
	),
mobile_score as (
	select t0.*
		,(cast((max - mobile) as numeric) / cast((max - min) as numeric)) * 10 as mobile_score
	from mobile t0
	join mobile_minmax t1 on 1=1
	)

--Improved sanitation: means higher coping capacity, so lower score
,sanitation as (
	select t0.pcode_level2
		,improved_sanitation as sanitation
	from "MW_datamodel"."Geo_level2" t0
	left join "MW_datamodel"."Indicators_2_TOTAL" t1 on t0.pcode_level2 = t1.pcode
	),
sanitation_minmax as (
	select min(sanitation) as min
		,max(sanitation) as max
	from sanitation
	),
sanitation_score as (
	select t0.*
		,(cast((max - sanitation) as numeric) / cast((max - min) as numeric)) * 10 as sanitation_score
	from sanitation t0
	join sanitation_minmax t1 on 1=1
	)

--Piped water: means higher coping capacity, so lower score
,pipewater as (
	select t0.pcode_level2
		,watersource_piped as pipewater
	from "MW_datamodel"."Geo_level2" t0
	left join "MW_datamodel"."Indicators_2_TOTAL" t1 on t0.pcode_level2 = t1.pcode
	),
pipewater_minmax as (
	select min(pipewater) as min
		,max(pipewater) as max
	from pipewater
	),
pipewater_score as (
	select t0.*
		,(cast((max - pipewater) as numeric) / cast((max - min) as numeric)) * 10 as pipewater_score
	from pipewater t0
	join pipewater_minmax t1 on 1=1
	)

--JOINING ALL
select t1.pcode_level2
	,travel_score,travel
	,hospitals_score,hospitals
	,mobile_score,mobile
	,sanitation_score,sanitation
	,pipewater_score,pipewater
	,(10-power(coalesce(
			(10-travel_score)/10*9+1,1)
			 * coalesce((10-hospitals_score)/10*9+1,1)
			 * coalesce((10-mobile_score)/10*9+1,1)
			 * coalesce((10-sanitation_score)/10*9+1,1)
			 * coalesce((10-pipewater_score)/10*9+1,1)
			,cast(1 as float)/cast(
		(case when travel_score is null then 0 else 1 end + 
		case when hospitals_score is null then 0 else 1 end + 
		case when mobile_score is null then 0 else 1 end + 
		case when sanitation_score is null then 0 else 1 end + 
		case when pipewater_score is null then 0 else 1 end)		
		as float)))/9*10 as coping_capacity_score
into "MW_datamodel"."coping_capacity_scores"
from "MW_datamodel"."Geo_level2" t0
left join travel_score t1	on t0.pcode_level2 = t1.pcode_level2
left join hospitals_score t2	on t0.pcode_level2 = t2.pcode_level2
left join mobile_score t3 	on t0.pcode_level2 = t3.pcode_level2
left join sanitation_score t4 	on t0.pcode_level2 = t4.pcode_level2
left join pipewater_score t5 	on t0.pcode_level2 = t5.pcode_level2
--order by 8
;


----------------
-- 2.4: Total --
----------------

drop table if exists "MW_datamodel"."total_scores_level2";
select t1.pcode_level2
	,vulnerability_score
	,hazard_score
	,coping_capacity_score
	,poverty_score,life_exp_score,infant_mort_score,construction_score,fcs_score
	,flood_score,earthquake_score,drought_score
	,travel_score,hospitals_score,mobile_score,sanitation_score,pipewater_score
	,(10 - power(coalesce((10-vulnerability_score)/10*9+1,1)
		* coalesce((10-hazard_score)/10*9+1,1)
		* coalesce((10-coping_capacity_score)/10*9+1,1)
		, cast(1 as float)/cast(3 as float)))/9*10 as risk_score
into "MW_datamodel"."total_scores_level2"
from "MW_datamodel"."Geo_level2" t0
left join "MW_datamodel"."vulnerability_scores" t1	on t0.pcode_level2 = t1.pcode_level2
left join "MW_datamodel"."hazard_scores" t2		on t0.pcode_level2 = t2.pcode_level2
left join "MW_datamodel"."coping_capacity_scores" t3	on t0.pcode_level2 = t3.pcode_level2
--order by 7
;

/*
drop table if exists "MW_datamodel"."total_scores_level2";
select t1.pcode_parent as pcode_level2
	,sum(risk_score * population) / sum(population) as risk_score
	,sum(hazard_score * population) / sum(population) as hazard_score
	,sum(vulnerability_score * population) / sum(population) as vulnerability_score
	,sum(coping_capacity_score * population) / sum(population) as coping_capacity_score
	,sum(pov_score * population) / sum(population) as pov_score,sum(inc_score * population) / sum(population) as inc_score,sum(hdi_score * population) / sum(population) as hdi_score
	,sum(wall_score * population) / sum(population) as wall_score,sum(roof_score * population) / sum(population) as roof_score,sum(pantawid_score * population) / sum(population) as pantawid_score
	,sum(flood_score * population) / sum(population) as flood_score,sum(cyclone_score * population) / sum(population) as cyclone_score,sum(earthquake_score * population) / sum(population) as earthquake_score
	,sum(tsunami_score * population) / sum(population) as tsunami_score,sum(drought_score * population) / sum(population) as drought_score
	,sum(travel_score * population) / sum(population) as travel_score,sum(hospitals_score * population) / sum(population) as hospitals_score,sum(governance_score * population) / sum(population) as governance_score
into "MW_datamodel"."total_scores_level2"
from "MW_datamodel"."total_scores_level3" t0
join "MW_datamodel"."Indicators_3_TOTAL" t1	on t0.pcode_level3 = t1.pcode
group by t1.pcode_parent
--order by 2 desc
;
*/

--------------------------------------
-- 2.5: Export ranges per indicator --
--------------------------------------
/*
select --min(health_density) as min_pov
	--,max(health_density) as max_pov
	t1.*,t2.*,t3.*
from "MW_datamodel"."Geo_level3" t0
left join "MW_datamodel"."vulnerability_scores" t1	on t0.pcode_level3 = t1.pcode_level3
left join "MW_datamodel"."hazard_scores" t2		on t0.pcode_level3 = t2.pcode_level3
left join "MW_datamodel"."coping_capacity_scores" t3	on t0.pcode_level3 = t3.pcode_level3
*/

