

									###############     Customers        ###############

							###########         Creating Customer base with created_date
	
	/* creating a base of valid customers in the system */
	
	create temporary table Customers_1 as
	select id as Customer_id,partner_id,network_id,client_code,client_code_id,Extract(Year from created_date) as created_year /* computing created_year for the valid users */
	from EOS_USER
	where client_type='individual' and type='live' 
	group by Customer_id,partner_id,network_id,client_code,client_code_id;

	alter table Customers_1
	add index(Customer_id),
	add index(partner_id);

	##########     Appropriate enquiry base    ###############	
	/* creating a base of valid enquiries for each valid customer in the system */
	
	alter table enquiry
	add index(eos_user_id),
	add index(partner_id);
	
	set sql_safe_updates=0;
	drop table if exists Metrics;
	create temporary table Metrics as 
	select B.eos_user_id,B.id
	from Customers_1 A,enquiry B
	where A.Customer_id=B.eos_user_id 
	group by B.eos_user_id,B.id;

	alter table Metrics
	add index(id);
	alter table Orders
	add index(enquiry_id);

	############   entire_Base_valid_transactions      ################
	/* We have computed Cust_txns as a base of valid transactions, we will constantly refer to this transaction base for computing the SVOC table  */
	
	set sql_safe_updates=0;
	drop table Cust_txns;
	create table Cust_txns as 
	select A.eos_user_id,B.enquiry_id,B.unit_count,B.id as component_id,B.discount,B.subject_area_id,B.price_after_tax,B.delivery_date,B.sent_to_client_date,B.type,B.component_type,B.offer_code,B.allocation_type,B.file_type,B.journal_name,B.delivery_special_instruction,B.specialized_subject_area,B.created_date,B.service_id from Metrics A,component B
	where A.id=B.enquiry_id and B.status='send-to-client' and B.type='normal' and B.component_type='job' and B.price_after_tax is not null and B.price_after_tax > 0 ;
	#price_after_tax>0

	###############    adding subject SA1,SA 1_5 AND SA 1_6    ###############################


	CREATE TEMPORARY TABLE MAPPING AS 
	SELECT * FROM CACTUS.subject_area;

	alter table MAPPING
	add column SA1 varchar(500),
	add column SA1_5 varchar(500),
	add column SA1_6 varchar(500),
	add column SA1_name varchar(500),
	add column SA1_5_name varchar(500),
	add column SA1_6_name varchar(500);
	alter table MAPPING add index(SA1,SA1_5,SA1_6);
	alter table subject_area_mapping add index(id);
    alter table MAPPING add index(SA1,SA1_5,SA1_6,id);
	alter table Cust_txns add index(subject_area_id);
	alter table Cust_txns
	add column SA1 varchar(500),
	add column SA1_5 varchar(500),
	add column SA1_6 varchar(500);
	
	
	alter table Cust_txns
	add column SA1_id varchar(500),
	add column SA1_5_id varchar(500),
	add column SA1_6_id varchar(500);
 
	
	/* 1.   SA1 */
	set sql_safe_updates=0;
	update MAPPING
	set SA1 = JSON_UNQUOTE(JSON_EXTRACT(data, '$.sa1'));
    
	/* 2. SA1_5 */
	set sql_safe_updates=0;
	update MAPPING
	set SA1_5 = JSON_UNQUOTE(JSON_EXTRACT(data, '$.sa1_5'));

	/* 3. SA1_6  */
	set sql_safe_updates=0;
	update MAPPING
	set SA1_6 = JSON_UNQUOTE(JSON_EXTRACT(data, '$.sa1_6'));

	/* SA1 name */
	update MAPPING A,subject_area_mapping B
	set A.SA1_name=B.title	
	where A.SA1=B.id;
    
	/* SA1_5 name */
	update MAPPING A,subject_area_mapping B
	set A.SA1_5_name=B.title	
	where A.SA1_5=B.id;
    
	/* SA1_6 name */
	update MAPPING A,subject_area_mapping B
	set A.SA1_6_name=B.title	
	where A.SA1_6=B.id;

	
	/* SA1 name */
	update Cust_txns A,MAPPING B
	set A.SA1_6_id=B.SA1_6
	where A.subject_area_id=B.id;

	/* SA1_5 name */
	update Cust_txns A,MAPPING B
	set A.SA1_5=SA1_5_name
	where A.subject_area_id=B.id;

	/* SA1_6 name */
	update Cust_txns A,MAPPING B
	set A.SA1_6=SA1_6_name
	where A.subject_area_id=B.id

	
	/* SA1 name */
	update Cust_txns A,MAPPING B
	set A.SA1=SA1_name
	where A.subject_area_id=B.id;

	/* SA1_5 name */
	update Cust_txns A,MAPPING B
	set A.SA1_5=SA1_5_name
	where A.subject_area_id=B.id;

	/* SA1_6 name */
	update Cust_txns A,MAPPING B
	set A.SA1_6=SA1_6_name
	where A.subject_area_id=B.id

	/* Actual time for job completion is the difference between send-to-client-date and confirmed_date which is computed for each order */
	
	ALTER TABLE Cust_txns
	ADD COLUMN Act_Time_for_job_Completion int;

	alter table Cust_txns
	add column confirmed_date varchar(10);

	update Cust_txns A,component B
	set A.confirmed_date=left(B.confirmed_date,10)
	where A.component_id=B.id ;

	UPDATE Cust_txns
	set Act_Time_for_job_Completion = datediff(sent_to_client_date, confirmed_date); 

	/* Indicator variable whether quotation was sought by the customer */

	 alter table Cust_txns add column Quotation_given varchar(2);
	 update Cust_txns A,
	 (
	 select * from enquiry where source_url like 'ecf.online.editage.%'
	 or source_url like 'php_form/newncf' or source_url like 'ecf.app.editage.%'
	 or source_url like	 'ncf.editage.%'
	 or source_url like 'api.editage.%/existing'
	 or source_url like 'api.editage.com/newecf-skipwc'
	 ) B
	 set A.Quotation_given='Y'
	 where A.enquiry_id=B.id;
	 
	##############################   Other Metrics added to the Cust_txns
	
	alter table Cust_txns
	add column currency_code varchar(10),
	add column rate varchar(15),
	add column wb_user_id varchar(10),
	add index(component_id),
	add index(enquiry_id);
	alter table Cust_txns
	add column Delay int(5);
	alter table component_auction
	add index(enquiry_id);
    
	
	/* wb_user_id */
	update Cust_txns A,component_auction B
	set A.wb_user_id=B.wb_user_allocated_id
	where A.enquiry_id=B.enquiry_id;
 
    /* feedback rating */
	update Cust_txns A,client_feedback B
	set A.rate=B.rating
	where A.component_id=B.component_id;
	
	/* recoding rating to integer values */

	alter table Cust_txns add column calculated_rating  int;
	update Cust_txns
	set calculated_rating=
	case when rate='outstanding' then 3 else 
	case when rate='acceptable' then 2 else
	case when rate='not-acceptable' then 1 else
	null
	end end end;

	/* currency */
	update Cust_txns A,Orders B
	set A.currency_code=B.currency_code
	where A.enquiry_id=B.enquiry_id;
	
	/* Delay */
	update Cust_txns
	set Delay=case when Left(sent_to_client_date,10)>Left(delivery_date,10) then datediff(Left(sent_to_client_date,10),Left(delivery_date,10)) else 0 end;

	#################    Payment mode mapping   ######################
	
	
	/* Adding payment_type for each transaction */
	
	alter table Cust_txns
	add column payment_mode_id varchar(6),
	add column payment_type varchar(30)
	;
	
	/* Adding payment_mode_id from payment table for each transaction */
	
	create temporary table as migration
	select * from master;
	
	alter table migration
	add column payment_mode varchar(30);
	
	set sql_safe_updates=0;
	update migration
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode')); /* Extracting Payment mode from migration type */

	update Cust_txns A,(select payment_mode_id,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_mode_id=B.payment_mode_id
	where A.invoice_id=B.invoice_debit_note_id;
	
	
	alter table Cust_txns add column invoice_id int(9);
	update Cust_txns A,Orders B
	set A.invoice_id=B.invoice_id
	where A.enquiry_id=B.enquiry_id and B.invoice_id is not null;
	
	alter table Cust_txns add index(payment_mode_id);
	alter table mig add index(id);

	update Cust_txns A, mig B
	set A.payment_type=B.payment_mode	
	where A.payment_mode_id=B.id and B.config_id=48; /* mapping payment_mode_id with id from migration and config_id =48 */
	
	/* adding additional instructions of each job */
	
	alter table Cust_txns 
	add column client_instruction varchar(200),
	add column delivery_instruction varchar(200),
	add column title varchar(200),
	add column use_ediatge_card varchar(15),add column editage_card_id int(15),
	add column author_name varchar(30);

	update Cust_txns A,component B
	set 
	A.client_instruction=B.client_instruction,A.delivery_instruction=B.delivery_instruction,A.title=B.title,A.journal_name=B.journal_name,A.use_ediatge_card=B.use_ediatge_card,A.editage_card_id=B.editage_card_id,A.author_name=B.author_name
	where A.enquiry_id=B.enquiry_id;
	
	
	/* Ranking the Transactions of the Customer by Transact date */

	ALTER TABLE Cust_txns ADD Column Txn_No int(10);

	UPDATE Cust_txns A, (select eos_user_id, created_date, transact_date, ROW_NUMBER() Over(PARTITION BY eos_user_id ORDER BY created_date) as TXn_No FROM Cust_txns) B
	SET A.Txn_No = B.Txn_No 
	where A.eos_user_id = B.eos_user_id AND A.created_date = B.created_date;
	
	/* No of Questions */
	
	ALTER TABLE Cust_txns Add COLUMN NoOfQuestions Int;
	update Cust_txns B,component A
	set B.NoOfQuestions = (select count(*) from component where component_type='question' and A.enquiry_id= B.enquiry_id)
	where A.enquiry_id=B.enquiry_id;
	
	
	/* Computing whether an order led to paid_mre,valid_mre and quality-re_edit, this is computed for each valid order in Cust_txns */
	
	alter table Cust_txns
	add column Txn_to_paid_mre varchar(2),
	add column Txn_to_valid_mre varchar(2),
	add column Txn_to_quality_re_edit varchar(2);

	update 
	Cust_txns A
	,(SELECT enquiry_id,parent_id FROM component WHERE type = 'paid-mre' and price_after_tax is not null and price_after_tax >0 and status='send-to-client' and component_type='job') B
	set A.Txn_to_paid_mre = 'Y'
	where A.component_id=B.parent_id ;

	update 
	Cust_txns A
	,(SELECT enquiry_id,parent_id FROM component WHERE type = 'valid-mre' and price_after_tax is not null and price_after_tax >0 and status='send-to-client' and component_type='job') B
	set A.Txn_to_valid_mre = 'Y'
	where A.component_id=B.parent_id ;

	update 
	Cust_txns A
	,(SELECT enquiry_id,parent_id FROM component WHERE type = 'quality-re_edit' and price_after_tax is not null and price_after_tax >0 and status='send-to-client' and component_type='job') B
	set A.Txn_to_quality_re_edit = 'Y'
	where A.component_id=B.parent_id ;

	
	######################## 	% discount      ###############
	
	/*  SVOC  */
	
	/* 
	FTD- First enquiry date
	LTD - last enquiry date
	*/
	drop table SVOC;
	create table SVOC as
	select eos_user_id,round(count( case when rate ='not-acceptable'then rate end)/count(*),2) as percent_not_acceptable_cases,round(count( case when rate ='acceptable'then rate end)/count(*),2) as percent_acceptable_cases,round(count( case when rate is null then rate end)/count(*),2) as percent_not_rated_cases,round(count( case when rate ='outstanding'then rate end)/count(*),2) as percent_outstanding_cases/*order's with outstanding rating to the total orders*/,round(count( case when discount>0 then discount end)/count(*),2) as percent_discount_cases/*order's with discount to the total orders*/,round(count( case when delay>0 then delay end)/count(*),2) as percent_delay_cases/*order's with delay to the total orders*/,count(distinct(service_id)) as Range_of_services/*distinct service_id's*/,count(distinct(subject_area_id)) as Range_of_subjects/*distinct subject_area_id's*/,distinct(currency_code) as Currency_code,ROUND(avg(delay)) as Average_Delay/*average delay in orders*/,Count(Distinct(enquiry_id)) as Frequency/*distinct bills*/,MIN(Left(created_date,10)) as FTD,MAX(Left(created_date,10))  as LTD
	from Cust_txns
	group by eos_user_id;
	
	/* Temporal variables */
	alter table Cust_txns 
	add column Favourite_Month int(3),
	add column Favourite_Time int(2),
	add column Favourite_Day_Week varchar(2);
	alter table SVOC 
	add column maximum_rating varchar(20),add column Favourite_subject int(11);
	alter table SVOC add column Favourite_SA1_name varchar(30),add column Favourite_SA1_5_name varchar(30),add column Favourite_SA1_6_name varchar(30),
	add column Favourite_service int(11);			
	
	alter table SVOC add column Favourite_subject_name varchar(50),
	add column Favourite_service_name varchar(50);
	alter table SVOC add index(Favourite_subject);
	alter table subject_area add index(id);
	
	/* Average word count */
	
	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Average_word_count_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	
	/* Favourite_Month */
	update Cust_txns 
	set Favourite_Month=Extract(MONTH FROM created_date);

	/* Favourite_Time */
	update Cust_txns 
	set Favourite_Time=Extract(HOUR FROM created_date);

	/* Favourite_Day_Week */
	update Cust_txns 
	set Favourite_Day_Week=DAYOFWEEK(created_date);

	/* Favourite_week_number */
	update Cust_txns 
	set Week_number=FLOOR((DAYOFMONTH(created_date) - 1) / 7) + 1;
	
	/* Calculating most frequent Week_number, in case of tie, value is taken to into consideration*/
	
    UPDATE IGNORE
			SVOC A
		SET Favourite_Week_number=(
               SELECT 
						Week_number
					FROM (select eos_user_id,Week_number,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Week_number order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id 
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
	UPDATE IGNORE
			SVOC A
		SET Favourite_Month=(
                    SELECT 
						Favourite_Month
					FROM (select eos_user_id,Favourite_Month,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Favourite_Month order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
	/* Calculating most frequent Day of the Week, in case of tie, value is taken to into consideration*/	
	
    UPDATE IGNORE
			SVOC A
		SET Favourite_Day_Week=(
			SELECT 
						Favourite_Day_Week
					FROM (select eos_user_id,Favourite_Day_Week,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Favourite_Day_Week order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
    /* Calculating most frequent Time, in case of tie, value is taken to into consideration*/  						
    
	UPDATE IGNORE
			SVOC A
		SET Favourite_Time=(
			SELECT 
						Favourite_Time
					FROM (select eos_user_id,Favourite_Time,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Favourite_Time order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);

	/* most_frequent rating given by the customer */				
					
	 UPDATE IGNORE
			SVOC A
		SET 
			maximum_rating = (
					SELECT 
						rate
					FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,rate order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);
				
				
	/* Calculating number of Number of MREs attached to a valid order in the Cust_txns */
	
	alter table Cust_txns
	add column No_OF_MRES int(4);

	update Cust_txns A,(select parent_id,count(*) as No_OF_MRES from component where component_type='job'  and type in ('quality-re_edit','paid-mre','valid-mre') group by parent_id) B
	set A.No_OF_MRES=B.No_OF_MRES
	where A.component_id=B.parent_id;

	###########       calculated_rating  ################# 	/*recoding ratings to numeric values */
	
	/* Computing average rating from the calculated  integer ratings */
	
	alter table SVOC add column average_calculated_rating double;

	update SVOC A,(select eos_user_id,avg(calculated_rating) as average_calculated_rating from Cust_txns where calculated_rating is not null group by eos_user_id) B
	set A.average_calculated_rating=B.average_calculated_rating
	where A.eos_user_id=B.eos_user_id;	
	
	/* Computing average rating from the calculated  integer ratings for time period 2017-2018 */
	
	alter table SVOC add column average_calculated_rating_2017_2018 double;

	update SVOC A,(select eos_user_id,avg(calculated_rating) as average_calculated_rating_2017_2018 from Cust_txns where calculated_rating is not null and transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.average_calculated_rating_2017_2018=B.average_calculated_rating_2017_2018
	where A.eos_user_id=B.eos_user_id;

	/* Computing average rating from the calculated  integer ratings for time period 2016-2017 */
	
	alter table SVOC add column average_calculated_rating_2016_2017 double;

	update SVOC A,(select eos_user_id,avg(calculated_rating) as average_calculated_rating_2016_2017 from Cust_txns where calculated_rating is not null and transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.average_calculated_rating_2016_2017=B.average_calculated_rating_2016_2017
	where A.eos_user_id=B.eos_user_id;
	
	/* most_frequent subject area denoted by the customer */
	
	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_subject= (
					SELECT 
						subject_area_id
					FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);
	
	/* most_frequent service_id allocated to the customer */	

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);			
	
	/* most_frequent SA1 allocated to the customer */	

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_SA1_name=(
					SELECT 
						SA1
					FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,SA1 order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		
				
	/* most_frequent SA1_5 allocated to the customer */

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_SA1_5_name=(
					SELECT 
						SA1_5
					FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

				/* most_frequent SA1_6 allocated to the customer */

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_SA1_6_name=(
					SELECT 
						SA1_6
					FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

	/* allocating name to the most_frequent_subject_area */
	set sql_safe_updates=0;
	update SVOC A,(select * from subject_area) B
	set A.Favourite_subject_name=B.title
	where A.Favourite_subject=B.id;
	
	/* allocating name to the most_frequent_service_id */
`	set sql_safe_updates=0;
	update SVOC A,(select * from service) B
	set A.Favourite_service_name=B.name
	where A.Favourite_service=B.id;
	
	/*  ###############################			Calculating RFM VARIABLES AND DEMOGRAPHIC VARIABLES  ######################################*/
	
	
	alter table SVOC
	add column Recency int(10),
	add column ADGBT int(10),
	add column Tenure int(10),
	add column Recent_translator varchar(10),
	add column First_translator varchar(10),
	add index(eos_user_id),
	add index(LTD),
	add column partner_id int(10),
	add column network_id int(10),
	add column client_code varchar(10),
	add column client_code_id int(10),
	add column created_year varchar(10),
	add column network_name varchar(20),
	add column partner_name varchar(20),
	add column organisation varchar(150),
	add column dob varchar(50),
	add column Job_title varchar(20),
	add column Country varchar(20),
	add column Language varchar(10),
	add column Number_of_times_rated int(5);

	alter table Cust_txns
	add index(eos_user_id),
	add index(created_date);
	alter table Cust_txns
	add column transact_date varchar(10),
	add column rate_to_USD double;

	/* Taking into account the date attributes only */
	
	set sql_safe_updates=0;
	update Cust_txns
	set transact_date=Left(created_date,10);

	###############################             Translator                 ####################
	
	
	alter table Cust_txns add index(component_id);
	alter table component_detail add index(component_id);

	/* mapping enquiry with the wb_user_id */
	
	update Cust_txns A,
	(select component_id,wb_user_id,min(actual_end_date) as date from component_detail where status='accepted' group by component_id,wb_user_id )B
	set A.wb_user_id=B.wb_user_id
	where A.component_id=B.component_id;
	
	/* Calculating most frequent Translator for each customer */
	
	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_Translator = (
						SELECT 
							wb_user_id
						FROM (select eos_user_id,wb_user_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,wb_user_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);


	
	/* Calculating wb_user on most recent date */
	update SVOC A,Cust_txns B
	set A.Recent_translator=B.wb_user_id
	where A.eos_user_id=B.eos_user_id and A.LTD=B.transact_date;

	/* Calculating First_translator from the First Transaction date */
	
	update SVOC A,Cust_txns B
	set A.First_translator=B.wb_user_id
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;

	/* Calculating FTD and LTD based on first transact date and last transact_date */
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD,max(transact_date) as LTD from Cust_txns   group by eos_user_id) B
	set A.FTD=B.FTD,A.LTD=B.LTD
	where A.eos_user_id=B.eos_user_id;
	
	/* Average Days Gap Between Transactions: ADGBT = (LTD - FTD ) / (Frequency -1 ) */
	
	update SVOC
	set ADGBT=datediff(LTD,FTD)/(Frequency-1);

	/* calculating Days since last transaction */	

	update SVOC
	set Recency=datediff('2018-08-28',LTD);

	/* calculating Tenure for each customer in the system */
	
	update SVOC
	set Tenure=datediff('2018-08-28',FTD);


	##############################################    partner_id,service_id mapping    #########################
	
	/* adding demographics and geographical variables to each customers */
	
	update SVOC A,Customers_1 B
	set A.partner_id=B.partner_id,A.network_id=B.network_id,A.client_code=B.client_code,A.client_code_id=B.client_code_id,A.created_year=B.created_year
	where A.eos_user_id=B.Customer_id;
	
	update SVOC A,network B
	set network_name=B.name where A.network_id=B.id;

	update SVOC A,partner B
	set partner_name=B.name where A.partner_id=B.id;

	###############################        USER_PROFILE            ####################

	
	#################    email id domain 

	/* We have email_id from a  EOS_USER table where email_id compulsorily should not be MASKED*/

	alter table SVOC add column email_id_domain varchar(200);

	update SVOC A,
	(SELECT id,SUBSTRING(email_id, LOCATE('@', email_id) + 1) AS domain FROM EOS_USER_NEW) B
	set A.email_id_domain=B.domain
	where A.eos_user_id=B.id;
	
	/* Adding salutation  for each customer */
	
	CREATE TEMPORARY TABLE eos_USER AS 
	SELECT * FROM CACTUS.EOS_USER;

	alter table eos_USER
	add column salutation_code varchar(5);
	
	set sql_safe_updates=0;
	update eos_USER
	set salutation_code = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_salutation'));
	
	
	CREATE TEMPORARY TABLE masters1 AS 
	SELECT * FROM CACTUS.masters;

	alter table masters1
	add column salutation varchar(5);
	
	set sql_safe_updates=0;
	update masters1
	set salutation = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_salutation_name'));
	
	alter table eos_USER
	add column salutation varchar(20);
	
	update eos_USER A,masters1 B
	set A.salutation=B.salutation
	where A.salutation_code=B.id;
	
	alter table SVOC
    add column salutation varchar(10);
    
	update SVOC A,eos_USER B
	set A.salutation=B.salutation
	where A.eos_user_id=B.id;
	
	
	/* #1 ORGANIZATION  */
	
	alter table eos_USER
	add column org1 varchar(500);

	set sql_safe_updates=0;
	update eos_USER
	set org1 = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_org'));

	/* #2 Date of Birth */
 	alter table eos_USER
	add column dob varchar(20);

	set sql_safe_updates=0;
	update eos_USER
	set dob = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_dob'));

	/* #3	Job_title */
	alter table eos_USER
	add column Job_title varchar(20);

	set sql_safe_updates=0;
	update eos_USER
	set Job_title = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_job_title'));


	/* #4  Country */

	alter table eos_USER
	add column Country varchar(20);

	set sql_safe_updates=0;
	update eos_USER
	set Country = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_address_country'));

	/* #5 Reference Source */

	alter table eos_USER
	add column Source int(10);

	set sql_safe_updates=0;
	update eos_USER
	set Source=JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_ref_source'));

	/* # 6 organization variables */

	alter table SVOC
	add index(eos_user_id);

	alter table eos_USER
	add index(id);

	update SVOC A, eos_USER B
	set A.organisation=B.org1,A.dob=B.dob,A.Job_title=B.Job_title,A.Country=B.Country,A.Language=B.Language
	where A.eos_user_id=B.id;

	/* Number of times Customer has rated */
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns group by eos_user_id) B
	set Number_of_times_rated=rate_count
	where A.eos_user_id=B.eos_user_id;

	/* Converting currency to USD*/

	alter table Cust_txns
	add column transact_date varchar(10),
	add column rate_to_USD double;

	/* we need to remove cases where payment master had improper currency currency values */
	
	alter table Cust_txns
	add column transact_date_1 date;

	alter table Cust_txns
	add index(transact_date_1,currency_code);
	
	/* Exchange_rate table is referred for standardizing prices to USD */
	
	alter table exchange_rate
	add column currency_date_val varchar(10);
	
	alter table exchange_rate 
	add index(currency_date_val,currency_from);

	
	update Cust_txns /* We have created transact_date_1 because transact_date in the given days need to have previous day's rate to dollar  */
	set transact_date_1=case when transact_date ='2017-12-22' then '2017-12-21' else 
	case when transact_date in ('2018-01-26','2018-01-27','2018-01-28','2018-01-29') then '2018-01-25' else
	case when transact_date ='2018-02-02' then '2018-02-01' else transact_date end end end;
	
	/* rate to USD  */
	
	update Cust_txns A,exchange_rate B
	set rate_to_USD=B.exchange_rate 
	where
	A.transact_date_1=B.currency_date_val and B.currency_to='USD' and A.currency_code=B.currency_from;
	select transact_date,created_date from Cust_txns;

	set sql_safe_updates=0;
	update exchange_rate
	set currency_date_val=Left(currency_date,10);

	alter table Cust_txns
	add column rate_to_USD double;

	###############################             currency_conversion                 ####################
	
	/* We are creating Standardised_Price variables which is contains conversion rate to USD for all the currencies */
	
	alter table Cust_txns
	add column Standardised_Price double;

	alter table Cust_txns
	add index(transact_date_1);

	update Cust_txns
	set rate_to_USD=1
	where currency_code='USD';

	/*We have taken all non negative and non-null currency rates to USD , we will average it out across all the time periods */
	
	update Cust_txns A,(select currency_from,currency_to,avg(exchange_rate) as forex
	from exchange_rate
	where currency_to='USD' 
	and exchange_rate>0 and exchange_rate is not null
	group by currency_from,currency_to) B
	set rate_to_USD= forex
	where A.currency_code=B.currency_from and currency_code is not null;

	/* Multiplying all price_after_tax with USD */
	
	update Cust_txns
	set Standardised_Price=rate_to_USD*price_after_tax;
	
	/* adding coupon code to each transaction */
	
	alter table Cust_txns 
	add column offer_code varchar(25);

	update Cust_txns A,coupon_tracker B
	set A.offer_code=B.coupon_code where A.enquiry_id=B.enquiry_id;


	#############################        Year Tags

	/* In our model building base, we have taken base from 
	in Aug to Aug cycle */
	
	/* Therefore we have created tags for customer for each year */
	
	alter table SVOC
	add column Sept_2018 varchar(5),
	add column Sept_2017 varchar(5),
	add column Sept_2016 varchar(5),
	add column Sept_2015 varchar(5),
	add column Sept_2014 varchar(5),
	add column Sept_2013 varchar(5),
	add column Sept_2012 varchar(5),
	add column Sept_2011 varchar(5),
	add column Sept_2010 varchar(5),
	add column Sept_2009 varchar(5),
	add column Sept_2008 varchar(5),
	add column Sept_2007 varchar(5),
	add column Sept_2006 varchar(5),
	add column Sept_2005 varchar(5);

	
	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') B
	set Sept_2018='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set Sept_2017='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') B
	set Sept_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2014-08-29' and '2015-08-28') B
	set Sept_2015='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2013-08-29' and '2014-08-28') B
	set Sept_2014='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2012-08-29' and '2013-08-28') B
	set Sept_2013='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2011-08-29' and '2012-08-28') B
	set Sept_2012='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2010-08-29' and '2011-08-28') B
	set Sept_2011='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2009-08-29' and '2010-08-28') B
	set Sept_2010='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2008-08-29' and '2009-08-28') B
	set Sept_2009='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2007-08-29' and '2008-08-28') B
	set Sept_2008='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2006-08-29' and '2007-08-28') B
	set Sept_2007='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2005-08-29' and '2006-08-28') B
	set Sept_2006='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2004-08-29' and '2005-08-28') B
	set Sept_2005='Y'
	where A.eos_user_id=B.eos_user_id;


	###############################              Recency - Frequency - Monetary Value Parameters                        ####################
	
	/* Creating key metrics for two different time periods 
		1)  1_years :- 29-Aug-2017 to 28-Aug-2018 indicated by _1_year
		2)	2_years :- 29-Aug-2016 to 28-Aug-2018 indicated by 2016_2017  _2_year
	
	*/ 
	
	/* FTD - first transaction date
	   LTD - last transaction date
	   frequency - number of transactions 
	   
	   
	/* RFM variables */
	
	alter table SVOC 
	add column ATV_entire int(20),
	add column ATV_1_year int(10),/* for time period 29-Aug-2017 to 28-Aug-2018  */
	add column ATV_2_year int(10), /* for time period 29-Aug-2016 to 28-Aug-2018 */
	add column Total_Standard_price int(15),
	add column Total_Standard_price_1_year int(15),/* for time period 29-Aug-2017 to 28-Aug-2018  */
	add column Total_Standard_price_2_year int(15), /* for time period 29-Aug-2016 to 28-Aug-2018 */
	add column FTD_1_years date, 
	add column LTD_1_years date,
	add column frequency_1_year int(4),
	add column ATV_1_year int(10),add column Recency_1_year int(5),add column ADGBT_1_Year int(5),add column Inactivity_ratio_1_year double,
	add column FTD_2_years date,
	add column LTD_2_years date,
	add column frequency_2_year int(4),
	add column ATV_2_year int(10),add column Recency_2_year int(5),add column ADGBT_2_Year int(5),
	add column ATV_entire int(10),
	add column  ATV_1_year int(10),
	add column ATV_2_year int(10);
	
    update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') B group by eos_user_id) B
	set A.FTD_1_years=B.FTD_1_years,A.LTD_1_years=B.LTD_1_years,A.frequency_1_year=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' );

	update SVOC
	set Recency_1_year=datediff('2018-08-28',LTD_1_years)
	where (Sept_2018='Y' ) and frequency_1_year is not null;

	update SVOC
	set ADGBT_1_Year=datediff(LTD_1_years,FTD_1_years)/(frequency_1_year-1)
	 where (Sept_2018='Y' ) and frequency_1_year is not null;
	
	/* ATV is average transaction value = Avg(total_sales_orders) 
	   Total_Standard_price is the sum of all Standardized Price After Tax 
	   ADGBT is the average days gap between transactions */
	 
	update SVOC A,(select eos_user_id,avg(Standardised_Price) as ATV_entire from Cust_txns group by eos_user_id) B
	set A.ATV_entire=B.ATV_entire
	where A.eos_user_id=B.eos_user_id;
	
	update SVOC A,(select eos_user_id,avg(case when transact_date between '2017-08-29' and '2018-08-28' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_1_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' );
	
	update SVOC A,(select eos_user_id,sum(case when transact_date between '2017-08-29' and '2018-08-28' then Standardised_Price end) as Total_Standard_price_1_year from Cust_txns  group by eos_user_id) B
	set A.Total_Standard_price_1_year=B.Total_Standard_price_1_year
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(case when transact_date between '2016-08-29' and '2018-08-28' then Standardised_Price end) as Total_Standard_price_2_year from Cust_txns  group by eos_user_id) B
	set A.Total_Standard_price_2_year=B.Total_Standard_price_2_year
	where A.eos_user_id=B.eos_user_id;
	
	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Total_Standard_price from Cust_txns  group by eos_user_id) B
	set A.Total_Standard_price=B.Total_Standard_price
	where A.eos_user_id=B.eos_user_id;
	
	/* */
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_2_years,max(transact_date) as LTD_2_years, count(distinct(enquiry_id)) as frequency_2_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2016-08-29' and '2018-08-28') B group by eos_user_id) B
	set A.FTD_2_years=B.FTD_2_years,A.LTD_2_years=B.LTD_2_years,A.frequency_2_year=B.frequency_2_year
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' or Sept_2017='Y');

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2016-08-29' and '2018-08-28' then Standardised_Price end) as ATV_2_year from Cust_txns group by eos_user_id) B
	set A.ATV_2_year=
	case when 
	B.ATV_2_year is null then 0 else B.ATV_2_year end
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' or Sept_2017='Y');

	update SVOC
	set Recency_2_year=datediff('2018-08-28',LTD_2_years)
	where (Sept_2018='Y' or Sept_2017='Y') and frequency_2_year is not null;

	update SVOC
	set ADGBT_2_Year=datediff(LTD_2_years,FTD_2_years)/(frequency_2_year-1)
	 where (Sept_2018='Y' or Sept_2017='Y') and frequency_2_year is not null;
	
	########################     L2_segment for 2016_2017 #################
	
	alter table SVOC
	add column  ATV_2016_2017_year int(10),
	add column frequency_2016_2017_year int(4),
	add column Recency_2016_2017_year int(5),
	add column FTD_2016_2017_years date,
	add column LTD_2016_2017_years date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B group by eos_user_id) B
	set A.FTD_2016_2017_years=B.FTD_1_years,A.LTD_2016_2017_years=B.LTD_1_years,A.frequency_2016_2017_year=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id ;

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2016-08-29' and '2017-08-28' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_2016_2017_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_2016_2017_year=datediff('2017-08-28',LTD_2016_2017_years)
	where frequency_2016_2017_year is not null;
	
	
	##################################          Second Transaction Date                 ###############################################
	
	
	
	/* 
	   STD indicates second transaction date
	   STD_1_Year indicates second transaction date in the time period - 29-Aug-2017 to 28-Aug-2018 
	   STD_2_Year indicates second transaction date in the time period - 29-Aug-2016 to 28-Aug-2018
	*/
	
	alter table SVOC 
	add column Bounce_Curve int,
	add column STD date,
	add column STD_2_Year date,
	add column STD_1_Year date,
	add column Bounce_2_year int,
	add column Bounce_Curve int,
	add column Bounce_1_year int;
	
	
	set sql_safe_updates=0;
	UPDATE IGNORE
			SVOC A
	SET 
		STD = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
	WHERE 
			Frequency > 1 ;

	
		set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_1_Year = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2017-08-29' and '2018-08-28'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_1_year > 1 ;
			
			
		set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_2_Year = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2016-08-29' and '2018-08-28'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_2_year > 1 ;
	

	/* Bounce Curve is the difference between the STD and FTD, where eos_user has more than one transactions */
	
	update SVOC
	set Bounce_2_year = datediff(STD_2_Year,FTD_2_years)
	where frequency_2_year>1 and STD_2_Year is not null;/* for the time period - 29-Aug-2016 to 28-Aug-2018 */

	update SVOC
	set Bounce_Curve = datediff(STD,FTD)
	where Frequency>1 and STD is not null;

	update SVOC
	set Bounce_1_year = datediff(STD_1_Year,FTD_1_years)
	where frequency_1_year>1 and STD_1_Year is not null;/* for the time period - 29-Aug-2017 to 28-Aug-2018 */
	
	
	
	
	/*      Inactivity ratio is the indicator variable for a customer to showcase if a customer is currently transacting below,*/
			
	update SVOC
	set Inactivity_ratio_1_year=recency_1_year/ADGBT_1_year;

	
	#############################      Referral       #########################
	
	/* Source name extraction */
	
	drop table if exists eos_USER;
	create temporary table eos_USER as
	select * from EOS_USER;
	alter table eos_USER
	add column Source int(10);


	set sql_safe_updates=0;
	update eos_USER
	set Source=JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_ref_source'));

	alter table SVOC
	add column is_referred varchar(3);
	
	/* is_referred for customer referred customers */
	
	update SVOC A,eos_USER B
	set is_referred=
	case when Source is not null then 'Y' else 'N' end
	where A.eos_user_id=B.id and Source in ('77030','77016','13300',			
	'13303',
	'13304',
	'28563',
	'13297',
	'13309',
	'13310',
	'13311',
	'13312',
	'13307',
	'13305',
	'13298',
	'13424',
	'13421',
	'13422',
	'13431',
	'13425',
	'13426',
	'28572',
	'13419',
	'13423',
	'13420',
	'13432',
	'13416',
	'13417',
	'13418',
	'13427',
	'13429',
	'52518',
	'52519');

	alter table SVOC
	add column Referrer int(10);

	update SVOC A,eos_USER B
	set Referrer=B.Source
	where A.eos_user_id=B.id;
	
    /* adding Source_name to SVOC */
	
    alter table SVOC 
    add column Source int,
    add column Source_name varchar(100);
    
    update SVOC A,eos_USER B
    set A.Source =B.Source
    where A.eos_user_id=B.id;
    
	alter table SVOC
	add column Favourite_payment_type varchar(20);

	UPDATE IGNORE
			SVOC A
	SET Favourite_payment_type=(
	SELECT 
		payment_type 
					FROM (select eos_user_id,payment_type ,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,payment_type  order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
    alter table SVOC add index(Source);
    alter table masters add index(id);
    
    update SVOC A,masters B
    set A.Source_name =B.name
    where A.Source=B.id;
    
	#############################  country
	
	/* Country of the user */
	
	alter table SVOC
	add index(Country);

	alter table country
	add index(iso_alpha2 );

	update SVOC A,(select name,iso_alpha2 from country) B
	set A.Country=
	name
	where A.Country=B.iso_alpha2;


/*
	##############################                  Number of reedits     ###########################
	
	
	
	alter table Cust_txns
	add column nummber_of_re_edits int(4);

	update Cust_txns A,
	(select enquiry_id,count(distinct(B.parent_id)) as nummber_of_re_edits
	from component A,
	(SELECT parent_id FROM component where parent_id is not null) B
	where A.enquiry_id=B.parent_id
	group by enquiry_id) B
	set A.nummber_of_re_edits=B.nummber_of_re_edits
	where A.enquiry_id=B.enquiry_id;

	/*
	alter table SVOC
	add column Number_of_reedits int(5);

	update SVOC A,(select eos_user_id,sum(case when nummber_of_re_edits is not null then nummber_of_re_edits end) as Number_of_reedits from Cust_txns group by eos_user_id) B
	set A.Number_of_reedits=B.Number_of_reedits
	where A.eos_user_id=B.eos_user_id;
	*/
	
	######################################### editage card #############################################
	
	/* mapping editage_card user */
	
	alter table SVOC
	add column editage_card_user varchar(2),
	add column editage_card_id int(5);


	update SVOC A,
	(select eos_user_id,B.editage_card_id from Cust_txns A,component B where A.enquiry_id=B.enquiry_id and B.editage_card_id is not null and use_ediatge_card='Yes') B
	set editage_card_user='Y',A.editage_card_id=B.editage_card_id
	where A.eos_user_id=B.eos_user_id;


	##########################priority ########################
	
	/* preferred_translator for each user */
	
	alter table SVOC
	add column preferred_translator int(10);

	update SVOC A,
	(select eos_user_id,wb_user_id from favourite_editor where status='favourite') B
	set preferred_translator=B.wb_user_id 
	where A.eos_user_id=B.eos_user_id;
	/* is_preferred_transalator */
	
	alter table SVOC 
	add column is_preferred_transalator varchar(2);/* indicator variable whether the customer has preferred translator or not in the entire_lifetime Aug-Aug cycle */

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2015-08-29' and '2016-08-28') B
	set A.is_preferred_transalator_2015_2016='Y'
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC 
	add column is_preferred_transalator_2015_2016 varchar(2);/* indicator variable whether the customer has preferred translator or not in the entire_lifetime Aug-Aug cycle 2015-2016 */

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2015-08-29' and '2016-08-28') B
	set A.is_preferred_transalator_2015_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	####################  promo_code
	
	/* cases offer_code for each customer */

	alter table SVOC
	add column percent_offer_cases int(8);

	update SVOC A,(select eos_user_id,round(count( case when offer_code is not null then offer_code end) *100/count(*),2) as percent_offer_cases from Cust_txns group by eos_user_id) B
	set A.percent_offer_cases=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;


	####################   Group 

	/* mapping group for each customer */
	
	alter table SVOC
	add column is_part_of_group varchar(3),/* indicator variable for mapping grouped customer */
	add column Number_of_group int(8);/* count of number of groups each user is part of */

	update SVOC A,(select distinct(eos_user_id) from group_author_association where eos_user_id is not null and group_id is not null) B
	set is_part_of_group ='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(distinct(group_id)) as Number_of_group from group_author_association where eos_user_id is not null or group_id is not null group by eos_user_id) B
	set A.Number_of_group =B.Number_of_group 
	where A.eos_user_id=B.eos_user_id;


	############# annualized_returns
	########### 

	/* indicator flags for transact period from Aug-to-Aug cycle */
	
	alter table Cust_txns
	add column update_transact_year int(5);

	update Cust_txns
	set update_transact_year=
	case when transact_date between '2004-08-29' and '2005-08-28' then 2005 else
	case when transact_date between '2005-08-29' and '2006-08-28' then 2006 else
	case when transact_date between '2006-08-29' and '2007-08-28' then 2007 else
	case when transact_date between '2007-08-29' and '2008-08-28' then 2008 else
	case when transact_date between '2008-08-29' and '2009-08-28' then 2009 else
	case when transact_date between '2009-08-29' and '2010-08-28' then 2010 else
	case when transact_date between '2010-08-29' and '2011-08-28' then 2011 else
	case when transact_date between '2011-08-29' and '2012-08-28' then 2012 else
	case when transact_date between '2012-08-29' and '2013-08-28' then 2013 else
	case when transact_date between '2013-08-29' and '2014-08-28' then 2014 else
	case when transact_date between '2014-08-29' and '2015-08-28' then 2015 else
	case when transact_date between '2015-08-29' and '2016-08-28' then 2016 else
	case when transact_date between '2016-08-29' and '2017-08-28' then 2017 else
	-- case when transact_date between '2017-08-29' and '2018-08-28' then 2018 else 'NA'
	end end end end end end end end end end end  end end  end ;

	/* indicator flags for transact period from April-to-March cycle */
	
	alter table Cust_txns
	add column fiscal_transact_year int(5);

	update Cust_txns
	set fiscal_transact_year=
	case when transact_date between '2004-04-01' and '2005-03-31' then 2004 else
	case when transact_date between '2005-04-01' and '2006-03-31' then 2005 else
	case when transact_date between '2006-04-01' and '2007-03-31' then 2006 else
	case when transact_date between '2007-04-01' and '2008-03-31' then 2007 else
	case when transact_date between '2008-04-01' and '2009-03-31' then 2008 else
	case when transact_date between '2009-04-01' and '2010-03-31' then 2009 else
	case when transact_date between '2010-04-01' and '2011-03-31' then 2010 else
	case when transact_date between '2011-04-01' and '2012-03-31' then 2011 else
	case when transact_date between '2012-04-01' and '2013-03-31' then 2012 else
	case when transact_date between '2013-04-01' and '2014-03-31' then 2013 else
	case when transact_date between '2014-04-01' and '2015-03-31' then 2014 else
	case when transact_date between '2015-04-01' and '2016-03-31' then 2015 else
	case when transact_date between '2016-04-01' and '2017-03-31' then 2016 else
	case when transact_date between '2017-04-01' and '2018-03-31' then 2017 else 
	case when transact_date between '2018-04-01' and '2019-03-31' then 2018 else 'NA'
	end end end end end end end end end end end  end end  end end;

	/* 1 Year fiscal frequency - april 17 to Mar 18 */
	
	alter table SVOC
	add column Frequency_fy_17_18 int(5);
	
	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as Frequency_fy_17_18 from Cust_txns where fiscal_transact_year=2017 group by eos_user_id) B
	set A.Frequency_fy_17_18=B.Frequency_fy_17_18
	where A.eos_user_id=B.eos_user_id and fiscal_2017='Y';
	
	alter table SVOC
	add column  ATV_fy_17_18_year int(10),
	add column Recency_fy_17_18_year int(5),
	add column FTD_fy_17_18_years date,
	add column LTD_fy_17_18_years date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2017-04-01' and '2018-03-31') B group by eos_user_id) B
	set A.FTD_fy_17_18_years=B.FTD_1_years,A.LTD_fy_17_18_years=B.LTD_1_years
	where A.eos_user_id=B.eos_user_id ;

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2017-04-01' and '2018-03-31' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_fy_17_18_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_fy_17_18_year=datediff('2018-03-31',LTD_fy_17_18_years)
	where Frequency_fy_17_18 is not null;
	
	/* distinct active year (fiscal-wise) */
	
	alter table SVOC
	add column Active_fiscal_years int(5);
	
	update SVOC A,
	(select eos_user_id,count(distinct(fiscal_transact_year)) as Distinct_years from Cust_txns where transact_date between '2004-04-01' and '2018-03-31' group by eos_user_id) B
	set A.Active_fiscal_years=B.Distinct_years
	where A.eos_user_id=B.eos_user_id;
	
	/* Total spend fiscal wise */
	
	alter table SVOC add column fiscal_Standardised_Value double;
	
	update SVOC A,
	(select eos_user_id,sum(Standardised_Price) as fiscal_Standardised_Value from Cust_txns where transact_date between '2004-04-01' and '2018-03-31' group by eos_user_id) B
	set A.fiscal_Standardised_Value=B.fiscal_Standardised_Value
	where A.eos_user_id=B.eos_user_id;
	
	/* Calculating annualized value for fiscal years between 01 April 2004 and  31st March 2018*/
	
	alter table SVOC
	add column Annualized_fiscal_value double;
	
	update SVOC
	set Annualized_fiscal_value=(fiscal_Standardised_Value/Active_fiscal_years);

	/*select eos_user_id,Frequency_fy_17_18,Active_fiscal_years,fiscal_Standardised_Value,Annualized_fiscal_value
	from SVOC;*/
	##################   fiscal
	
	/* fiscal indicator for each year */

	alter table SVOC
	add column fiscal_2018 varchar(5),
	add column fiscal_2017 varchar(5),
	add column fiscal_2016 varchar(5),
	add column fiscal_2015 varchar(5),
	add column fiscal_2014 varchar(5),
	add column fiscal_2013 varchar(5),
	add column fiscal_2012 varchar(5),
	add column fiscal_2011 varchar(5),
	add column fiscal_2010 varchar(5),
	add column fiscal_2009 varchar(5),
	add column fiscal_2008 varchar(5),
	add column fiscal_2007 varchar(5),
	add column fiscal_2006 varchar(5),
	add column fiscal_2005 varchar(5),
	add column fiscal_2004 varchar(5);


	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2018-04-01' and '2019-03-31') B
	set fiscal_2018='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2017-04-01' and '2018-03-31') B
	set fiscal_2017='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2016-04-01' and '2017-03-31') B
	set fiscal_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2015-04-01' and '2016-03-31') B
	set fiscal_2015='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2014-04-01' and '2015-03-31') B
	set fiscal_2014='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2013-04-01' and '2014-03-31') B
	set fiscal_2013='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2012-04-01' and '2013-03-31') B
	set fiscal_2012='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2011-04-01' and '2012-03-31') B
	set fiscal_2011='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2010-04-01' and '2011-03-31') B
	set fiscal_2010='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2009-04-01' and '2010-03-31') B
	set fiscal_2009='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2008-04-01' and '2009-03-31') B
	set fiscal_2008='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2007-04-01' and '2008-03-31') B
	set fiscal_2007='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2006-04-01' and '2007-03-31') B
	set fiscal_2006='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2005-04-01' and '2006-03-31') B
	set fiscal_2005='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2004-04-01' and '2005-03-31') B
	set fiscal_2004='Y'
	where A.eos_user_id=B.eos_user_id;


	##############################################         fiscal created Year
	
	/* indicator variable as per fiscal for eos_user created date */

	alter table SVOC
	add column fiscal_created_year varchar(5),

	update SVOC A,
	(select created_date,id from  EOS_USER where type='live' and client_type='individual' ) B
	set fiscal_created_year=
	case when left(created_date,10) between '2002-04-01' and '2003-03-31' then 2002
	when left(created_date,10) between '2003-04-01' and '2004-03-31' then 2003
	when left(created_date,10) between '2004-04-01' and '2005-03-31' then 2004 
	when left(created_date,10) between '2005-04-01' and '2006-03-31' then 2005 
	when left(created_date,10) between '2006-04-01' and '2007-03-31' then 2006 
	when left(created_date,10) between '2007-04-01' and '2008-03-31' then 2007 
	when left(created_date,10) between '2008-04-01' and '2009-03-31' then 2008 
	when left(created_date,10) between '2009-04-01' and '2010-03-31' then 2009 
	when left(created_date,10) between '2010-04-01' and '2011-03-31' then 2010 
	when left(created_date,10) between '2011-04-01' and '2012-03-31' then 2011 
	when left(created_date,10) between '2012-04-01' and '2013-03-31' then 2012 
	when left(created_date,10) between '2013-04-01' and '2014-03-31' then 2013 
	when left(created_date,10) between '2014-04-01' and '2015-03-31' then 2014 
	when left(created_date,10) between '2015-04-01' and '2016-03-31' then 2015 
	when left(created_date,10) between '2016-04-01' and '2017-03-31' then 2016 
	when left(created_date,10) between '2017-04-01' and '2018-03-31' then 2017 
	when left(created_date,10) between '2018-04-01' and '2019-03-31' then 2018 else 'NA' end
	where A.eos_user_id=B.id;

	###########################3

	/* indicator variable as per calendar year for eos_user created date */
	
	alter table SVOC
	add column calendar_2018 varchar(5),
	add column calendar_2017 varchar(5),
	add column calendar_2016 varchar(5),
	add column calendar_2015 varchar(5),
	add column calendar_2014 varchar(5),
	add column calendar_2013 varchar(5),
	add column calendar_2012 varchar(5),
	add column calendar_2011 varchar(5),
	add column calendar_2010 varchar(5),
	add column calendar_2009 varchar(5),
	add column calendar_2008 varchar(5),
	add column calendar_2007 varchar(5),
	add column calendar_2006 varchar(5),
	add column calendar_2005 varchar(5),
	add column calendar_2004 varchar(5);


	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2018) B
	set calendar_2018='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2017) B
	set calendar_2017='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2016) B
	set calendar_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2015) B
	set calendar_2015='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2014) B
	set calendar_2014='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2013) B
	set calendar_2013='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2012) B
	set calendar_2012='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2011) B
	set calendar_2011='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2010) B
	set calendar_2010='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2009) B
	set calendar_2009='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2008) B
	set calendar_2008='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2007) B
	set calendar_2007='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2006) B
	set calendar_2006='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2005) B
	set calendar_2005='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2004) B
	set calendar_2004='Y'
	where A.eos_user_id=B.eos_user_id;


	##################   total value

	/* Obtaining Annualized sum for each customer where  Annualized sum = sum of Lifetime sales/Number of active years  */
	/* we have taken update_transact_year tag for calculating active years for each customer, as we took into consideration Aug-Aug cycle for active years */
	
	##################  Annualized Entire lifetime ############################
	
	alter table SVOC
	add column sum_entire int(10);
	
	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_entire from Cust_txns where transact_date between '2004-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_entire=B.sum_entire
	where A.eos_user_id=B.eos_user_id; /* we are calculating total sales for entire lifetime*/
	
	
	######  Annualized_sum_entire  ###
	
	alter table SVOC
	add column Annualized_sum_entire_F int(10); /* F indicates the variable of Annualized sum*/

	update SVOC A, (select eos_user_id,count(distinct(update_transact_year)) as Distinct_years from Cust_txns where transact_date between '2004-08-29' and '2018-08-28' group by eos_user_id) B
	set Annualized_sum_entire_F=(A.sum_entire)/Distinct_years
	where A.eos_user_id=B.eos_user_id; /* we are calculating Annualized_sum by dividing total sales by active years for entire lifetime*/
	
	##################  one year

	#Annualized_sum_2018

	alter table SVOC 
	add column sum_2018 int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_2018 from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_2018=B.sum_2018
	where A.eos_user_id=B.eos_user_id;/* we are calculating annualized sum for 2018, hence in this case the denominator will be 1 */
  
	alter table SVOC
	add column Annualized_sum_2018_F int(10);

	update SVOC
	set Annualized_sum_2018_F=sum_2018;/* we are calculating annualized sums for 2018,we are calculating annualized sum for 2018, hence in this case the denominator will be 1*/


	################# Annualized_2017_2018

	alter table SVOC
	add column sum_2017_2018 int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_2017_2018 from Cust_txns where transact_date between '2016-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_2017_2018=B.sum_2017_2018/* we are calculating total sales for 2017 and 2018*/
	where A.eos_user_id=B.eos_user_id;

	#Annualized_2017_2018

	alter table SVOC
	add column Annualized_sum_2017_2018 int(10);

	update SVOC A, (select eos_user_id,count(distinct(update_transact_year)) as Distinct_years from Cust_txns where transact_date between '2016-08-29' and '2018-08-28' group by eos_user_id) B
	set Annualized_sum_2017_2018=(A.sum_2017_2018)/B.Distinct_years
	where A.eos_user_id=B.eos_user_id;/* we are calculating annualized sums for 2017 and 2018*/

	

	/* Year on year Annualized sum */
	/*
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2012 int(10);
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2011 int(10);
	alter table SVOC add column Annualized_2012 int(10);
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2011 int(10);
	alter table SVOC add column Annualized_2012 int(10);
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2014 int(10);
	alter table SVOC add column Annualized_2015 int(10);
	alter table SVOC add column Annualized_2016 int(10);
	alter table SVOC add column Annualized_2017 int(10);
	alter table SVOC add column Annualized_sum_2018 int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2013 from Cust_txns where transact_date between '2004-08-29' and '2005-08-28' group by eos_user_id) B
	set A.Annualized_2005=B.Annualized_2005
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2012 from Cust_txns where transact_date between '2005-08-29' and '2006-08-28' group by eos_user_id) B
	set A.Annualized_2012=B.Annualized_2012
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2013 from Cust_txns where transact_date between '2006-08-29' and '2007-08-28' group by eos_user_id) B
	set A.Annualized_2013=B.Annualized_2013
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2011 from Cust_txns where transact_date between '2010-08-29' and '2011-08-28' group by eos_user_id) B
	set A.Annualized_2011=B.Annualized_2011
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2012 from Cust_txns where transact_date between '2011-08-29' and '2012-08-28' group by eos_user_id) B
	set A.Annualized_2012=B.Annualized_2012
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2013 from Cust_txns where transact_date between '2012-08-29' and '2013-08-28' group by eos_user_id) B
	set A.Annualized_2013=B.Annualized_2013
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2014 from Cust_txns where transact_date between '2013-08-29' and '2014-08-28' group by eos_user_id) B
	set A.Annualized_2014=B.Annualized_2014
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2015 from Cust_txns where transact_date between '2014-08-29' and '2015-08-28' group by eos_user_id) B
	set A.Annualized_2015=B.Annualized_2015
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2016 from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.Annualized_2016=B.Annualized_2016
	where A.eos_user_id=B.eos_user_id;


	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2017 from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.Annualized_2017=B.Annualized_2017
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_sum_2018 from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.Annualized_sum_2018=B.Annualized_sum_2018
	where A.eos_user_id=B.eos_user_id;
	*/
	alter table SVOC
	add column sum_entire int(10),
	add column Annualized_sum_entire int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_entire from Cust_txns where transact_date between '2004-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_entire=B.sum_entire
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(update_transact_year)) as Distinct_years from Cust_txns group by eos_user_id) B
	set Annualized_sum_entire=(A.sum_entire)/B.Distinct_years
	where A.eos_user_id=B.eos_user_id;
	###########################  segment
	
	/* mapping service segment for each Favourite Serivce ( Most frequent service used for each user )*/
	
	
	alter table SVOC
	add column Favourite_service_segment int(5);

	alter table SVOC
	add index(Favourite_service);

	alter table service
	add index(id);

	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment=B.service_segment
	where A.Favourite_service=B.id;



	###########################   Is_delay

	/* Creating indicator variable for each customer, whether that particular customer faced any delay or not */
	
	alter table SVOC
	add column is_delay varchar(2);

	update SVOC A
	set A.is_delay= 'Y'
	where Average_Delay>0;
	
	########################    L1 - SEGMENTATION    ##########################
    
	/* 
	
		L1 Segment - Using ATV and frequency for period 29th August 2017 and 28th August 2018 segmenting customers into 
		1) High Value High Frequency 
		2) High Value Low Frequency
		3) Low Value High Frequency
		4) Low Value Low Frequency
	*/

	alter table SVOC
	add column L1_SEGMENT varchar(5);
	
	UPDATE SVOC
	SET L1_SEGMENT = CASE WHEN ATV_1_year >= 480 AND frequency_1_year>= 3  THEN 'HH'
	WHEN ATV_1_year >= 480 AND frequency_1_year < 3   THEN 'HL'
	WHEN ATV_1_year < 480 AND frequency_1_year >= 3   THEN 'LH'
	WHEN ATV_1_year < 480 AND frequency_1_year < 3   THEN 'LL'
	ELSE NULL END;

	/* 
	
		L2 Segment - Using ATV, monetary value and frequency for period 29th August 2017 and 28th August 2018 segmenting customers into 22 different segments
		Customers not active in the given time period are also considered in the segments 14 to 18 and 21 to 22
	*/
	
	alter table SVOC
	add column L2_SEGMENT varchar(10);

	UPDATE SVOC
	SET L2_SEGMENT = 
	case when recency_1_year between 0 and 50 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '1' 
	when recency_1_year between 0 and 50 and frequency_1_year >= 3  AND ATV_1_year  <480 then '2'
	when recency_1_year between 0 and 50 and frequency_1_year =2 then '3'
	when recency_1_year between 51 and 100 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '4' 
	when recency_1_year between 51 and 100 and frequency_1_year >= 3  AND ATV_1_year  <480 then '5'
	when recency_1_year between 51 and 100 and frequency_1_year =2 then '6'
	when recency_1_year between 101 and 150 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '7' 
	when recency_1_year between 101 and 150 and frequency_1_year >= 3  AND ATV_1_year  <480 then '8'
	when recency_1_year between 101 and 150 and frequency_1_year =2 then '9'
	when recency_1_year between 151 and 250 and frequency_1_year>=3 then '10' 
	when recency_1_year between 151 and 250 and frequency_1_year=2 then '11'
	when recency_1_year between 251 and 365   and frequency_1_year>=3 then '12' 
	when recency_1_year between 251 and 365    and frequency_1_year=2 then '13'
	when Recency between 365 and 500 and Frequency >=4 and ATV_entire>=480 then '14'
	when Recency between 365 and 500 and Frequency >=4 and ATV_entire<480 then '15'
	when Recency between 365 and 500 and Frequency BETWEEN 2 and 3 then '16'
	when Recency between 500 and 730 and Frequency >1 then '17'
	when Recency > 730  and Frequency >1 then '18'  
	WHEN recency_1_year < 365 AND ATV_1_year >=480 and frequency_1_year=1 THEN '19' 
	WHEN recency_1_year < 365 AND ATV_1_year <480 and frequency_1_year =1 THEN '20' 
	when Recency >= 365 AND ATV_entire  >=480 and Frequency =1 THEN '21'
	WHEN Recency >= 365 AND ATV_entire  <480 and Frequency=1 THEN '22' 
	ELSE NULL END; 
	
	
	/* 
	
		Combining previous L2 Segments into 18 different segments
	*/

	
	ALTER TABLE SVOC add column  L2_SEGMENT_new varchar(2);
	UPDATE SVOC
	SET L2_SEGMENT_new = 
	case when recency_1_year between 0 and 50 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '1' 
	when recency_1_year between 0 and 50 and frequency_1_year >= 3  AND ATV_1_year  <480 then '2'
	when recency_1_year between 0 and 50 and frequency_1_year =2 then '3'
	when recency_1_year between 51 and 150 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '4' 
	when recency_1_year between 51 and 150 and frequency_1_year >= 3  AND ATV_1_year  <480 then '5'
	when recency_1_year between 51 and 150 and frequency_1_year =2 then '6'
	when recency_1_year between 151 and 365 and frequency_1_year>=3 then '7' 
	when recency_1_year between 151 and 365 and frequency_1_year=2 then '8'
	when Recency between 365 and 730 and Frequency >1  then '9'
	when Recency > 730  and Frequency >1 then '10'  
	WHEN recency_1_year < 365  AND frequency_1_year=1 THEN '11' 
	WHEN Recency >= 365 and Frequency=1 THEN '12' 
	ELSE NULL END; 

    /* L2_SEGMENT for 2015-2016  we are using frequency,ATV and recency cutoffs as we did for 2017-2018 */
	
	AlTER TABLE SVOC add column  L2_SEGMENT_new_2015_2016 varchar(2);
	
	set sql_safe_updates=0;
    UPDATE SVOC
	SET L2_SEGMENT_new_2015_2016 = 
	case when Recency_2015_2016_year between 0 and 50 and frequency_2015_2016_year >= 3 AND ATV_2015_2016_year  >=480 then '1' 
	when Recency_2015_2016_year between 0 and 50 and frequency_2015_2016_year >= 3  AND ATV_2015_2016_year  <480 then '2'
	when Recency_2015_2016_year between 0 and 50 and frequency_2015_2016_year =2 then '3'
	when Recency_2015_2016_year between 51 and 150 and frequency_2015_2016_year >= 3 AND ATV_2015_2016_year  >=480 then '4' 
	when Recency_2015_2016_year between 51 and 150 and frequency_2015_2016_year >= 3  AND ATV_2015_2016_year  <480 then '5'
	when Recency_2015_2016_year between 51 and 150 and frequency_2015_2016_year =2 then '6'
	when Recency_2015_2016_year between 151 and 365 and frequency_2015_2016_year>=3 then '7' 
	when Recency_2015_2016_year between 151 and 365 and frequency_2015_2016_year=2 then '8'
	when Recency between 365 and 730 and Frequency >1  then '9'
	when Recency > 730  and Frequency >1 then '10'  
	WHEN Recency_2015_2016_year < 365  AND frequency_2015_2016_year=1 THEN '11' 
	WHEN Recency >= 365 and Frequency=1 THEN '12' 
	ELSE NULL END; 
	
	 /* L2_SEGMENT for 2016-2017, we are using frequency,ATV and recency cutoffs as we did for 2017-2018 */
	
	ALTER TABLE SVOC add column  L2_SEGMENT_new_2016_2017 varchar(2);
	UPDATE SVOC
	SET L2_SEGMENT_new_2016_2017 = 
	case when Recency_2016_2017_year between 0 and 50 and frequency_2016_2017_year >= 3 AND ATV_2016_2017_year  >=480 then '1' 
	when Recency_2016_2017_year between 0 and 50 and frequency_2016_2017_year >= 3  AND ATV_2016_2017_year  <480 then '2'
	when Recency_2016_2017_year between 0 and 50 and frequency_2016_2017_year =2 then '3'
	when Recency_2016_2017_year between 51 and 150 and frequency_2016_2017_year >= 3 AND ATV_2016_2017_year  >=480 then '4' 
	when Recency_2016_2017_year between 51 and 150 and frequency_2016_2017_year >= 3  AND ATV_2016_2017_year  <480 then '5'
	when Recency_2016_2017_year between 51 and 150 and frequency_2016_2017_year =2 then '6'
	when Recency_2016_2017_year between 151 and 365 and frequency_2016_2017_year>=3 then '7' 
	when Recency_2016_2017_year between 151 and 365 and frequency_2016_2017_year=2 then '8'
	when Recency between 365 and 730 and Frequency >1  then '9'
	when Recency > 730  and Frequency >1 then '10'  
	WHEN Recency_2016_2017_year < 365  AND frequency_2016_2017_year=1 THEN '11' 
	WHEN Recency >= 365 and Frequency=1 THEN '12' 
	ELSE NULL END; 
	
	################      CAMPAIGN DATA  ##############

	/* Adding campaign variables for each customer based on aditya's mail of 10th October 2018 */

	create table hub 
	(Client_code varchar(10),
	First_Name varchar(25),
	Last_Name varchar(25),
	Partner int(5),
	Recent_Sales_Email_Replied_Date date,
	Type_of_Client varchar(15),
	Sends_Since_Last_Engagement int(5),
	Emails_Delivered int(5),
	Emails_Opened int(5),
	Emails_Clicked int(5),
	Emails_Bounced int(5),
	Unsubscribed_from_of_all_email varchar(1),
	Last_email_name varchar(100),
	Last_email_send_date date,
	Last_email_open_date date,
	Last_email_click_date date,
	First_email_send_date date,
	First_email_open_date date,
	First_email_click_date date
	);


	LOAD DATA LOCAL INFILE '/opt/cactusops/hub_spot.csv' IGNORE INTO TABLE hub
	FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
	LINES TERMINATED BY '\r\n'
	IGNORE 1 LINES
	(	
		Client_code ,
	First_Name ,
	Last_Name ,
	Partner ,
	Recent_Sales_Email_Replied_Date ,
	Type_of_Client ,
	Sends_Since_Last_Engagement ,
	Emails_Delivered ,
	Emails_Opened ,
	Emails_Clicked ,
	Emails_Bounced ,
	Unsubscribed_from_of_all_email ,
	Last_email_name ,
	Last_email_send_date ,
	Last_email_open_date ,
	Last_email_click_date ,
	First_email_send_date ,
	First_email_open_date ,
	First_email_click_date
	);

	/* adding campaign variables in the SVOC */

	alter table SVOC add column Client_code varchar(10) ;
	alter table SVOC add column First_Name varchar(25) ;
	alter table SVOC add column Last_Name varchar(25) ;
	alter table SVOC add column Partner int(5) ;
	alter table SVOC add column Recent_Sales_Email_Replied_Date date ;
	alter table SVOC add column Type_of_Client varchar(15) ;
	alter table SVOC add column Sends_Since_Last_Engagement int(5) ;
	alter table SVOC add column Emails_Delivered int(5) ;
	alter table SVOC add column Emails_Opened int(5) ;
	alter table SVOC add column Emails_Clicked int(5) ;
	alter table SVOC add column Emails_Bounced int(5) ;
	alter table SVOC add column Unsubscribed_from_of_all_email varchar(10) ;
	alter table SVOC add column Last_email_name varchar(100) ;
	alter table SVOC add column Last_email_send_date date ;
	alter table SVOC add column Last_email_open_date date ;
	alter table SVOC add column Last_email_click_date date ;
	alter table SVOC add column First_email_send_date date ;
	alter table SVOC add column First_email_open_date date ;
	alter table SVOC add column First_email_click_date date ;


	alter table SVOC add index(client_code);
	alter table hub add index(client_code);

	update SVOC A,hub B set A.Recent_Sales_Email_Replied_Date=B.Recent_Sales_Email_Replied_Date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Sends_Since_Last_Engagement=B.Sends_Since_Last_Engagement where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Delivered=B.Emails_Delivered where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Opened=B.Emails_Opened where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Clicked=B.Emails_Clicked where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Bounced=B.Emails_Bounced where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Unsubscribed_from_of_all_email=B.Unsubscribed_from_of_all_email where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_name=B.Last_email_name where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_send_date=B.Last_email_send_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_open_date=B.Last_email_open_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_click_date=B.Last_email_click_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.First_email_send_date=B.First_email_send_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.First_email_open_date=B.First_email_open_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.First_email_click_date=B.First_email_click_date where A.Client_code=B.Client_code;


	#######################     NEW_VARIABLES   HUBSPOT

	/* Derived Variables from campaign data */

	alter table SVOC add column Communication_tenure int(8),
	add column Communication_recency int(8),
	add column Was_last_mail_opened varchar(2),
	add column Open_rate double,
	add column Click_rate double, 
	add column Order_by_send_ratio double,
	add column Order_by_open_ratio double,
	add column Last_order_email int(8); 

	/*calculating tenure of campaign related communication for each customer */

	 update SVOC 
	 set Communication_tenure=datediff(Last_email_send_date,First_email_send_date);
	 
	/*calculating days since latest communication for each customer */
	 
	 update SVOC 
	 set Communication_recency=datediff(Last_email_send_date,'2018-08-28');

	 
	 /* Identifying whether last email was opened by the customer or not */
	 
	update SVOC 
	 set Was_last_mail_opened=
	 case when Last_email_open_date>Last_email_send_date
	 then 'Y' else 'N' end
	 where Last_email_open_date is not null and Last_email_send_date is not null;
	 
	 /* Percentage of the mails opened by the customer */
	 
	 update SVOC
	 set Open_rate=round((Emails_Opened/Emails_Delivered),3);
	 
	 /* Percentage of the mails clicked by the customer */
	 
	 update SVOC
	 set Click_rate=round((Emails_Clicked/Emails_Delivered),3);
	 
	 /* Ratio frequency of the customer to the emails delivered of the customer */
	 
	 update SVOC 
	 set Order_by_send_ratio=round((Frequency/Emails_Delivered),2);

	 /* Ratio frequency of the customer to the emails opened of the customer */
	 
	 update SVOC 
	 set Order_by_open_ratio=round((Frequency/Emails_Opened),2);
	 
	 /* Difference between the Last Transaction date of the customer and last email send date */
	 
	  update SVOC 
	 set Last_order_email=datediff(LTD,Last_email_send_date);
		
		#### TimeforJobCompletion ####

		/* computing the time taken for completion for each order */
		
	 alter table Cust_txns 
	 add column TimeForJobCompletion bigint;
	 
	 Update Cust_txns as A, 
	 (select ConfirmDate.id, TIMESTAMPDIFF(SECOND,ConfirmDate.ConfirmDate,SendToClientDate.SendToClientDate) as TimeToCompleteJob
	 from 
	 (SELECT id, min(confirmed_date) as ConfirmDate FROM
	 (SELECT id,sent_to_client_date,confirmed_date,type,component_type,parent_id
	 FROM component
	 order by id) B
	 where parent_id IS NULL
	 GROUP BY id) AS ConfirmDate JOIN
	 ( SELECT parent_id, max(sent_to_client_date) as SendToClientDate FROM
	 (SELECT id,sent_to_client_date,confirmed_date,type,component_type,parent_id
	 FROM component
	 order by id) B
	 where parent_id IS NOT NULL
	 GROUP BY parent_id) as SendToClientDate
	 ON ConfirmDate.id = SendToClientDate.parent_id) as TIMETABLE
	 SET A.TimeForJobCompletion =TIMETABLE.TimeToCompleteJob
	 where A.component_id=TIMETABLE.id
	 ;
	
	
	############## Updating Avg_days_for_jobCompl in SVOC ##############
	ALTER TABLE SVOC
	add column Avg_days_for_jobCompl int; 

	UPDATE SVOC A, 
	(SELECT eos_user_id, Cast(Avg(TimeForJobCompletion)/(3600*24) as int) as Avg_Time_for_Compl  FROM Cust_txns
	WHERE left(Created_date, 10) > '2015-08-28'
	GROUP BY eos_user_id) as ComplTimeTable
	set A.Avg_days_for_jobCompl = ComplTimeTable.Avg_Time_for_Compl
	WHERE A.eos_user_id = ComplTimeTable.eos_user_id;

	 ############
	 # 4. First_subject_in_top_subject_areas (Is the subject in first transaction is in top subjects)
	-- # Is_in_top_sub_Area (Is subject_area_id in top Subject Areas) in Cust_txns
	
	/* Indicator variable whether the customer's subject area is among the top subject areas */
	
	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area varchar(2) default 'N',

	UPDATE Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,1088,524,742,921,1072,1075,1388,168,207,500,528,554,560,597,616,710,812,827,840,861,863,898,914,935,936,979,1016,1018,1053,1078,1127,1155,1173,1183,1219,1223,1240,1274,1326,1391,1394,1422,1456,1496,2062,858,962,1265,161,1190,196,689,705,799,922,934,1021,1259,1387,1414,1446,1460,604,804,1095,1296,630,247,214,942,1564,888,1325,290,1405,1157,1312,797,1567,598,1070,628,824,205,573,41,600,932,1220,474,481,502,523,590,612,624,632,682,709,819,826,866,868,881,893,967,1017,1038,1152,1199,1225,1241,1243,1340,1351,1354,1364,1462,1467,1573,303,1092,1282);
	
	/* Indicator variable whether the customer's subject area is among the top subject areas for the time period 2015-2016*/
	
	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2015_2016 varchar(2) default 'N',

	UPDATE SVOC  
	SET Is_in_top_sub_Area_2015_2016 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area = 'Y' and transact_date BETWEEN '2015-08-29' AND '2016-08-28');
	
	/* Indicator variable whether the customer's First subject area is among the top subject areas for the time period 2015-2016*/
	
	ALTER TABLE SVOC
	ADD Column First_subject_in_top_subject_areas varchar(2) default 'N';

	UPDATE SVOC A, Cust_txns B
	set A.First_subject_in_top_subject_areas = 'Y'
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.Is_in_top_sub_Area = 'Y';
		
	/* Adding  Revision variables for each customer */
	
	#####################     revision table
	/* mapping enquiry_id for each order in the revisions table */
	
	alter table content_type_enquiry add index(nid);
	alter table migration add index(whiteboard_id);

	update content_type_enquiry A,migration B
	set A.enquiry_id=B.crm_id
	where A.nid=B.whiteboard_id and B.whiteboard_table='enquiry';

	/* Calculating revision tags for each enquiry from revision data */
	
	/* For each node id calculating earliest version id and the latest version id */
	
	create temporary table revise as
	select A.* from
	content_type_enquiry A,
	(select nid,min(vid) as first_revision,max(vid) as last_revision from content_type_enquiry
	group by nid) B
	where (vid=first_revision or vid=last_revision) and A.nid=B.nid;


	alter table content_type_enquiry add index(vid),add index(nid);

	/* 
	
	we are measuring revision in four cases 
	1) price_after_tax
	2) subject_area
	3) service_id
	4) delivery_date 
	
	*/
	alter table enquiry add column Revision_in_subject_area varchar(2),add column Revision_in_price_after_tax varchar(2),add column Revision_in_service_id varchar(2),add column Revision_in_delivery_date varchar(2),add index(id);

	alter table revise add index(nid,vid),add index(enquiry_id),add index(enquiry_id);

	/* For calculating revision in one particular field for example, subject area we measure whether field_enquiry_subjectarea_value for earliest version id is different from the latest version id for each node id, if it is true then we define that revision existed in the enquiry */
	
	# 1  Subject

	create temporary table subject as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_subjectarea_value <>
		  ( SELECT b.field_enquiry_subjectarea_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
		  
	set sql_safe_updates=0;
	alter table subject add index(enquiry_id);

	update enquiry A,subject B
	set Revision_in_subject_area='Y' where A.id=B.enquiry_id;

		  

	#  2 price_after_tax
	 
	create temporary table price_after_tax as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_price_after_tax_value <>
		  ( SELECT b.field_enquiry_price_after_tax_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table price_after_tax add index(enquiry_id);
	  
	update enquiry A,price_after_tax B
	set Revision_in_price_after_tax='Y' where A.id=B.enquiry_id;


	# 3 Service
	 
	create temporary table service as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_service_nid <>
		  ( SELECT b.field_enquiry_service_nid
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table service add index(enquiry_id);
	  
	update enquiry A,service B
	set Revision_in_service_id='Y' where A.id=B.enquiry_id;


	#  4   Delivery Date

	create temporary table delivery_date as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_delivery_date_value <>
		  ( SELECT b.field_enquiry_delivery_date_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table delivery_date add index(enquiry_id);
	  
	update enquiry A,delivery_date B
	set Revision_in_delivery_date='Y' where A.id=B.enquiry_id;


	#  5 words

	alter table enquiry add column Revision_in_words varchar(2);
	create temporary table words as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_unit_count_value <>
		  ( SELECT b.field_enquiry_unit_count_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table words add index(enquiry_id);
	  
	update enquiry A,words  B
	set Revision_in_words='Y' where A.id=B.enquiry_id;
	
	
-- Updating Revision variables in Cust_txns from enquiry 

	alter table Cust_txns add column Revision_in_subject_area varchar(2);
	alter table Cust_txns add column Revision_in_price_after_tax varchar(2);
	alter table Cust_txns add column Revision_in_service_id varchar(2);
	alter table Cust_txns add column Revision_in_delivery_date varchar(2);
	alter table Cust_txns add column Revision_in_words varchar(2);

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	-- Updating Revision variables in SVOC from Cust_txns


	ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area int,
	add column No_of_Revision_in_price_after_tax int,
	add column No_of_Revision_in_service_id int,
	add column No_of_Revision_in_delivery_date int,
	add column No_of_Revision_in_words int;
	
	
	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;
			
	


	ALTER TABLE SVOC
	add column ratio_of_Revision_in_subject_area_2016_2017 double,
	add column ratio_of_Revision_in_price_after_tax_2016_2017 double,
	add column ratio_of_Revision_in_service_id_2016_2017 double,
	add column ratio_of_Revision_in_delivery_date_2016_2017 double,
	add column ratio_of_Revision_in_words_2016_2017 double;

	update SVOC
	set 
	ratio_of_Revision_in_subject_area_2016_2017 =No_of_Revision_in_subject_area_2016_2017/frequency_2016_2017_year
	,ratio_of_Revision_in_price_after_tax_2016_2017 =No_of_Revision_in_price_after_tax_2016_2017/frequency_2016_2017_year,
	ratio_of_Revision_in_service_id_2016_2017 =No_of_Revision_in_service_id_2016_2017/frequency_2016_2017_year,
	ratio_of_Revision_in_delivery_date_2016_2017 =No_of_Revision_in_delivery_date_2016_2017/frequency_2016_2017_year,
	ratio_of_Revision_in_words_2016_2017=No_of_Revision_in_words_2016_2017/frequency_2016_2017_year;


	alter table SVOC 
	add column No_of_premium_orders_2016_2017 int(5),add column No_of_non_premium_orders_2016_2017 int(5);

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' and Premium='Yes' group by eos_user_id) B
	set A.No_of_premium_orders_2016_2017=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC add column No_of_non_premium_orders int(5);

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where transact_date between '2016-08-29' and '2017-08-28'  and Premium='No' group by eos_user_id) B
	set A.No_of_non_premium_orders_2016_2017=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC 
	add column Ratio_of_premium_to_total_2016_2017 double,add column Ratio_of_non_premium_to_total_2016_2017 double;

	update SVOC
	set Ratio_of_premium_to_total_2016_2017=(No_of_premium_orders_2016_2017)/(frequency_2016_2017_year);

	update SVOC
	set Ratio_of_non_premium_to_total_2016_2017=(No_of_non_premium_orders_2016_2017)/(frequency_2016_2017_year);

	alter table SVOC
	add column Ratio_of_premium_to_total_2016_2017_band varchar(10);

	update SVOC
	set Ratio_of_premium_to_total_2016_2017_band=
	case when (Ratio_of_premium_to_total_2016_2017 between 0 and 0.1 or Ratio_of_premium_to_total_2016_2017 
	is null) then '0% - 10%' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.1 and 0.2 then '10% -20% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.2 and 0.3 then '20% -30% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.3 and 0.4 then '30% - 40%' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.4 and 0.5 then '40% -50% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.5 and 0.6 then '50% -60% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.6 and 0.7 then '60% - 70%' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.7 and 0.8 then '70% - 80% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.8 and 0.9 then '80% - 90% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.9 and 1 then '90% - 100% ' else null
	end end end end end end end end end end;

	######################     new variables created - nov 9

	alter table SVOC  add column enquiry_job_ratio double,paid_mre_percent_to_total double,distinct_translators int(3);		
	alter table SVOC  add column (enquiry_job_ratio double,paid_mre_percent_to_total double,distinct_translators int(3));
	
	# Distinct Translators /* Distinct wb_user_ids allocated for a customer */

	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators from Cust_txns group by eos_user_id) B
	set A.distinct_translators=B.distinct_translators
	where A.eos_user_id=B.eos_user_id;/* Lifetime different types of translators for each customer */

	alter table SVOC add column distinct_translators_2015_2016 int;
	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators_2015_2016 from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.distinct_translators_2015_2016=B.distinct_translators_2015_2016
	where A.eos_user_id=B.eos_user_id; /* Different types of translators for each customer in the time period 2015-08-29 and 2016-08-28*/

	
	# Enquiry_job
	
	/* Number of valid orders to the number of enquiries calculated for each customer */
	
	update SVOC A,(select B.eos_user_id,count(case when component_type='job' and price_after_tax is not null and price_after_tax>0 and type='normal' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio=A.Frequency/B.enquiries
	where A.eos_user_id=B.eos_user_id;
	
	/* Number of valid orders to the number of enquiries calculated for each customer for 2015-2016 (Aug-Aug cycle*/
	
	alter table SVOC add column enquiry_job_ratio_2015_2016 double; 
	update SVOC A,(select B.eos_user_id,count(case when  component_type='job' and price_after_tax is not null and price_after_tax>0type='normal' and left(A.created_date,10) between '2015-08-29' and '2016-08-28' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio_2015_2016=A.frequency_2015_2016_year/B.enquiries
	where A.eos_user_id=B.eos_user_id;
	
	/* 2015_2016 RFM variables year */
	
	alter table SVOC
	add column  ATV_2015_2016_year int(10),
	add column frequency_2015_2016_year int(4),
	add column Recency_2015_2016_year int(5),
	add column FTD_2015_2016_years date,
	add column LTD_2015_2016_years date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') B group by eos_user_id) B
	set A.FTD_2015_2016_years=B.FTD_1_years,A.LTD_2015_2016_years=B.LTD_1_years,A.frequency_2015_2016_year=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id ;

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2015-08-29' and '2016-08-28' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_2015_2016_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_2015_2016_year=datediff('2016-08-28',LTD_2015_2016_years)
	where frequency_2015_2016_year is not null;
    
	alter table SVOC
    add column ADGBT_2015_2016_year int(5),
    add column Inactivity_ratio_2015_2016_year double,
    add column STD_2015_2016_year date,
    add column Bounce_2015_2016_year int(11),
    add column Total_Standard_price_2015_2016_year decimal(18,6);
    
	update SVOC
	set ADGBT_2015_2016_year=datediff(LTD_2015_2016_years,FTD_2015_2016_years)/(frequency_2015_2016_year-1)
	 where (Sept_2016='Y' ) and frequency_2015_2016_year is not null;

	update SVOC
	set Inactivity_ratio_2015_2016_year = Recency_2015_2016_year/ADGBT_2015_2016_year;

	set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_2015_2016_year = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2015-08-29' and '2016-08-28'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_2015_2016_year > 1 ;
            
	update SVOC
	set Bounce_2015_2016_year = datediff(STD_2015_2016_year,FTD_2015_2016_years)
	where frequency_2015_2016_year>1 and STD_2015_2016_year is not null;
    
	update SVOC A,(select eos_user_id,
	sum(case when transact_date between '2015-08-29' and '2016-08-28' then Standardised_Price end) as Total_Standard_price_2015_2016_year 
	from Cust_txns  group by eos_user_id) B
		set A.Total_Standard_price_2015_2016_year=B.Total_Standard_price_2015_2016_year
	where A.eos_user_id=B.eos_user_id;
    
	######################		Premium			#########################

	/* Mapping service with the premium service */  
	
	alter table service add column Premium varchar(5);

	update service  A, premium B
	set A.Premium =B.Premium 
	where A.name=B.Name;

	alter table Cust_txns
	add column Premium varchar(5);

	update Cust_txns  A, service B
	set A.Premium =B.Premium 
	where A.service_id=B.id;

	/* 
	No_of_premium_orders - total premium orders by the customer 
	No_of_non_premium_orders - total non-premium orders by the customer 
	Ratio_of_premium_to_non_premium - (No_of_premium_orders)/(No_of_non_premium_orders)
	first_order_premium - indicator variable for each customer whether first order by customer is a premium order
	*/
	
	alter table SVOC 
	add column No_of_premium_orders int(5),add column No_of_non_premium_orders int(5),add column Ratio_of_premium_to_non_premium double,add column first_order_premium varchar(2) default 'N';

	
	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where Premium='Yes' group by eos_user_id) B
	set A.No_of_premium_orders=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where Premium='No' group by eos_user_id) B
	set A.No_of_non_premium_orders=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC
	set Ratio_of_premium_to_non_premium=(No_of_premium_orders)/(No_of_non_premium_orders);

	update SVOC A,Cust_txns B
	set A.first_order_premium ='Y'
	where A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id and B.Premium='Yes';
	/* for mapping first transaction order for customer we equate the FTD of the customer with the transact_date of the customer, this practice automatically maps details of FTD with the first transact_date */

	
	/* To identify whether the customer has ever transacted */
	
	 alter table SVOC
	 add column is_ever_premium_buyer varchar(2) default 'N';
	 
	 update SVOC A,(select distinct eos_user_id from Cust_txns where Premium='Yes') B
	 set A.is_ever_premium_buyer='Y'
	 where A.eos_user_id=B.eos_user_id;
	 
	 /* 
		
	No_of_premium_orders_2017_2018 - total premium orders by the customer for 17-18 Aug-Aug cycle
	No_of_non_premium_orders_2017_2018 - total non-premium orders by the customer for 17-18 Aug-Aug cycle
	Ratio_of_premium_to_non_premium_2017_2018 - (No_of_premium_orders)/(No_of_non_premium_orders) for 17-18 Aug-Aug cycle
	
	*/

	alter table SVOC 
	add column No_of_premium_orders_2017_2018 int(5),add column No_of_non_premium_orders_2017_2018 int(5),add column Ratio_of_premium_to_non_premium_2017_2018 double;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where Premium='Yes' and transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.No_of_premium_orders_2017_2018=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_non_premium_orders from Cust_txns where Premium='No' and transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.No_of_non_premium_orders_2017_2018=B.No_of_non_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC
	set Ratio_of_premium_to_non_premium_2017_2018=(No_of_premium_orders_2017_2018)/(No_of_non_premium_orders_2017_2018);

	
		

	###########################              fill_rate

	/* fill rating is the ratio of the cases where rating was not null divided by the total orders */
	
	alter table SVOC add column fill_rating_2017_2018 double;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as fill_rating_2017_2018 from Cust_txns where rate is not null and transact_date between '2017-08-29'
	 and '2018-08-28' group by eos_user_id) B
	 set A.fill_rating_2017_2018=(B.fill_rating_2017_2018)/A.frequency_1_year
	 where A.eos_user_id=B.eos_user_id;/*fill rating with order in the period 29th Aug 2017 to 28th Aug 2018 */


	alter table SVOC add column fill_rating_2016_2017 double;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as fill_rating_2016_2017 from Cust_txns where rate is not null and transact_date between '2016-08-29'
	 and '2017-08-28' group by eos_user_id) B
	 set A.fill_rating_2016_2017=(B.fill_rating_2016_2017)/A.frequency_2016_2017_year
	 where A.eos_user_id=B.eos_user_id;/*fill rating with order in the period 29th Aug 2016 to 28th Aug 2017 */
	
	/* 
	Mapping translated name for each university to the respective user
	User_University - is a table which contains translated_name of each university 
	
	- eos_user_id, partner_id, original_name, translated_name
	So we map each eos_user_id with the translated University_name 
	
	*/

	alter table SVOC
	add column University_name varchar(500);

	update SVOC A,User_University B
	set A.University_name=B.TranslatedName
	where A.eos_user_id=B.eos_user_id;


	#############################    Feedback CLassifier
	
	/*
	feedback classifier - we have created this variable for the time period 2016-08-29 and 2017-08-28
	Creating indicator variables based on the rating history of the customer 
	If the customer has single rating as outstanding then we tag as '3'
	If the customer has single rating as not rated cases then we tag as '1'
	If the customer has single rating as acceptable or not-acceptable then we tag '2'
	If the customer has rated twice, as Outstanding and Not-Rated then we tag '3'
	Rest all cases are tagged as '2'
	*/
	
	drop table distinct_rating_16_17;
	create temporary table distinct_rating_16_17 as
	select eos_user_id,count(distinct IFNULL(rate,0)) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' 
	group by eos_user_id;

	alter table distinct_rating_16_17
	add column O varchar(2) default 'N',
	add column A varchar(2) default 'N',
	add column NA varchar(2) default 'N',
	add column NR varchar(2) default 'N';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.O='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate='outstanding';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.A='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate='acceptable';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.NA='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate='not-acceptable';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.NR='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate is null;

	alter table SVOC
	add column Feedback_Classifier varchar(3);

	update SVOC A,distinct_rating_16_17 B
	set A.Feedback_Classifier=
	case when 
	B.rate =1 and O='Y' then '3' else
	case when
	B.rate =1 and NR='Y' then '1' else
	case when
	B.rate =1 and (NA='Y' or A='Y') then '2' else
	case when 
	B.rate =2 and (O='Y' and NR='Y') then '3' else '2'
	end end end end 
	where 
	A.eos_user_id=B.eos_user_id;


	##################   creating variables for 2016-2017     ##########################
	
	alter table SVOC add column percent_not_acceptable_cases_2016_2017 float(2);
	alter table SVOC add column percent_acceptable_cases_2016_2017 double;
	alter table SVOC add column percent_not_rated_cases_2016_2017 double;
	alter table SVOC add column percent_outstanding_cases_2016_2017 double;
	alter table SVOC add column percent_discount_cases_2016_2017 double;
	alter table SVOC add column percent_delay_cases_2016_2017 double;
	alter table SVOC add column Range_of_services_2016_2017 int(5);
	alter table SVOC add column Range_of_subjects_2016_2017 int(5);
	alter table SVOC add column Average_word_count_2016_2017 int(5);
	alter table SVOC add column Average_Delay_2016_2017 int(5);
	alter table SVOC add column Favourite_Week_number_2016_2017 varchar(2);
	alter table SVOC add column Favourite_Month_2016_2017 varchar(2);
	alter table SVOC add column Favourite_Time_2016_2017 varchar(4);
	alter table SVOC add column Favourite_Day_Week_2016_2017 varchar(2);
	alter table SVOC add column maximum_rating_2016_2017 varchar(20);
	alter table SVOC add column Range_of_subjects_1_6_2016_2017 int(5);

	update SVOC A,(select eos_user_id,count(distinct SA1_6_id) as Range_of_subjects_1_6_2016_2017 from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.Range_of_subjects_1_6_2016_2017=B.Range_of_subjects_1_6_2016_2017
	where
	A.eos_user_id=B.eos_user_id;
	
	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2016_2017=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_acceptable_cases_2016_2017 =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_not_rated_cases_2016_2017=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_outstanding_cases_2016_2017=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_discount_cases_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_delay_cases_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.Range_of_services_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.Range_of_subjects_2016_2017= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.Average_word_count_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.Average_Delay_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;


	UPDATE IGNORE
				SVOC A
			SET Favourite_Week_number_2016_2017=(
	SELECT 
							Week_number
						FROM (select eos_user_id,Week_number,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Week_number order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id 
						ORDER BY ratings desc,sum desc
						LIMIT 1);
	UPDATE IGNORE
				SVOC A
			SET Favourite_Month_2016_2017=(
	SELECT 
							Favourite_Month
						FROM (select eos_user_id,Favourite_Month,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Favourite_Month order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
	UPDATE IGNORE
				SVOC A
			SET Favourite_Day_Week_2016_2017=(
	SELECT 
							Favourite_Day_Week
						FROM (select eos_user_id,Favourite_Day_Week,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Favourite_Day_Week order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
						
	 UPDATE IGNORE
				SVOC A
			SET Favourite_Time_2016_2017=(
	SELECT 
							Favourite_Time
						FROM (select eos_user_id,Favourite_Time,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Favourite_Time order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);


	UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2016_2017 = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

		SELECT eos_useR_id, maximum_rating_2016_2017 FROM SVOC
		WHERE eos_user_id = 228307;
	   

	alter table SVOC
		add column percent_offer_cases_2016_2017 int(8);

		update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
		set A.percent_offer_cases_2016_2017=B.percent_offer_cases 
		where A.eos_user_id=B.eos_user_id;
		
		
		alter table SVOC add column 
		Number_of_times_rated_2016_2017 int(5);
		
		update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
		set Number_of_times_rated_2016_2017=rate_count
		where A.eos_user_id=B.eos_user_id;
		
		alter table SVOC add column is_delay_2016_2017 varchar(2);
		
		update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
		set is_delay_2016_2017='Y'
		where Average_Delay_2016_2017 >0  and Average_Delay_2016_2017 is not null and A.eos_user_id=B.eos_user_id;

		
	#################    Favourite Service

		alter table SVOC
		add column Favourite_service_segment_2016_2017 int(5);

		alter table service
		add index(id);

	alter table SVOC add column Favourite_service_2016_2017 varchar(20);
		 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_service_2016_2017=(
						SELECT 
							service_id
						FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,service_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

		set sql_safe_updates=0;
		update SVOC A,service B
		set A.Favourite_service_segment_2016_2017=B.service_segment
		where A.Favourite_service_2016_2017=B.id;	
		

	##### 

	ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area_2016_2017 int,
	add column No_of_Revision_in_price_after_tax_2016_2017 int,
	add column No_of_Revision_in_service_id_2016_2017 int,
	add column No_of_Revision_in_delivery_date_2016_2017 int,
	add column No_of_Revision_in_words_2016_2017 int;


	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area_2016_2017 = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax_2016_2017 = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id_2016_2017 = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date_2016_2017 = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words_2016_2017 = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;
 
	ALTER TABLE SVOC
	add column Favourite_subject_2016_2017 int(11),
	add column Favourite_SA1_name_2016_2017 varchar(100) ,
	add column Favourite_SA1_5_name_2016_2017 varchar(100),
	add column Favourite_SA1_6_name_2016_2017 varchar(100);

	/*ALTER TABLE SVOC
	change Favourite_SA1_name_2016_2017 Favourite_SA1_name_2016_2017 varchar(100),
	change Favourite_SA1_5_name_2016_2017 Favourite_SA1_5_name_2016_2017 varchar(100),
	change Favourite_SA1_6_name_2016_2017 Favourite_SA1_6_name_2016_2017 varchar(100);*/



	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2016_2017 = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2016_2017 =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

		 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2016_2017 =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

		 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2016_2017 =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					); 
					
	alter table SVOC
		add column ADGBT_2016_2017_year int(5),
		add column Inactivity_ratio_2016_2017_year double,
		add column STD_2016_2017_year date,
		add column Bounce_2016_2017_year int(11),
		add column Total_Standard_price_2016_2017_year decimal(18,6);
		
	update SVOC
		set ADGBT_2016_2017_year=datediff(LTD_2016_2017_years,FTD_2016_2017_years)/(frequency_2016_2017_year-1)
		 where (Sept_2017='Y' ) and frequency_2016_2017_year is not null;

	update SVOC
		set Inactivity_ratio_2016_2017_year = Recency_2016_2017_year/ADGBT_2016_2017_year;

	 
		
	set sql_safe_updates=0;
		 UPDATE IGNORE
				SVOC A
			SET 
				STD_2016_2017_year = (
						SELECT 
							transact_date
						FROM Cust_txns AS B
						WHERE
							A.eos_user_id = B.eos_user_id
						and transact_date between '2016-08-29' and '2017-08-28'
						ORDER BY transact_date ASC
						LIMIT 1,1
					)
			WHERE 
				frequency_2016_2017_year > 1 ;
				
	update SVOC
		set Bounce_2016_2017_year = datediff(STD_2016_2017_year,FTD_2016_2017_years)
		where frequency_2016_2017_year>1 and STD_2016_2017_year is not null;
		

	update SVOC A,(select eos_user_id,
	sum(case when transact_date between '2016-08-29' and '2017-08-28' then Standardised_Price end) as Total_Standard_price_2016_2017_year 
	from Cust_txns  group by eos_user_id) B
		set A.Total_Standard_price_2016_2017_year=B.Total_Standard_price_2016_2017_year
		where A.eos_user_id=B.eos_user_id;
		

		
	##############################       Extra variables created ####################
		
	alter table SVOC 
	add column is_preferred_transalator_2016_2017 varchar(2);

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2016-08-29' and '2017-08-28') B
	set A.is_preferred_transalator_2016_2017='Y'
	where A.eos_user_id=B.eos_user_id;


	alter table SVOC add column enquiry_job_ratio_2016_2017 double; 
	update SVOC A,(select B.eos_user_id,count(case when type='normal' and left(A.created_date,10) between '2016-08-29' and '2017-08-28' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio_2016_2017=A.frequency_2016_2017_year/B.enquiries
	where A.eos_user_id=B.eos_user_id;


	alter table SVOC add column distinct_translators_2016_2017 int;
	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators_2016_2017 from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.distinct_translators_2016_2017=B.distinct_translators_2016_2017
	where A.eos_user_id=B.eos_user_id;	
		

	-- HAs ever rated in period 2016_2017

	ALTER TABLE SVOC
	add column Ever_rated_2016_2017 varchar(2) default 'N';

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate is not null AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_2016_2017 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	/*outstanding
	acceptable
	not-acceptable*/

	-- Has ever rated outstanding/not-acceptable in period 2016_2017
	ALTER TABLE SVOC
	add column Ever_rated_outstanding_2016_2017 varchar(2) default 'N',
	add column Ever_rated_acceptable_2016_2017 varchar(2) default 'N',
	add column Ever_rated_not_acceptable_2016_2017 varchar(2) default 'N';


	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'outstanding' AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_outstanding_2016_2017 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'acceptable' AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_acceptable_2016_2017 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'not-acceptable' AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_not_acceptable_2016_2017 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	/*
	########################### Is subject_area_id in top Subject Areas. #################
	########################### Updating Cust_txns before updating SVOC ################

	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1 varchar(2) default 'N';

	UPDATE Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	UPDATE Cust_txns
	SET Is_in_top_sub_Area_1 = 'Y'
	WHERE subject_area_id IN 
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282,	84,	1279,	310,	85,	1348,	1566,	378,	1532,	339,	533,	199,	1475,	204,	1171,	1355,	159,	297,	478,	563,	795,	1228,	1238,	1210,	1290,	111,	460,	532,	1481,	419,	357,	658,	170,	251,	518,	537,	720,	875,	1143,	1266,	1568,	1560,	667,	1112,	1540,	1437,	637,	772,	1047,	1189,	102,	1116,	1544,	129,	329,	1359,	752,	262,	588,	91,	761,	1124,	98,	217,	629,	1138,	1569,	130,	530,	541,	669,	758,	1037,	1058,	1174,	1179,	1245,	184,	1356,	1402,	328,	1358,	435,	1497,	1505,	1105,	302,	1403,	670,	806,	2070,	387,	58,	439,	249,	4,	65,	295,	458,	663,	1102,	352,	781,	366,	92,	471,	1526,	807,	1517,	1098,	135,	14,	1048,	1012,	1193,	108,	466,	890,	969,	255,	1398,	1559,	35,	1154,	190,	133,	1382,	574,	1534,	416,	1381,	1523,	311,	117,	31,	1323,	1527,	422,	40,	462,	1404,	162,	769,	373,	565,	314,	425,	576,	332,	1313,	143,	367,	428,	292,	16,	105,	153,	745,	1278,	1324,	48,	1487,	43,	124,	126,	70,	305,	327,	544,	551,	570,	594,	741,	940,	1468,	152,	298,	564,	639,	704,	1473,	1528,	389,	493,	542,	620,	650,	676,	679,	684,	701,	708,	728,	750,	778,	810,	862,	876,	880,	897,	901,	945,	961,	966,	990,	1011,	1022,	1057,	1104,	1239,	1390,	1451,	1457,	1495,	1507,	2073,	2077,	738,	1107,	88,	557,	578,	1181,	324,	140,	753,	151,	464,	1365,	1201,	1430,	1194,	21,	1482,	1097,	1114,	1492,	202,	403,	1454,	323,	1552,	1545,	763,	294,	755,	923,	1525,	1529,	1197,	188,	1281,	1334,	286,	1184,	110,	1561,	412,	1263,	1408,	1417,	322,	115,	107,	1087,	104,	429,	671,	8,	380,	121,	242,	1300,	662,	1297,	1399,	257,	163,	413,	1090,	721,	802,	1214,	469,	1187,	193,	749,	1352,	1081,	1434,	1548,	800,	1208,	178,	183,	2078,	349,	227,	1518,	371,	142,	259,	472,	96,	1117,	1431,	67,	567,	924,	1059,	1196,	71,	1510,	1294,	34,	39,	348,	1,	291,	33,	1302,	1145,	1200,	1384,	446,	1480,	572,	274,	410,	106,	38,	239,	734,	321,	167,	277,	1409,	1385,	1109,	224,	1555,	441,	1306,	390,	1280,	1508,	1537,	264,	463,	938,	1346,	99,	245,	317,	447,	968,	992,	993,	995,	1042,	1226,	1310,	1450,	1485,	1113,	571,	331,	394,	395,	1303,	377,	225,	50,	1415,	631,	1494,	150,	269,	341,	1299,	1531,	95,	94,	128,	1488,	1068,	271,	198,	37,	1307,	125,	796,	1186,	5,	100,	330,	1530,	1277,	144,	602,	626,	997,	206,	459,	485,	989,	1261,	1341,	1574,	360,	1301,	1198,	46,	63,	579,	293,	586,	432,	375,	381,	430,	1026,	248,	97,	1285,	231,	437,	455,	633,	664,	1028,	1106,	103,	398,	1372,	253,	1360,	756,	768,	1270,	1367,	1501,	112,	468,	771,	344,	568,	1576,	1484,	287,	53,	18,	189,	118,	1202,	1206,	1550,	177,	1249,	407,	408,	114,	345,	941,	1096,	1188,	243,	270,	241,	234,	51,	361,	1308,	12,	374,	62,	307,	219);*/


	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2016_2017 varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_2016_2017 varchar(2) default 'N';

	UPDATE SVOC  
	SET Is_in_top_sub_Area_2016_2017 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area = 'Y' and transact_date between '2016-08-29' and '2017-08-28');

	UPDATE SVOC  
	SET Is_in_top_sub_Area_1_2016_2017 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_1 = 'Y' and transact_date between '2016-08-29' and '2017-08-28');

	-- Vintage(From 2016-08-28) and New or existing in (2015-16)

	ALTER TABLE SVOC
	add column Vintage_2016_2017 int,
	add column New_or_existing_in_2016_2017 varchar(10) ;

	UPDATE SVOC
	set Vintage_2016_2017 = TIMESTAMPdiff(MONTH, FTD, '2017-08-28'),
	New_or_existing_in_2016_2017 = CASE WHEN FTD BETWEEN '2016-08-29' AND '2017-08-28' THEN 'new' ELSE 'existing' END;


	-- Number of paid-mre, valid-mre, qualityre-edit in 2015-2016
		
		drop table mre;
		create temporary table mre as
		select eos_user_id,enquiry_id,left(B.created_date,10) as transact_date,type from enquiry A,component B
		where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client' and price_after_tax is not null and price_after_tax > 0 
		group by eos_user_id,enquiry_id;

	ALTER TABLE SVOC
	ADD Column No_of_paid_mre_in_2016_2017 int default 0,
	ADD Column No_of_valid_mre_in_2016_2017 int default 0,
	ADD Column No_of_quality_reedit_mre_in_2016_2017 int default 0;

	update SVOC 
	set No_of_paid_mre_in_2016_2017 =0,No_of_valid_mre_in_2016_2017=0,No_of_quality_reedit_mre_in_2016_2017=0;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='paid-mre' and transact_date between '2016-08-29' and '2017-08-28'  GROUP BY eos_user_id) B
	set A.No_of_paid_mre_in_2016_2017 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='valid-mre' and transact_date between '2016-08-29' and '2017-08-28' GROUP BY eos_user_id) B
	set A.No_of_valid_mre_in_2016_2017 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='quality-re_edit' and transact_date between '2016-08-29' and '2017-08-28' GROUP BY eos_user_id) B
	set A.No_of_quality_reedit_mre_in_2016_2017 = B.count
	where A.eos_user_id = B.eos_user_id;

	

	ALTER TABLE SVOC
	ADD Column Ratio_paid_mre_to_total_orders_2016_2017 double,
	ADD Column Ratio_valid_mre_to_total_orders_2016_2017 double,
	ADD Column Ratio_quality_re_edit_mre_to_total_orders_2016_2017 double;

	update SVOC 
	set Ratio_paid_mre_to_total_orders_2016_2017 =null,
	Ratio_valid_mre_to_total_orders_2016_2017 =null,Ratio_quality_re_edit_mre_to_total_orders_2016_2017=null;

	UPDATE SVOC
	SET Ratio_paid_mre_to_total_orders_2016_2017 = No_of_paid_mre_in_2016_2017 / frequency_2016_2017_year,
	Ratio_valid_mre_to_total_orders_2016_2017 = No_of_valid_mre_in_2016_2017 / frequency_2016_2017_year,
	Ratio_quality_re_edit_mre_to_total_orders_2016_2017 = No_of_quality_reedit_mre_in_2016_2017 / frequency_2016_2017_year;

	########################  mre variables for 2016_2017

	/* calculating cases with percentage of paid mre,valid mre and quality-re_edit for the time period 2016-08-29 and 2017-08-28 */
	
	alter table SVOC 
	add column percent_paid_mre_2016_2017  double,
	add column percent_valid_mre_2016_2017  double,
	add column percent_quality_reedit_2016_2017  double;

	
	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client'
	group by eos_user_id,enquiry_id;/* We are computing cases with with completed mre orders, for this purpose we have computed all the cases from component */
    
        
 	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(case when type='normal' then type end ) as percent_paid_mre from mre  where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id ) B
	set A.percent_paid_mre_2016_2017=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id; /* percent of paid_mre*/
    
    update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(case when type='normal' then type end ) as percent_valid_mre from mre  where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id ) B
	set A.percent_valid_mre_2016_2017=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id; /* percent of valid_mre*/

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(case when type='normal' then type end ) as percent_quality_reedit from mre  where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id ) B
	set A.percent_quality_reedit_2016_2017=B.percent_quality_reedit 
	where A.eos_user_id=B.eos_user_id;	/* percent of quality-re_edit */
	
	
	########################  year_on_year MVC base
	
	/* selecting year on year MVC for the valid MVC base */
	
	alter table SVOC add column 2013_14_base varchar(2) default 'N';
	
	update SVOC
	set 2013_14_base='Y'
	where eos_user_id in (select distinct eos_user_id  from Cust_txns where transact_date between '2013-04-01' and '2014-03-31');
	
	alter table SVOC add column 2013_14_MVC_base varchar(2);
	alter table SVOC add column 2014_15_MVC_base varchar(2);
	alter table SVOC add column 2015_16_MVC_base varchar(2);
	alter table SVOC add column 2016_17_MVC_base varchar(2);
	alter table SVOC add column 2017_18_MVC_base varchar(2);
	alter table SVOC add column 2018_19_MVC_base varchar(2);

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2013-04-01' and '2014-03-31' group by eos_user_id) B
	set A.2013_14_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2014-04-01' and '2015-03-31' group by eos_user_id) B
	set A.2014_15_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2015-04-01' and '2016-03-31' group by eos_user_id) B
	set A.2015_16_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2016-04-01' and '2017-03-31' group by eos_user_id) B
	set A.2016_17_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2017-04-01' and '2018-03-31' group by eos_user_id) B
	set A.2017_18_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2018-04-01' and '2019-03-31' group by eos_user_id) B
	set A.2018_19_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';
	
	###########################  2017_2018 ##########################
	
	/* computing variables for the time period 2017-2018*/
	
	alter table SVOC add column percent_not_acceptable_cases_2017_2018 float(2);
	alter table SVOC add column percent_acceptable_cases_2017_2018 double;
	alter table SVOC add column percent_not_rated_cases_2017_2018 double;
	alter table SVOC add column percent_outstanding_cases_2017_2018 double;
	alter table SVOC add column percent_discount_cases_2017_2018 double;
	alter table SVOC add column percent_delay_cases_2017_2018 double;
	alter table SVOC add column Range_of_services_2017_2018 int(5);
	alter table SVOC add column Range_of_subjects_2017_2018 int(5);
	alter table SVOC add column Average_word_count_2017_2018 int(5);
	alter table SVOC add column Average_Delay_2017_2018 int(5);
	alter table SVOC add column Favourite_Week_number_2017_2018 varchar(2);
	alter table SVOC add column Favourite_Month_2017_2018 varchar(2);
	alter table SVOC add column Favourite_Time_2017_2018 varchar(4);
	alter table SVOC add column Favourite_Day_Week_2017_2018 varchar(2);
	alter table SVOC add column maximum_rating_2017_2018 varchar(20);



	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2017_2018=B.rate
	where A.eos_user_id=B.eos_user_id;


	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_acceptable_cases_2017_2018 =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_not_rated_cases_2017_2018=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_outstanding_cases_2017_2018=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_discount_cases_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_delay_cases_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.Range_of_services_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.Range_of_subjects_2017_2018= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.Average_word_count_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.Average_Delay_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;


	UPDATE IGNORE
				SVOC A
			SET Favourite_Week_number_2017_2018=(
	SELECT 
							Week_number
						FROM (select eos_user_id,Week_number,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Week_number order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id 
						ORDER BY ratings desc,sum desc
						LIMIT 1) 
						where Sept_2018='Y';
	UPDATE IGNORE
				SVOC A
			SET Favourite_Month_2017_2018=(
	SELECT 
							Favourite_Month
						FROM (select eos_user_id,Favourite_Month,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Favourite_Month order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
	UPDATE IGNORE
				SVOC A
			SET Favourite_Day_Week_2017_2018=(
	SELECT 
							Favourite_Day_Week
						FROM (select eos_user_id,Favourite_Day_Week,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Favourite_Day_Week order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
						
	 UPDATE IGNORE
				SVOC A
			SET Favourite_Time_2017_2018=(
	SELECT 
							Favourite_Time
						FROM (select eos_user_id,Favourite_Time,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Favourite_Time order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);


		UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2017_2018 = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

				
	
	alter table SVOC
	add column percent_offer_cases_2017_2018 int(8);

	update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.percent_offer_cases_2017_2018=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;
	
	
	alter table SVOC 
	add column percent_paid_mre_2017_2018  double,
	add column percent_valid_mre_2017_2018  double,
	add column percent_quality_reedit_2017_2018  double;

	
	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client'
	group by eos_user_id,enquiry_id;
    
        
 	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(*) as percent_paid_mre from mre  where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id ) B
	set A.percent_paid_mre_2017_2018=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id;
    
    update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(*) as percent_valid_mre from mre  where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id ) B
	set A.percent_valid_mre_2017_2018=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(*) as percent_quality_reedit from mre  where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id ) B
	set A.percent_quality_reedit_2017_2018=B.percent_quality_reedit 
	where A.eos_user_id=B.eos_user_id;	
	
	/* Number of times customer has rated in the time period 2017-2018 (Aug-Aug time period) */
	
	alter table SVOC add column 
	Number_of_times_rated_2017_2018 int(5);
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set Number_of_times_rated_2017_2018=rate_count
	where A.eos_user_id=B.eos_user_id;
	
	/* is_delay is the indicator variable for marking whether the customer has experienced any delay in the time period 2017-2018 (Aug-Aug time period) */
	
	alter table SVOC add column is_delay_2017_2018 varchar(2);
	
	update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') B
	set is_delay_2017_2018='Y'
	where Average_Delay_2017_2018 >0  and Average_Delay_2017_2018 is not null and A.eos_user_id=B.eos_user_id;
	
	
	/*
	ALTER TABLE SVOC
	add column Avg_perc_chrgd_mre double;
	
	UPDATE SVOC X,
	(SELECT A.eos_user_id, A.tot_mre_cost / B.tot_price as Avg_perc_chrgd_mre
	FROM
	(SELECT eos_user_id, sum(price_after_tax*paid_mre_percent_to_total) as tot_mre_cost FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null
	GROUP BY eos_user_id) A , 
	(SELECT eos_user_id, sum(price_after_tax) as tot_price FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null
	GROUP BY eos_user_id) B
	WHERE A.eos_user_id = B.eos_user_id) C
	set X.Avg_perc_chrgd_mre = C.Avg_perc_chrgd_mre
	WHERE X.eos_user_id = C.eos_user_id;
		#########################
	
	ALTER TABLE SVOC
	add column Avg_perc_chrgd_mre_2017_2018 double,

	UPDATE SVOC X,
	(SELECT A.eos_user_id, A.tot_mre_cost / B.tot_price as Avg_perc_chrgd_mre
	FROM
	(SELECT eos_user_id, sum(price_after_tax*paid_mre_percent_to_total) as tot_mre_cost FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null and transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) A , 
	(SELECT eos_user_id, sum(price_after_tax) as tot_price FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null and transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	WHERE A.eos_user_id = B.eos_user_id) C
	set X.Avg_perc_chrgd_mre_2017_2018 = C.Avg_perc_chrgd_mre
	WHERE X.eos_user_id = C.eos_user_id;
		*/

	#################    Favourite Service   ####################
	/* Favourite serivce is used for Marking most frequent service_id for the customer from the time period 2017-2018 (Aug-Aug cycle) */
	

	alter table SVOC add column Favourite_service_2017_2018 varchar(20);
	 UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service_2017_2018=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		
	/* Favourite serivce segment is used for Marking most frequent service segment for the customer from the time period 2017-2018 (Aug-Aug cycle) */
	
	alter table SVOC
	add column Favourite_service_segment_2017_2018 int(5);

	alter table service
	add index(id);
				
	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment_2017_2018=B.service_segment
	where A.Favourite_service_2017_2018=B.id;	
    

	##### 
	
	/* Number of revisions in our selected parameters in the time period 2017-2018 (Aug-Aug cycle) */

	ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area_2017_2018 int,
	add column No_of_Revision_in_price_after_tax_2017_2018 int,
	add column No_of_Revision_in_service_id_2017_2018 int,
	add column No_of_Revision_in_delivery_date_2017_2018 int,
	add column No_of_Revision_in_words_2017_2018 int;


	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area_2017_2018 = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax_2017_2018 = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id_2017_2018 = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date_2017_2018 = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	where c
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words_2017_2018 = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;

	
	/* 
	
	Favourite_subject_2017_2018 - Identifying the most frequent subject_area_id in the time period 2017_2018 \
	Favourite_SA1_6_name_2017_2018 - Identifying the most frequent SA 1.6 subject area in the time period 2017_2018
	Favourite_SA1_5_name_2017_2018 - Identifying the most frequent SA 1.5 subject area in the time period 2017_2018
	Favourite_SA1_name_2017_2018 - Identifying the most frequent SA 1 subject area in the time period 2017_2018
	
	*/
	
	alter table SVOC
	add column Favourite_subject_2017_2018 int(11),
	add column Favourite_SA1_name_2017_2018 varchar(100) ,
	add column Favourite_SA1_5_name_2017_2018 varchar(100),
	add column Favourite_SA1_6_name_2017_2018 varchar(100);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2017_2018 = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2017_2018 =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2017_2018 =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2017_2018 =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);
					
			
	
	
	###########################   2015_2016 #########################
	
	/* computing variables for the time period 2015-2016 for modelling purposes */
	
	alter table SVOC add column percent_not_acceptable_cases_2015_2016_year float(2);
	alter table SVOC add column percent_acceptable_cases_2015_2016_year double;
	alter table SVOC add column percent_not_rated_cases_2015_2016_year double;
	alter table SVOC add column percent_outstanding_cases_2015_2016_year double;
	alter table SVOC add column percent_discount_cases_2015_2016_year double;
	alter table SVOC add column percent_delay_cases_2015_2016_year double;
	alter table SVOC add column Range_of_services_2015_2016_year int(5);
	alter table SVOC add column Range_of_subjects_2015_2016_year int(5);
	alter table SVOC add column Average_word_count_2015_2016_year int(5);
	alter table SVOC add column Average_Delay_2015_2016_year int(5);
	alter table SVOC add column Favourite_Month_2015_2016_year varchar(2);
	alter table SVOC add column Favourite_Time_2015_2016_year varchar(4);
	alter table SVOC add column Favourite_Day_Week_2015_2016_year varchar(2);
	alter table SVOC add column Week_number_2015_2016_year varchar(2);
	alter table SVOC add column maximum_rating_2015_2016_year varchar(20);
	alter TABLE SVOC add column Ever_rated_2015_2016 varchar(2) default 'N';

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
		where rate is not null AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
		GROUP BY eos_user_id) B
		set Ever_rated_2015_2016 = 'Y' 
		WHERE A.eos_user_id = B.eos_user_id;

	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2015_2016_year=B.rate
	where A.eos_user_id=B.eos_user_id;



	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_acceptable_cases_2015_2016_year =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_not_rated_cases_2015_2016_year=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_outstanding_cases_2015_2016_year=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_discount_cases_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_delay_cases_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Range_of_services_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Range_of_subjects_2015_2016_year= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Average_word_count_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.Average_Delay_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(MONTH FROM created_date)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Favourite_Month_2015_2016_year=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(HOUR FROM created_date)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Favourite_Time_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(DAYOFWEEK(created_date)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Favourite_Day_Week_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX((FLOOR((DAYOFMONTH(created_date) - 1) / 7) + 1)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Week_number_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;



	UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2015_2016_year = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
				);

		
	/* percentage of cases where coupon_code was applied in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	alter table SVOC
	add column percent_offer_cases_2015_2016_year int(8);

	update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.percent_offer_cases_2015_2016_year=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;
	
	/* indicator variable for tagging whether has rated in outstanding, not acceptable or acceptable in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	ALTER TABLE SVOC
	add column Ever_rated_outstanding_2015_2016 varchar(2) default 'N',
	add column Ever_rated_acceptable_2015_2016 varchar(2) default 'N',
	add column Ever_rated_not_acceptable_2015_2016 varchar(2) default 'N';


	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'outstanding' AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_outstanding_2015_2016 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'acceptable' AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_acceptable_2015_2016 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'not-acceptable' AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_not_acceptable_2015_2016 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;


	describe SVOC;

	# Is subject_area_id in top Subject Areas.
	
	/*
	Is_in_top_sub_Area is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1 is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	*/
	
	
	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1 varchar(2) default 'N';

	UPDATE Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	UPDATE Cust_txns
	SET Is_in_top_sub_Area_1 = 'Y'
	WHERE subject_area_id IN 
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282,	84,	1279,	310,	85,	1348,	1566,	378,	1532,	339,	533,	199,	1475,	204,	1171,	1355,	159,	297,	478,	563,	795,	1228,	1238,	1210,	1290,	111,	460,	532,	1481,	419,	357,	658,	170,	251,	518,	537,	720,	875,	1143,	1266,	1568,	1560,	667,	1112,	1540,	1437,	637,	772,	1047,	1189,	102,	1116,	1544,	129,	329,	1359,	752,	262,	588,	91,	761,	1124,	98,	217,	629,	1138,	1569,	130,	530,	541,	669,	758,	1037,	1058,	1174,	1179,	1245,	184,	1356,	1402,	328,	1358,	435,	1497,	1505,	1105,	302,	1403,	670,	806,	2070,	387,	58,	439,	249,	4,	65,	295,	458,	663,	1102,	352,	781,	366,	92,	471,	1526,	807,	1517,	1098,	135,	14,	1048,	1012,	1193,	108,	466,	890,	969,	255,	1398,	1559,	35,	1154,	190,	133,	1382,	574,	1534,	416,	1381,	1523,	311,	117,	31,	1323,	1527,	422,	40,	462,	1404,	162,	769,	373,	565,	314,	425,	576,	332,	1313,	143,	367,	428,	292,	16,	105,	153,	745,	1278,	1324,	48,	1487,	43,	124,	126,	70,	305,	327,	544,	551,	570,	594,	741,	940,	1468,	152,	298,	564,	639,	704,	1473,	1528,	389,	493,	542,	620,	650,	676,	679,	684,	701,	708,	728,	750,	778,	810,	862,	876,	880,	897,	901,	945,	961,	966,	990,	1011,	1022,	1057,	1104,	1239,	1390,	1451,	1457,	1495,	1507,	2073,	2077,	738,	1107,	88,	557,	578,	1181,	324,	140,	753,	151,	464,	1365,	1201,	1430,	1194,	21,	1482,	1097,	1114,	1492,	202,	403,	1454,	323,	1552,	1545,	763,	294,	755,	923,	1525,	1529,	1197,	188,	1281,	1334,	286,	1184,	110,	1561,	412,	1263,	1408,	1417,	322,	115,	107,	1087,	104,	429,	671,	8,	380,	121,	242,	1300,	662,	1297,	1399,	257,	163,	413,	1090,	721,	802,	1214,	469,	1187,	193,	749,	1352,	1081,	1434,	1548,	800,	1208,	178,	183,	2078,	349,	227,	1518,	371,	142,	259,	472,	96,	1117,	1431,	67,	567,	924,	1059,	1196,	71,	1510,	1294,	34,	39,	348,	1,	291,	33,	1302,	1145,	1200,	1384,	446,	1480,	572,	274,	410,	106,	38,	239,	734,	321,	167,	277,	1409,	1385,	1109,	224,	1555,	441,	1306,	390,	1280,	1508,	1537,	264,	463,	938,	1346,	99,	245,	317,	447,	968,	992,	993,	995,	1042,	1226,	1310,	1450,	1485,	1113,	571,	331,	394,	395,	1303,	377,	225,	50,	1415,	631,	1494,	150,	269,	341,	1299,	1531,	95,	94,	128,	1488,	1068,	271,	198,	37,	1307,	125,	796,	1186,	5,	100,	330,	1530,	1277,	144,	602,	626,	997,	206,	459,	485,	989,	1261,	1341,	1574,	360,	1301,	1198,	46,	63,	579,	293,	586,	432,	375,	381,	430,	1026,	248,	97,	1285,	231,	437,	455,	633,	664,	1028,	1106,	103,	398,	1372,	253,	1360,	756,	768,	1270,	1367,	1501,	112,	468,	771,	344,	568,	1576,	1484,	287,	53,	18,	189,	118,	1202,	1206,	1550,	177,	1249,	407,	408,	114,	345,	941,	1096,	1188,	243,	270,	241,	234,	51,	361,	1308,	12,	374,	62,	307,	219);

	/*
				computing top subject area for the time period 2015-2016 (Aug-Aug Cycle)
		
	Is_in_top_sub_Area_2015_2016 is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1_2015_2016 is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	
	
	*/
	
	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2015_2016 varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_2015_2016 varchar(2) default 'N';


	UPDATE SVOC  
	SET Is_in_top_sub_Area_2015_2016 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area = 'Y' and transact_date BETWEEN '2015-08-29' AND '2016-08-28');

	UPDATE SVOC  
	SET Is_in_top_sub_Area_1_2015_2016 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_1 = 'Y' and transact_date BETWEEN '2015-08-29' AND '2016-08-28');
	
	/* Vintage is the number of days from the FTD of the customer till the last date of the observational time period, it is used to measure the number of days customer was active in the system

	New_or_existing_in_2015_2016 is an indicator variable for measuring whether customer transacted in time period 2015-08-29 AND 2016-08-28
	
	*/
	
	# Vintage(From 2016-08-28) and New or existing in (2015-16)

	ALTER TABLE SVOC
	add column Vintage_2015_2016 int,
	add column New_or_existing_in_2015_2016 varchar(10) ;

	UPDATE SVOC
	set Vintage_2015_2016 = TIMESTAMPdiff(MONTH, FTD, '2016-08-28'),
	New_or_existing_in_2015_2016 = CASE WHEN FTD BETWEEN '2015-08-29' AND '2016-08-28' THEN 'new' ELSE 'existing' END;

	describe SVOC;

	/* Obtaining number of paid-mre, valid mre and quality re-edit for the period 2015-2016 */
	
	# Number of paid-mre, valid-mre, qualityre-edit in 2015-2016
		
	drop table mre;
	create temporary table mre as
	select eos_user_id,enquiry_id,left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client' and price_after_tax is not null and price_after_tax > 0 
	group by eos_user_id,enquiry_id;

	ALTER TABLE SVOC
	ADD Column No_of_paid_mre_in_2015_2016 int default 0,
	ADD Column No_of_valid_mre_in_2015_2016 int default 0,
	ADD Column No_of_quality_reedit_mre_in_2015_2016 int default 0;


	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='paid-mre' and transact_date BETWEEN '2015-08-29' AND '2016-08-28'  GROUP BY eos_user_id) B
	set A.No_of_paid_mre_in_2015_2016 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='valid-mre' and transact_date BETWEEN '2015-08-29' AND '2016-08-28' GROUP BY eos_user_id) B
	set A.No_of_valid_mre_in_2015_2016 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='quality-re_edit' and transact_date BETWEEN '2015-08-29' AND '2016-08-28' GROUP BY eos_user_id) B
	set A.No_of_quality_reedit_mre_in_2015_2016 = B.count
	where A.eos_user_id = B.eos_user_id;

	/* Obtaining ratio of paid-mre, valid-mre and quality re-edit for the period 2015-2016 */
	
	ALTER TABLE SVOC
	ADD Column Ratio_paid_mre_to_total_orders_2015_2016 double,
	ADD Column Ratio_valid_mre_to_total_orders_2015_2016 double,
	ADD Column Ratio_quality_re_edit_mre_to_total_orders_2015_2016 double;

	update SVOC 
	set Ratio_paid_mre_to_total_orders_2015_2016 =null,
	Ratio_valid_mre_to_total_orders_2015_2016 =null,Ratio_quality_re_edit_mre_to_total_orders_2015_2016=null;

	UPDATE SVOC
	SET Ratio_paid_mre_to_total_orders_2015_2016 = No_of_paid_mre_in_2015_2016 / frequency_2015_2016_year,
	Ratio_valid_mre_to_total_orders_2015_2016 = No_of_valid_mre_in_2015_2016 / frequency_2015_2016_year,
	Ratio_quality_re_edit_mre_to_total_orders_2015_2016 = No_of_quality_reedit_mre_in_2015_2016 / frequency_2015_2016_year;
	
	###########################
	
	/* 
	Favourite subject area id in time period 2015-2016 
	Favourite SA 1 in time period 2015-2016 
	Favourite SA 1.6 in time period 2015-2016 
	*/
	
	ALTER TABLE SVOC
	ADD COLUMN Favourite_subject_2015_2016 int(11) ,
	ADD COLUMN Favourite_SA1_name_2015_2016 varchar(100),
	ADD COLUMN Favourite_SA1_5_name_2015_2016 varchar(100),
	ADD COLUMN Favourite_SA1_6_name_2015_2016 varchar(100);

	select Favourite_SA1_name_2015_2016 FROM SVOC;


	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2015_2016 = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2015_2016 =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

    UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2015_2016 =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		
	 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2015_2016 =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);
	
	


	############################  For calculating MVC from sent_to_client_date ########
	/*  First send to client date  */
	
	ALTER TABLE SVOC
	add column STC_date date,
	add column one_yr_from_STC_date date,
	add column one_yr_Frq_from_STC_date int;

	UPDATE SVOC A, Cust_txns B
	set A.STC_date = left(B.sent_to_client_date, 10)
	where A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;

	update SVOC
	set one_yr_from_STC_date = DATE_ADD(STC_date, INTERVAL 1 Year); 
	
	/* Two years since FTD calculated for each customer */
		
	ALTER TABLE SVOC
	ADD COLUMN two_yrs_from_FTD date;

	update SVOC
	set two_yrs_from_FTD = DATE_ADD(FTD, INTERVAL 2 Year); 

	alter table SVOC 
	add column two_yrs_Frq_from_FTD int;

	update SVOC A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq from Cust_txns A,SVOC B
	where transact_date between FTD and two_yrs_from_FTD and A.eos_user_id=B.eos_user_id 
	group by A.eos_user_id) C
	set A.two_yrs_Frq_from_FTD=C.freq
	where A.eos_user_id=C.eos_user_id;


	alter table SVOC 
	add column two_yrs_MVC varchar(2);

	update SVOC
	set two_yrs_MVC=
	case when two_yrs_Frq_from_FTD >= 3 then '1' else '0' end;

	/* Computing frequency for all the customers from first send to client date */
	
	update SVOC A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq from Cust_txns A, SVOC B
	where transact_date between STC_date and one_yr_from_STC_date and A.eos_user_id=B.eos_user_id 
	group by A.eos_user_id) C
	set A.one_yr_Frq_from_STC_date=C.freq
	where A.eos_user_id=C.eos_user_id;

	alter table SVOC 
	add column one_yr_MVC_from_STC_date varchar(2);

	update SVOC
	set one_yr_MVC_from_STC_date=
	case when one_yr_Frq_from_STC_date >= 3 then '1' else '0' end;
	
	/* Computing frequency for all the customers from first transact date*/
	
	alter table SVOC add column 1_yr_from_FTD date;

	update SVOC
	set 1_yr_from_FTD=DATE_ADD(FTD, INTERVAL 1 Year); 

	alter table SVOC add column 1_yr_Frq_from_FTD int;
	/*
	update SVOC A,(select eos_user_id,transact_date,enquiry_id from Cust_txns) B
	set */

	update SVOC A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq from Cust_txns A,SVOC B
	where transact_date between FTD and 1_yr_from_FTD and A.eos_user_id=B.eos_user_id 
	group by A.eos_user_id) C
	set A.1_yr_Frq_from_FTD=C.freq
	where A.eos_user_id=C.eos_user_id;


	alter table SVOC add column 1_yr_MVC varchar(2);

	update SVOC
	set 1_yr_MVC=
	case when 1_yr_Frq_from_FTD>=3 then '1' else '0' end ;

	############### Actual Time for Job Completion #############

	/* Actual time for job completion is the difference between send-to-client-date and confirmed_date */
	
	ALTER TABLE SVOC
	ADD Column First_Act_Time_for_job_Completion int;

	UPDATE SVOC A, Cust_txns B
	set A.First_Act_Time_for_job_Completion = B.Act_Time_for_job_Completion
	WHERE A.eos_user_id = B.eos_user_id AND A.STC_date = left(B.sent_to_client_date,10);

	/* Is_Univ_in_top_Univ is a indicator variable to define whether customer belongs to the university which is most frequent among the MVCs */
	
	ALTER TABLE SVOC
	ADD column Is_Univ_in_top_Univ varchar(2) default 'N';

	SET SQL_SAFE_UPDATES = 0;
	UPDATE SVOC
	set Is_Univ_in_top_Univ = 'Y'
	WHERE University_name in ('The University of Tokyo',
	'Seoul National University',
	'Waseda University',
	'Kyoto University',
	'Yonsei University',
	'Osaka University',
	'University of Tsukuba',
	'Tohoku University',
	'Korea University',
	'Kyushu University',
	'Nagoya University',
	'Keio University',
	'Hanyang University',
	'Hiroshima University',
	'Tokyo Medical and Dental University',
	'Hokkaido University',
	'Seoul National University Hospital');

	/* 
	
	First_translator_in_top_translator is an indicator variable for each customer whether the customer was assigned a top translator for the first transaction 
	top translators are identified by taking cumulative distribution for MVC customers, and then selecting the top decile as a top translator
	
	*/
	
	ALTER TABLE SVOC
	add Column First_translator_in_top_translator varchar(2);

	UPDATE SVOC
	set First_translator_in_top_translator = 'N'
	WHERE First_trnx_Translator IS NOT NULL;

	UPDATE SVOC
	set First_translator_in_top_translator = 'Y'
	WHERE First_trnx_Translator IN (1007,1009,1019,102,1026,1036,1052,1053,1056,1060,1065,1078,1079,1084,1086,109,1092,1093,1110,1111,1112,1127,1133,1134,1138,1148,1149,1162,	117,	1176,	1183,	1188,	1189,	1191,	1215,	1220,	1227,	1243,	1247,	1248,	1255,	1256,	1257,	1261,	1270,	1286,	1299,	1310,	1336,	135,	1350,	1352,	136,	1360,	1365,	1367,	1368,	1369,	1384,	1389,	14,	1401,	1407,	1418,	1422,	1438,	1446,	1453,	1454,	1470,	1475,	1500,	1504,	1509,	1513,	1516,	1519,	1542,	1553,	1557,	1563,	1566,	1568,	1570,	1581,	1611,	162,	1652,	1658,	1660,	1661,	1667,	1674,	1681,	1682,	1684,	1685,	1688,	1703,	1712,	1713,	1729,	1747,	1757,	1765,	1766,	1775,	1776,	1783,	1785,	1806,	1808,	1811,	1813,	1816,	1818,	182,	1822,	1824,	1827,	1829,	1830,	1835,	1837,	1840,	185,	1853,	1854,	186,	1862,	187,	1878,	1879,	188,	1885,	1886,	1889,	1898,	190,	1916,	1922,	1926,	1945,	1953,	197,	1977,	1978,	1981,	1989,	1991,	1992,	1996,	2001,	2005,	2008,	2015,	2030,	2066,	2067,	2076,	2099,	2108,	2129,	2137,	214,	2143,	2160,	2170,	2177,	2181,	2184,	2186,	219,	2197,	2204,	2207,	2209,	2213,	2220,	224,	2246,	2250,	2272,	2288,	2302,	2313,	2317,	2321,	2325,	2328,	2329,	2354,	2355,	2360,	2391,	2392,	2395,	2396,	2400,	2410,	2411,	2413,	2426,	2449,	2450,	2457,	2463,	2469,	2481,	2490,	2492,	2495,	2500,	2512,	2517,	2524,	2525,	2527,	2531,	2536,	2546,	2557,	256,	2562,	2568,	257,	2570,	2576,	2595,	2597,	260,	2600,	2605,	2614,	2617,	2619,	2621,	2631,	2635,	2642,	2658,	2660,	2663,	2677,	2682,	2688,	2690,	2695,	2699,	2700,	2702,	2711,	2716,	2725,	2735,	2737,	2741,	2742,	2749,	2750,	2751,	2756,	2760,	2762,	2771,	2773,	2780,	2782,	2783,	2785,	2793,	2797,	2803,	2805,	2809,	2811,	2813,	2819,	2821,	2828,	2833,	2836,	2840,	2842,	2843,	2844,	2847,	2848,	2857,	2858,	2872,	2874,	2876,	2881,	2885,	2887,	2893,	2897,	2901,	2906,	2910,	2913,	2915,	2922,	2929,	2931,	2935,	2938,	2943,	2944,	2949,	2950,	2951,	2952,	2955,	2956,	2958,	2964,	2966,	2973,	2975,	2979,	2980,	2987,	2992,	3000,	3001,	3004,	3005,	3006,	301,	3012,	3019,	3023,	3025,	3029,	3030,	3031,	3037,	3038,	3039,	3043,	3046,	3050,	3054,	3055,	3059,	3060,	3061,	3066,	3067,	3072,	3075,	3077,	308,	3080,	3086,	3087,	309,	3090,	3091,	3093,	3096,	3097,	3098,	3099,	310,	3101,	3102,	3103,	3104,	3106,	3107,	3108,	311,	3110,	3111,	3112,	3113,	3115,	3123,	3132,	3133,	3139,	3141,	3142,	3144,	3145,	3146,	315,	3153,	3155,	3157,	3159,	316,	3161,	3164,	3166,	3167,	3168,	3170,	3172,	3173,	3176,	3177,	3180,	3182,	3185,	3189,	319,	3190,	3191,	3194,	3198,	3199,	320,	3201,	3202,	3208,	321,	3211,	3212,	3218,	3219,	3220,	3222,	3227,	3230,	3231,	3235,	3239,	3246,	3248,	3249,	3251,	3254,	3258,	3259,	3261,	3264,	3265,	3267,	3278,	3279,	328,	3282,	3286,	3289,	3290,	3291,	3292,	3296,	3297,	3302,	3307,	3309,	3312,	3316,	3321,	3322,	3325,	3327,	3328,	3329,	3336,	3337,	3339,	334,	3340,	3343,	3348,	3354,	3355,	3371,	3375,	3379,	338,	3384,	339,	3390,	3391,	3393,	3396,	3406,	3408,	3409,	3410,	3413,	3414,	3415,	3416,	3420,	3428,	3432,	3436,	3439,	3441,	3446,	3448,	3453,	3454,	3457,	3458,	3460,	3463,	3464,	3466,	3467,	3471,	3474,	3476,	3478,	3480,	3482,	3483,	3491,	3492,	3499,	3500,	3501,	3508,	3510,	3512,	3514,	3516,	3518,	3522,	3526,	3531,	3532,	3533,	3535,	3545,	3546,	3549,	3553,	3554,	3555,	3556,	3559,	3560,	3561,	3574,	3578,	3579,	3585,	3586,	3588,	3589,	3592,	3595,	3603,	3605,	3606,	3607,	3608,	3610,	3611,	3612,	3613,	3616,	3617,	3619,	362,	3622,	3631,	3634,	3636,	3637,	3638,	3640,	3641,	3643,	3645,	3648,	3651,	3652,	3653,	3654,	3655,	3656,	3657,	3659,	366,	3662,	3664,	3665,	3669,	3676,	3678,	3679,	3685,	3687,	3690,	3692,	3694,	3696,	3697,	3700,	3703,	3706,	3707,	3709,	3716,	3717,	3719,	3720,	3723,	3727,	3728,	373,	3730,	3732,	3745,	3748,	3749,	3751,	3760,	3761,	3762,	3764,	3767,	3768,	3770,	3779,	3780,	3781,	3784,	3785,	3786,	3789,	3790,	3791,	3793,	3796,	3797,	3806,	381,	3811,	3812,	3817,	3819,	3830,	3831,	3834,	3835,	3836,	3837,	3839,	3840,	3844,	3845,	3846,	3852,	3854,	3859,	3863,	3865,	3867,	3869,	3870,	3871,	3872,	3875,	3878,	3883,	3889,	3894,	3896,	3900,	3902,	3903,	3905,	3907,	3916,	3920,	3924,	3928,	3930,	3931,	3933,	3934,	3935,	3936,	3939,	3944,	3950,	3951,	3954,	3955,	3959,	3960,	3963,	3964,	3970,	3972,	3974,	3976,	3979,	3984,	3986,	3990,	3995,	3996,	4001,	4002,	4003,	4006,	4008,	4013,	4015,	4017,	4019,	4023,	4024,	4026,	4028,	403,	4030,	4034,	4035,	4036,	4037,	4039,	404,	4046,	4050,	4052,	4053,	4054,	4056,	4059,	406,	4061,	4062,	4065,	4066,	4069,	4070,	4074,	4078,	4079,	4080,	4081,	4088,	4095,	4099,	4100,	4104,	4107,	4111,	4115,	4118,	4119,	4123,	4129,	4131,	4133,	4136,	4139,	4142,	4146,	4148,	4151,	4152,	4154,	4155,	4158,	4161,	4164,	4166,	417,	4176,	4179,	4185,	4189,	419,	4198,	420,	4201,	4202,	421,	4211,	4213,	4215,	4221,	4226,	4229,	4231,	4232,	4234,	4237,	4241,	4245,	4246,	4248,	425,	4251,	4254,	4257,	4259,	4260,	4263,	4268,	4271,	4272,	4278,	4288,	4290,	4303,	4305,	4316,	4318,	4319,	4320,	4321,	4323,	4324,	4326,	4328,	433,	4332,	4334,	4336,	4338,	4340,	4341,	4344,	4345,	4346,	4358,	4364,	4366,	4369,	437,	4371,	4375,	4380,	4385,	4392,	4393,	4396,	44,	440,	4400,	4401,	4404,	4405,	4409,	4422,	4425,	4427,	443,	4434,	4437,	4441,	4443,	4445,	4460,	4464,	4470,	4477,	4490,	4492,	4493,	4494,	4496,	4499,	4500,	4503,	4504,	4511,	4514,	4519,	452,	4523,	4530,	4541,	4549,	4550,	4552,	4554,	4556,	4559,	4569,	4572,	4574,	4576,	4577,	4579,	4584,	4601,	4614,	4616,	4621,	4624,	4626,	4629,	4641,	4643,	4649,	465,	4658,	4659,	4662,	4665,	4675,	4678,	4682,	4686,	4688,	4689,	4693,	4694,	4697,	4700,	4701,	4703,	4704,	4716,	4717,	4723,	4724,	4732,	4733,	4735,	4741,	4748,	475,	4754,	4755,	4760,	4770,	4771,	4773,	4774,	4779,	4793,	4795,	4806,	4817,	4818,	4821,	4825,	4828,	4833,	4835,	4839,	4844,	4845,	4850,	4853,	486,	4863,	4870,	4873,	4874,	4876,	4877,	4886,	4889,	4894,	4895,	4896,	4897,	4898,	4899,	490,	4900,	4901,	4903,	4906,	491,	4911,	4916,	492,	4924,	4925,	4928,	493,	4930,	4934,	4937,	494,	4941,	4957,	4968,	4974,	4984,	4988,	4989,	4992,	4997,	5000,	5004,	5008,	5009,	5011,	5012,	5015,	5016,	5019,	5024,	5040,	5043,	5045,	5046,	5048,	5051,	5053,	5055,	5056,	5059,	506,	5062,	5066,	5069,	5080,	5081,	509,	5099,	5104,	5108,	511,	5114,	5116,	5122,	5128,	5136,	5147,	5151,	5152,	516,	5165,	5166,	5167,	5169,	5197,	520,	5204,	5206,	5208,	521,	5210,	5216,	5225,	523,	5230,	5240,	5246,	5250,	5255,	5256,	5259,	526,	527,	5271,	5275,	5289,	5295,	5296,	5297,	5303,	5309,	5315,	5322,	5325,	533,	5337,	5341,	5348,	5383,	5386,	5389,	5393,	5394,	5398,	5407,	541,	5416,	5420,	5422,	5437,	5445,	5446,	5451,	5460,	5469,	5479,	5495,	5513,	5516,	5538,	554,	5540,	5543,	5544,	5548,	5551,	5558,	556,	5563,	5566,	5582,	5586,	5593,	5599,	5602,	561,	5632,	5645,	5647,	5655,	566,	5665,	5673,	5678,	5681,	569,	5692,	5693,	5694,	5695,	570,	5716,	5723,	5725,	5728,	5760,	579,	5797,	584,	589,	590,	591,	592,	597,	604,	605,	606,	607,	609,	610,	615,	621,	633,	636,	640,	641,	651,	656,	657,	659,	660,	661,	665,	667,	678,	76,	81,	84,	8569,	8596,	927,	93,	930,	932,	943,	957,	9573,	972,	9720,	9752,	980,	989,	990,	997);
	
	
	

	
	####################      adding MRE variables   ##########################
	
	
	/* Percentage of the paid-mre, valid-mre and quality-re-edit cases in the time period 2015-2016 (Aug-Aug cycle)*/
	
	alter table SVOC 
	add column percent_paid_mre_2015_2016_year double,
	add column percent_valid_mre_2015_2016_year double,
	add column percent_quality_reedit_2015_2016_year double;

	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id 
	group by eos_user_id,enquiry_id;

	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(*) as percent_paid_mre from mre  where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id ) B
	set A.percent_paid_mre_2015_2016_year=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(*) as percent_valid_mre from mre  where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id ) B
	set A.percent_valid_mre_2015_2016_year=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(*) as percent_quality_reedit from mre  where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id ) B
	set A.percent_quality_reedit_2015_2016_year=B.percent_quality_reedit
	where A.eos_user_id=B.eos_user_id;	
	
	/* Number of times customer has given rating in the time period 2015-2016 (Aug-Aug cycle) */
	
	alter table SVOC 
	add column Number_of_times_rated_2015_2016_year int(5);
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set Number_of_times_rated_2015_2016_year=rate_count
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC add column is_delay_2015_2016_year varchar(2);
	
	update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') B
	set is_delay_2015_2016_year='Y'
	where Average_Delay_2015_2016_year >0  and Average_Delay_2015_2016_year is not null and A.eos_user_id=B.eos_user_id;

	
	
	#################    Favourite Service

	alter table SVOC
	add column Favourite_service_segment_2015_2016_year int(5);

	alter table SVOC
	add index(Favourite_service);

	alter table service
	add index(id);

	alter table SVOC add column Favourite_service_2015_2016_year varchar(20);
	 UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service_2015_2016_year=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment_2015_2016_year=B.service_segment
	where A.Favourite_service_2015_2016_year=B.id;	
	
	
	##############################################   creating set of variables for 2016-2017     #########################################
	
	
	
	##########################  
	
	/* marking MVCs from 2016_2017 */
	ALTER TABLE SVOC
	add column MVC_in_2016_2017 varchar(2);

	UPDATE SVOC
	set MVC_in_2016_2017 = 'Y'
	WHERE L2_Segment_new_2016_2017 = 1 or L2_Segment_new_2016_2017 = 2 
	or L2_Segment_new_2016_2017 = 4 or L2_Segment_new_2016_2017 = 5
	or L2_Segment_new_2016_2017 = 7;
	
	
	############## Calculating Ever MVCs #################
	ALTER TABLE SVOC
	ADD Column MVC_2003_2004 varchar(2) default 'N',
	ADD Column MVC_2004_2005 varchar(2) default 'N',
	ADD Column MVC_2005_2006 varchar(2) default 'N',
	ADD Column MVC_2006_2007 varchar(2) default 'N',
	ADD Column MVC_2007_2008 varchar(2) default 'N',
	ADD Column MVC_2008_2009 varchar(2) default 'N',
	ADD Column MVC_2009_2010 varchar(2) default 'N',
	ADD Column MVC_2010_2011 varchar(2) default 'N',
	ADD Column MVC_2011_2012 varchar(2) default 'N',
	ADD Column MVC_2012_2013 varchar(2) default 'N',
	ADD Column MVC_2013_2014 varchar(2) default 'N',
	ADD Column MVC_2014_2015 varchar(2) default 'N',
	ADD Column MVC_2015_2016 varchar(2) default 'N',
	ADD Column MVC_2016_2017 varchar(2) default 'N',
	ADD Column MVC_2017_2018 varchar(2) default 'N';

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2003-08-29' AND '2004-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2003_2004 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;


	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2004-08-29' AND '2005-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2004_2005 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2005-08-29' AND '2006-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2005_2006 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2006-08-29' AND '2007-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2006_2007 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2007-08-29' AND '2008-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2007_2008 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2008-08-29' AND '2009-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2008_2009 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2009-08-29' AND '2010-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2009_2010 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2010-08-29' AND '2011-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2010_2011 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2011-08-29' AND '2012-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2011_2012 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2012-08-29' AND '2013-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2012_2013 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2013-08-29' AND '2014-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2013_2014 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2014-08-29' AND '2015-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2014_2015 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2015_2016 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2016-08-29' AND '2017-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2016_2017 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2017-08-29' AND '2018-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2017_2018 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;


	ALTER TABLE SVOC
	ADD Column EVER_MVC varchar(2) default 'N';

	UPDATE SVOC
	SET EVER_MVC = 'Y'
	WHERE MVC_2003_2004 = 'Y' OR MVC_2004_2005 = 'Y' OR MVC_2005_2006 = 'Y' OR MVC_2006_2007 = 'Y' OR MVC_2007_2008 = 'Y' OR MVC_2008_2009 = 'Y' OR MVC_2009_2010 = 'Y' OR MVC_2010_2011 = 'Y' OR MVC_2011_2012 = 'Y' OR MVC_2012_2013 = 'Y' OR MVC_2013_2014 = 'Y' OR MVC_2014_2015 = 'Y' OR MVC_2015_2016 = 'Y' OR MVC_2016_2017 = 'Y' OR MVC_2017_2018 = 'Y';
		
	##########################  First Transaction variables   #########################
	
	/* computing derived variables for each customer */
	
	alter table SVOC add column First_unit_count int(10);
	alter table SVOC add column First_rate int(10);
	alter table SVOC add column First_subject_area_id int(10);
	alter table SVOC add column First_service_id int(10);
	alter table SVOC add column First_client_instruction_present varchar(2);
	alter table SVOC add column First_delivery_instruction_present varchar(2);
	alter table SVOC add column First_title_present varchar(2);
	alter table SVOC add column First_journal_name_present varchar(2);
	alter table SVOC add column First_use_ediatge_card varchar(2);
	alter table SVOC add column First_editage_card_id int(10);
	alter table SVOC add column First_author_name_present varchar(2);
	
	alter table SVOC add column First_unit_count int(5),
	add column First_rate varchar(15),
	add column First_subject_area_id int(10),
	add column First_service_id int(10);

	alter table SVOC add index(FTD),add index(eos_user_id);
	alter table Cust_txns add index(transact_date),add index(eos_user_id);

	Alter Table SVOC
	ADD Column First_txn_Rev_in_subject_area varchar(2),
	ADD Column First_txn_Rev_in_price_after_tax varchar(2),
	ADD Column First_txn_Rev_in_service_id varchar(2),
	ADD Column First_txn_Rev_in_delivery_date varchar(2),
	ADD Column First_txn_Rev_in_words varchar(2);

	UPDATE SVOC A, (SELECT eos_user_id, Revision_in_subject_area, Revision_in_price_after_tax, Revision_in_service_id, Revision_in_delivery_date, Revision_in_words FROM Cust_txns) B
	set A.First_txn_Rev_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A. eos_user_id = B.eos_user_id;

	
	set sql_safe_updates=0;
	Update SVOC A,(select eos_user_id,transact_date,unit_count,rate,subject_area_id,service_id from Cust_txns) B
	set 
	First_unit_count = unit_count,
	First_rate = rate,
	First_subject_area_id = subject_area_id,
	First_service_id = service_id
	where A.FTD=transact_date and A.eos_user_id=B.eos_user_id;
	
	update SVOC A,Cust_txns B
	set A.First_client_instruction_present='Y' 
	where A.FTD=B.transact_date and client_instruction is not null and client_instruction not like '%test%';


	update SVOC A,Cust_txns B
	set First_delivery_instruction_present='Y' 
	where A.FTD=B.transact_date and delivery_instruction is not null and delivery_instruction not like '%test%';

	update SVOC A,Cust_txns B
	set First_title_present='Y' 
	where A.FTD=B.transact_date and title is not null and title not like '%test%';


	update SVOC A,Cust_txns B
	set First_journal_name_present='Y' 
	where A.FTD=B.transact_date and journal_name is not null and journal_name not like '%test%';

	update SVOC A,Cust_txns B
	set First_use_ediatge_card=null'Y' 
	where A.FTD=B.transact_date and use_ediatge_card='Yes' and editage_card_id is not null and use_ediatge_card not like '%test%';

	update SVOC A,Cust_txns B
	set First_use_ediatge_card='Y' 
	where A.FTD=B.transact_date and use_ediatge_card='Yes' and use_ediatge_card not like '%test%';

	update SVOC A,Cust_txns B
	set First_author_name_present='Y' 
	where A.FTD=B.transact_date and author_name is not null and author_name not like '%test%';
	
	########################################################## First transaction variables #################################################################
	
	/* Customer received discount on first transaction or not ? */
	
    # Creating NEW Variables ##
	# 1. First Transaction Discount Recieved.
	ALTER TABLE SVOC add column First_txn_discount varchar(2);
	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,transact_date,discount from Cust_txns where discount >0 and discount is not null) B
	set A.First_txn_discount='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;


	/* Customer received Coupon_used on first transaction or not ? */
	
	# 2. First Transaction Coupon used.
	ALTER TABLE SVOC add column First_txn_Coupon_used varchar(2);
	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,transact_date, offer_code from Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;

	/* Customer received word_count on first transaction or not ? */
	
	# 3. First job wordcount
	ALTER TABLE SVOC drop column First_job_word_count;
	ALTER TABLE SVOC add column First_job_word_count int(10);
	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,transact_date, unit_count from Cust_txns) B
	set A.First_job_word_count =B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;
	
	/* Customer received NO_OFQUES on first transaction or not ? */
	
	# 4. First_NoOfQues
	
	ALTER TABLE SVOC add column First_NoOfQues Int;
	update SVOC A, (SELECT eos_user_id, transact_date, NoOfQuestions FROM Cust_txns) B
	set A.First_NoOfQues = B.NoOfQuestions
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;
	
	/* First translator of the customer */
	
	# 5. First Translator/editor
	ALTER TABLE SVOC 
	ADD Column First_trnx_Translator varchar(10);

	SET SQL_SAFE_UPDATES = 0;
	UPDATE SVOC A, (select eos_user_id, transact_date, wb_user_id FROM Cust_txns) B
	SET A.First_trnx_Translator = B.wb_user_id
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;

	# 6. First_trnx_Feedback
	ALTER TABLE SVOC 
	ADD Column First_trnx_Feedback varchar(15);

	SET SQL_SAFE_UPDATES = 0;
	UPDATE SVOC A, (select eos_user_id, transact_date, rate FROM Cust_txns) B
	SET A.First_trnx_Feedback = B.rate
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;
	
	/* indicator variable whether first transaction lead to paid_mre,valid_mre and quality-re_edit */
	
	/*
	First transaction detail variables 
	
	First_Txn_to_paid_mre - whether first transaction led to paid mre
	First_Txn_to_valid_mre - whether first transaction led to valid mre
	First_Txn_to_quality_reedit - whether first transaction led to quality re-edit
	First_Delay - Whether customer faced delay in the first transaction
	*/]
	
	alter table SVOC 
	add column First_Txn_to_paid_mre varchar(2),
	add column First_Txn_to_valid_mre varchar(2),
	add column First_Txn_to_quality_reedit varchar(2),
	add column First_Delay int(6);

	update SVOC A,(Select Delay,eos_user_id,min(Left(created_date,10)) as transact_date from Cust_txns group by Delay,eos_user_id) B
	set A.First_Delay=B.Delay 
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;


	update SVOC A, Cust_txns B
	set A.First_Txn_to_paid_mre = 'Y'
	where A.eos_user_id=B.eos_user_id AND A.FTD=B.transact_date AND B.Txn_to_paid_mre='Y';

	update SVOC A, Cust_txns B
	set A.First_Txn_to_valid_mre = 'Y'
	where A.eos_user_id=B.eos_user_id AND A.FTD=B.transact_date AND B.Txn_to_valid_mre='Y';

	update SVOC A, Cust_txns B
	set A.First_Txn_to_quality_reedit = 'Y'
	where A.eos_user_id=B.eos_user_id AND A.FTD=B.transact_date AND B.Txn_to_quality_re_edit='Y' ;
	
	/* campaign email sent is an indicator variable for identifying customers which have received campaign communication */
	
	alter table SVOC add column campaign_email_sent varchar(2);
	
	update SVOC 
	set campaign_email_sent='Y'
	where First_email_send_date is not null and First_email_send_date >'0000-00-00';

	/* Mode of payment in the first order */
	
	alter table SVOC add column First_payment_type varchar(20);

	update SVOC A,(select eos_user_id,payment_type,min(transact_date) as transact_date from Cust_txns group by eos_user_id) B
	set A.First_payment_type=B.payment_type
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date and payment_type is not null;
	
	/* First order price_after_tax */
	
	alter table SVOC add column First_price_after_tax varchar(10);

	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,Standardised_Price,min(transact_date) as transact_date from Cust_txns group by eos_user_id) B
	set A.First_price_after_tax=B.Standardised_Price
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date and Standardised_Price is not null;



	###########   first job number of components
	
	/* Computing: Number of components in the job */
	
	alter table Cust_txns add column No_service_components int(5);

	alter table Cust_txns add index(service_id);
	alter table process_service_mapping add index(service_id);

	update Cust_txns A,(select service_id,count(distinct id) as component from process_service_mapping group by service_id) B
	set A.No_service_components=B.component
	where A.service_id=B.service_id;
	
	/* First_service_components - Is the number of service components in the first order */
	
	alter table SVOC add column First_service_components int(5);

	update SVOC A,Cust_txns B
	set A.First_service_components=B.No_service_components
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;

	#################### First Transaction New Variables #################3
	#First_subject_is_in_top_subject_area
	#First_txn_job_completion_time
	#First_feedback_outstanding
	#First_feedback_acceptable
	#First_feedback_non_acceptable

	ALTER TABLE SVOC
	ADD Column First_subject_in_top_subject_areas varchar(2) default 'N',
	ADD Column First_txn_feedback_given varchar (2) default 'N',
	ADD Column First_feedback_outstanding varchar(2) default 'N',
	ADD Column First_feedback_acceptable varchar(2) default 'N',
	ADD Column First_feedback_not_acceptable varchar(2) default 'N',
	ADD Column First_txn_job_completion_time_in_days int(11);

	UPDATE SVOC A, Cust_txns B
	set A.First_subject_in_top_subject_areas = 'Y'
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.Is_in_top_sub_Area = 'Y';

	SELECT eos_user_id, First_subject_in_top_subject_areas FROM SVOC
	WHERE A.First_subject_in_top_subject_areas IS NOT NULL;

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_given = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate is not null;

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_outstanding = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate = 'outstanding';

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_acceptable = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate = 'acceptable';

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_not_acceptable = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate = 'not-acceptable';

	UPDATE SVOC A, Cust_txns B
	set A.First_txn_job_completion_time_in_days = B.TimeForJobCompletion/(3600*24)
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;

	### Tag Y if country is one of TOP 3 countries.
	ALTER TABLE SVOC
	ADD Column Country_in_top_countries varchar(2) default 'N';

	UPDATE SVOC A
	set Country_in_top_countries = 'Y'
	WHERE Country IN ('Japan','South Korea','China');

	#####################   Fiscal_tenure     ##############################
	
	alter table SVOC
	add column Tenure_fiscal int(10);

	set sql_safe_updates=0;
	update SVOC 
	set Tenure_fiscal = datediff('2018-03-31',FTD);
	
	
	select 	'3' as Lifetime_revenue_band,eos_user_id,Annualized_fiscal_value,Active_fiscal_years,Tenure_fiscal,Recency_fy_17_18_year,Frequency_fy_17_18 from SVOC
	where Annualized_fiscal_value<420.74 and Frequency_fy_17_18 in (1,2)
	union all 
	select 	'2' as Lifetime_revenue_band,eos_user_id,Annualized_fiscal_value,Active_fiscal_years,Tenure_fiscal,Recency_fy_17_18_year,Frequency_fy_17_18 from SVOC
	where (Annualized_fiscal_value>=420.74 and Annualized_fiscal_value<843.34)  and Frequency_fy_17_18 in (1,2)
	union all
	select 	'1' as Lifetime_revenue_band,eos_user_id,Annualized_fiscal_value,Active_fiscal_years,Tenure_fiscal,Recency_fy_17_18_year,Frequency_fy_17_18 from SVOC
	where (Annualized_fiscal_value>=843.34)  and Frequency_fy_17_18 in (1,2);


	alter table SVOC
	add column Updated_MVC_17_18 varchar(2) default 'N';

	update SVOC
	set Updated_MVC_17_18='Y'
	where Annualized_fiscal_value>=420.74 and Frequency_fy_17_18>=3;
	
	
	
	#######################################################################################################################
	
	
				######################     ENQUIRY LEVEL MODEL      ##############################################################
				
	
	#######################################################################################################################
	/* creating enquiry base */
	
	

	create table FTD_Cust_txns as
	select * from component
	where type='normal' and component_type='job' and price_after_tax is not null and price_after_tax>0
	and enquiry_id in (select A.id from enquiry A,EOS_USER B where A.eos_user_id=B.id and B.client_type='individual' and B.type='live');


	alter table FTD_Cust_txns
	add column currency_code varchar(10),
	add column wb_user_id varchar(10),
	add index(id),
	add index(enquiry_id);

	alter table component_auction
	add index(enquiry_id);

	set sql_safe_updates=0;
	update FTD_Cust_txns A,Orders B
	set A.currency_code=B.currency_code
	where A.enquiry_id=B.enquiry_id;

	alter table FTD_Cust_txns
	add column eos_user_id int(11);

	update FTD_Cust_txns A,enquiry B
	set A.eos_user_id=B.eos_user_id
	where A.enquiry_id=B.id;

	create table SVOC_First_enquiry as 
	select eos_user_id,min(left(created_date,10)) as FTD
	from FTD_Cust_txns
	group by eos_user_id;

	alter table FTD_Cust_txns
	add column transact_date_1 date,
	add column  transact_date varchar(10);
		
		set sql_safe_updates=0;
		update FTD_Cust_txns
		set transact_date=Left(created_date,10);
		

	alter table SVOC_First_enquiry
	add column First_unit_count int(10),
	add column First_subject_area_id int(10),
	add column First_service_id int(10),
	add column First_client_instruction_present varchar(2),
	add column First_delivery_instruction_present varchar(2),
	add column First_title_present varchar(2),
	add column First_journal_name_present varchar(2),
	add column First_use_ediatge_card varchar(2),
	add column First_editage_card_id int(10),
	add column First_author_name_present varchar(2),
	add column First_payment_type varchar(20),
	add column First_subject_area int(10),
	add column First_price_after_tax int(10),
	add column First_txn_discount varchar(2),
	add column First_txn_Coupon_used varchar(2),
	add column First_job_word_count int(10),
	add column First_NoOfQues int(10),
	add column First_service_components varchar(2);

	ALTER TABLE SVOC_First_enquiry 
	add column First_txn_Coupon_used varchar(2);
	ALTER TABLE SVOC_First_enquiry
	add column transacted_or_not varchar(2) default 'N';

	UPDATE SVOC_First_enquiry A, FTD_Cust_txns B
	set A.transacted_or_not = 'Y'
	where A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND status = 'send-to-client';
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,transact_date, offer_code from FTD_Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;

	alter table SVOC_First_enquiry add index(FTD);	
	alter table FTD_Cust_txns add index(created_date);
	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_unit_count=B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10);

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_subject_area_id=B.subject_area_id
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10);

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_service_id=B.service_id
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10);


	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_client_instruction_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10) and B.client_instruction not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_delivery_instruction_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10) and B.delivery_instruction not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_title_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10) and B.title not like ('%test%');


	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_journal_name_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10) and B.journal_name not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_journal_name_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD=left(B.created_date,10) and B.journal_name not like ('%test%');

	alter table FTD_Cust_txns add column invoice_id int(9);

	update FTD_Cust_txns A,Orders B
	set A.invoice_id=B.invoice_id
	where A.enquiry_id=B.enquiry_id and B.invoice_id is not null;

	alter table FTD_Cust_txns add column payment_type varchar(9);


	create temporary table as migration
	select * from master;

	set sql_safe_updates=0;
	update migration
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode'));

	create temporary table mig as 
	select * from masters;

	alter table mig add column payment_mode varchar(20);

	set sql_safe_updates=0;
	update mig
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode'))
	where config_id=48;
	###################################################################
	
	/* Adding transaction specific variables */
	
	alter table FTD_Cust_txns add column payment_type varchar(30);

	update FTD_Cust_txns
	set payment_type=null;

	alter table FTD_Cust_txns
	add column payment_mode_id varchar(6);

	update FTD_Cust_txns A,(select payment_mode_id,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_mode_id=B.payment_mode_id
	where A.invoice_id=B.invoice_debit_note_id;

	alter table FTD_Cust_txns add index(payment_mode_id);
	alter table mig add index(id);


	alter table FTD_Cust_txns add column payment_type varchar(30);
	update FTD_Cust_txns A, mig B
	set A.payment_type=B.payment_mode	
	where A.payment_mode_id=B.id and B.config_id=48;


	set sql_safe_updates=0;
	update FTD_Cust_txns A,(select payment_mode_name,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_type=B.payment_mode_name
	where A.invoice_id=B.invoice_debit_note_id;

	 alter table SVOC_First_enquiry
	add column Favourite_payment_type varchar(20);

	 
	 UPDATE IGNORE
			SVOC_First_enquiry A
		SET Favourite_payment_type=(
			SELECT 
						payment_type 
					FROM (select eos_user_id,payment_type ,count(*) as ratings,sum(price_after_tax) as sum from FTD_Cust_txns group by eos_user_id,payment_type  order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
	
	update SVOC_First_enquiry A,(select eos_user_id,payment_type,min(left(created_date,10)) as transact_date from FTD_Cust_txns group by eos_user_id) B
	set A.First_payment_type=B.payment_type
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date and payment_type is not null;
		
		alter table FTD_Cust_txns
		add index(transact_date_1,currency_code);
		
		update FTD_Cust_txns
		set transact_date_1=case when transact_date ='2017-12-22' then '2017-12-21' else 
		case when transact_date in ('2018-01-26','2018-01-27','2018-01-28','2018-01-29') then '2018-01-25' else
		case when transact_date ='2018-02-02' then '2018-02-01' else transact_date end end end;

	   alter table FTD_Cust_txns
	add column Standardised_Price double;

		alter table FTD_Cust_txns
		add index(transact_date_1);
		
		alter table FTD_Cust_txns
		add column rate_to_USD double;
		
		update FTD_Cust_txns
		set rate_to_USD=1
		where currency_code='USD';

		update FTD_Cust_txns A,(select currency_from,currency_to,avg(exchange_rate) as forex
		from exchange_rate
		where currency_to='USD' 
		and exchange_rate>0 and exchange_rate is not null
		group by currency_from,currency_to) B
		set rate_to_USD= forex
		where A.currency_code=B.currency_from and currency_code is not null;


		update FTD_Cust_txns
		set Standardised_Price=rate_to_USD*price_after_tax;

		set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,Standardised_Price,min(transact_date) as transact_date from FTD_Cust_txns group by eos_user_id) B
	set A.First_price_after_tax=B.Standardised_Price
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date and Standardised_Price is not null;

	ALTER TABLE SVOC_First_enquiry add column First_txn_discount varchar(2);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,transact_date,discount from FTD_Cust_txns where discount >0 and discount is not null) B
	set A.First_txn_discount='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;	

	ALTER TABLE SVOC_First_enquiry add column First_txn_Coupon_used varchar(2);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,transact_date, offer_code from FTD_Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;


	ALTER TABLE SVOC_First_enquiry add column First_job_word_count varchar(20);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,transact_date, unit_count from FTD_Cust_txns) B
	set A.First_job_word_count =B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_client_instruction_present='Y' 
	where A.FTD=B.transact_date and client_instruction is not null and client_instruction not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_delivery_instruction_present='Y' 
	where A.FTD=B.transact_date and delivery_instruction is not null and delivery_instruction not like '%test%';



	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_title_present='Y' 
	where A.FTD=B.transact_date and title is not null and title not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_journal_name_present='Y' 
	where A.FTD=B.transact_date and journal_name is not null and journal_name not like '%test%';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_use_ediatge_card=null'Y' 
	where A.FTD=B.transact_date and use_ediatge_card='Yes' and editage_card_id is not null and use_ediatge_card not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_author_name_present='Y' 
	where A.FTD=B.transact_date and author_name is not null and author_name not like '%test%';

	alter table FTD_Cust_txns add column No_service_components int(5);

	alter table FTD_Cust_txns add index(service_id);
	alter table process_service_mapping add index(service_id);

	update FTD_Cust_txns A,(select service_id,count(distinct id) as component from process_service_mapping group by service_id) B
	set A.No_service_components=B.component
	where A.service_id=B.service_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_service_components=B.No_service_components
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;

	/* Computing One year from the FTD (first enquiry date) for each customer */
	
	ALTER TABLE SVOC_First_enquiry
	add column one_yr_from_FTD_date date,
	add column one_yr_Frq_from_FTD_date int,add column one_yr_Sales_from_FTD_date int; /* Computing One year frequency from the FTD  */

	update SVOC_First_enquiry
	set one_yr_from_FTD_date = DATE_ADD(FTD, INTERVAL 1 Year); 
	
	update SVOC_First_enquiry A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq,sum(Standardised_Price) as sum1 from FTD_Cust_txns A, SVOC_First_enquiry B
	where left(confirmed_date,10) between FTD and one_yr_from_FTD_date and A.eos_user_id=B.eos_user_id 
	and status='send-to-client'
	group by A.eos_user_id) C
	set A.one_yr_Frq_from_FTD_date=C.freq,A.one_yr_Sales_from_FTD_date=C.sum1
	where A.eos_user_id=C.eos_user_id;

	/* 
	
	It is important to determine whether the first transaction of the customer is valid order (converted to job or not)
	
	*/
	
	alter table FTD_Cust_txns
	add column is_order varchar(2) default 'N';

	alter table FTD_Cust_txns
	drop column is_order;

	alter table SVOC_First_enquiry
	add column is_order varchar(2) default 'N';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.is_order='Y'
	where A.FTD =B.transact_date and B.status='send-to-client';

	alter table SVOC_First_enquiry
	add column one_yr_MVC_from_FTD_date varchar(2);

	update SVOC_First_enquiry
	set one_yr_MVC_from_FTD_date=
	case when one_yr_Frq_from_FTD_date >= 2 and is_order='Y'   then '1' 
	when one_yr_Frq_from_FTD_date >= 3 and is_order='N' then '1' else '0' end; 

	alter table SVOC_First_enquiry
	add column one_yr_MVC_from_FTD_date_N varchar(2);

	update SVOC_First_enquiry
	set one_yr_MVC_from_FTD_date_N=
	case when one_yr_Frq_from_FTD_date >= 2 and is_order='Y' and  one_yr_Sales_from_FTD_date>=420.74 then '1' 
	when one_yr_Frq_from_FTD_date >= 3 and is_order='N' and one_yr_Sales_from_FTD_date>=420.74  then '1' else '0' end; 
	
	alter table FTD_Cust_txns
	add  column Is_in_top_sub_Area  varchar(2);

	/* Subject area among the top MVC decile or not */
	UPDATE FTD_Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	
	alter table FTD_Cust_txns
	add  column Is_in_top_sub_Area_N  varchar(2);

	/* Subject area among the top MVC decile or not */
	UPDATE FTD_Cust_txns
	SET Is_in_top_sub_Area_N = 'Y'
	WHERE subject_area_id IN
	(130,153,159,170,382,499,503,512,518,545,555,597,610,612,619,643,646,653,656,677,685,687,713,718,735,754,788,822,823,833,846,863,868,884,898,906,927,930,935,944,977,990,1023,1122,1127,1166,1175,1205,1220,1252,1253,1273,1321,1340,1378,1420,1424,1451,1456,1460,1462,1463,2068,2121,433,445,854,1448,1481,1577,129,268,1139,1479,802,43,98,559,616,674,705,720,787,812,828,902,1045,1050,1057,1193,1203,1480,2082,2113,1575,1028,32,1113,1517,1185,31,226,373,471,684,739,1162,1406,2120,1312,1146,13,275,600,1453,598,244,410,2090,537,1261,1361,117,240,1054,1352,573,48,439,1059,366,1572,2118,390,94,381,607,88,106,214,245,309,317,329,418,448,451,461,463,508,525,535,543,546,558,562,564,567,590,594,596,604,609,630,635,639,668,673,679,681,686,689,692,697,702,707,709,722,755,770,792,795,808,826,847,857,879,889,929,931,934,949,967,1005,1036,1058,1067,1068,1077,1106,1144,1178,1214,1219,1226,1234,1320,1335,1349,1377,1379,1389,1418,1421,1449,1457,1461,1491,2069,2073,2084,2117);
	
	alter table SVOC_First_enquiry
	add column First_Is_in_top_sub_Area varchar(2),
	add column First_Is_in_top_sub_Area_N varchar(2);

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_Is_in_top_sub_Area='Y'
	where A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id and Is_in_top_sub_Area= 'Y';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_Is_in_top_sub_Area_N='Y'
	where A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id and Is_in_top_sub_Area_N= 'Y';

	alter table FTD_Cust_txns
	add column Premium varchar(5);

	update FTD_Cust_txns  A, service B
	set A.Premium =B.Premium 
	where A.service_id=B.id;


	#####################     REVISION

	select enquiry_id,created_date
	from component;

	select nid,max(FROM_UNIXTIME(created_date))
	from node group by nid;


	alter table enquiry
	add column FTD_rev_date date;

	update enquiry A,
	(select A.nid,enquiry_id,Left(FROM_UNIXTIME(created),10) as date
	from node A,content_type_enquiry B
	where A.nid=B.nid) B
	set A.FTD_rev_date=B.date
	where A.id=B.enquiry_id;



		alter table FTD_Cust_txns add column Revision_in_subject_area varchar(2);
		alter table FTD_Cust_txns add column Revision_in_price_after_tax varchar(2);
		alter table FTD_Cust_txns add column Revision_in_service_id varchar(2);
		alter table FTD_Cust_txns add column Revision_in_delivery_date varchar(2);
		alter table FTD_Cust_txns add column Revision_in_words varchar(2);

		alter table FTD_Cust_txns add index(enquiry_id);
		
		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		
	alter table FTD_Cust_txns 
	add column FTD_rev_date date;

	update FTD_Cust_txns A,enquiry B
	set A.FTD_rev_date=B.FTD_rev_date
	where
	A.enquiry_id=B.id;

	Alter Table SVOC
	ADD Column First_txn_Rev_in_subject_area_EN varchar(2),
	ADD Column First_txn_Rev_in_price_after_tax_EN varchar(2),
	ADD Column First_txn_Rev_in_service_id_EN varchar(2),
	ADD Column First_txn_Rev_in_delivery_date_EN varchar(2),
	ADD Column First_txn_Rev_in_words_EN varchar(2);


	UPDATE SVOC_First_enquiry A, (SELECT eos_user_id, transact_date,FTD_rev_date,Revision_in_subject_area, Revision_in_price_after_tax, Revision_in_service_id, Revision_in_delivery_date, Revision_in_words FROM FTD_Cust_txns) B
	set A.First_txn_Rev_in_subject_area_EN = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_price_after_tax_EN = CASE WHEN  B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_service_id_EN = CASE WHEN  B.Revision_in_service_id = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_delivery_date_EN = CASE WHEN   B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_words_EN = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A.eos_user_id = B.eos_user_id and A.FTD=B.transact_date  and A.FTD=B.FTD_rev_date;

	/*
	
	select eos_user_id,First_txn_Rev_in_subject_area_EN from SVOC_First_enquiry where First_txn_Rev_in_subject_area_EN='Y';
	select enquiry_id,eos_user_id,transact_date,FTD_rev_date,Revision_in_subject_area from FTD_Cust_txns where eos_user_id =309;
	select * from content_type_enquiry where enquiry_id=324353;
	select nid,vid,Left(FROM_UNIXTIME(created),10) as date from node where nid=4606153;
	
	*/
		ALTER table SVOC_First_enquiry 
	add column First_quotation_given varchar(2) default 'N';
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_quotation_given = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD=B.transact_date;

	update FTD_Cust_txns A,component_auction B
	set A.wb_user_id=B.wb_user_allocated_id
	where A.enquiry_id=B.enquiry_id;
		
	#########################                      SALUTATION
	

	CREATE TEMPORARY TABLE eos_USER AS 
	SELECT * FROM CACTUS.EOS_USER;

	alter table eos_USER
	add column salutation_code varchar(5);
		
	set sql_safe_updates=0;
	update eos_USER
	set salutation_code = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_salutation'));
		
	CREATE TEMPORARY TABLE masters1 AS 
	SELECT * FROM CACTUS.masters;

	alter table masters1
	add column salutation varchar(5);
		
	set sql_safe_updates=0;
	update masters1
	set salutation = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_salutation_name'));
		
	alter table eos_USER
	add column salutation varchar(20);
		
	alter table eos_USER add index(salutation_code);
	alter table masters1 add index(id);
		
	update eos_USER A,masters1 B
	set A.salutation=B.salutation
	where A.salutation_code=B.id;
		
	alter table SVOC_First_enquiry
	add column salutation varchar(10);
		
	update SVOC_First_enquiry A,eos_USER B
	set A.salutation=B.salutation
	where A.eos_user_id=B.id;
			
	alter table SVOC_First_enquiry 
	add column First_service_segment int(5);

	update SVOC_First_enquiry A,service B
	set A.First_service_segment=B.service_segment
	where A.First_service_id=B.id;
		
	alter table SVOC_First_enquiry add column partner_id varchar(20);    

	update SVOC_First_enquiry A,EOS_USER B
	set A.partner_id=B.partner_id where A.eos_user_id=B.id;
		
	alter table SVOC_First_enquiry add column partner_name varchar(20);    

	update SVOC_First_enquiry A,partner B
	set partner_name=B.name where A.partner_id=B.id;
	
	###############   new vars 
	
	alter table FTD_Cust_txns
	add column Is_service_Standard_Editing varchar(2) default 'N',
	add column Is_service_Premium_Editing varchar(2) default 'N',
	add column Is_service_Premium_Editing_Plus varchar(2) default 'N',
	add column Is_service_Standard_Translation varchar(2) default 'N',
	add column Is_service_Korean_to_English_Translation varchar(2) default 'N',
	add column Is_service_Korean_to_English_Translation_Level_2 varchar(2) default 'N'
	;

	update FTD_Cust_txns
	set Is_service_Standard_Editing='Y'
	where service_id=36;


	update FTD_Cust_txns
	set Is_service_Premium_Editing='Y'
	where service_id=1;

	update FTD_Cust_txns
	set Is_service_Premium_Editing_Plus='Y'
	where service_id=49;

	update FTD_Cust_txns
	set Is_service_Standard_Translation='Y'
	where service_id=35;

	update FTD_Cust_txns
	set Is_service_Korean_to_English_Translation='Y'
	where service_id=55;

	update FTD_Cust_txns
	set Is_service_Korean_to_English_Translation_Level_2='Y'
	where service_id=10;


	alter table SVOC_First_enquiry 
	add column Is_First_service_Standard_Editing varchar(2) default 'N',
	add column Is_First_service_Premium_Editing varchar(2) default 'N',
	add column Is_First_service_Premium_Editing_Plus varchar(2) default 'N',
	add column Is_First_service_Standard_Translation varchar(2) default 'N',
	add column Is_First_service_Korean_to_English_Translation varchar(2) default 'N',
	add column Is_First_service_Korean_to_English_Translation_Level_2 varchar(2) default 'N'
	;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Standard_Editing='Y'
	where B.Is_service_Standard_Editing='Y' and A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Premium_Editing='Y'
	where B.Is_service_Premium_Editing='Y' and A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id;

	select count(*) from FTD_Cust_txns where Is_service_Premium_Editing='Y';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Premium_Editing_Plus='Y'
	where B.Is_service_Premium_Editing_Plus='Y' and A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Standard_Translation='Y'
	where B.Is_service_Standard_Translation='Y' and A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Korean_to_English_Translation='Y'
	where B.Is_service_Korean_to_English_Translation='Y' and A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Korean_to_English_Translation_Level_2='Y'
	where B.Is_service_Korean_to_English_Translation_Level_2='Y' and A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id;

	alter table FTD_Cust_txns
	add column Is_service_quotation_sought varchar(2);
	
	update FTD_Cust_txns
	set Is_service_quotation_sought= 'Y'
	where service_id in (1,2,36,49,102);
	
	alter table SVOC_First_enquiry
	add column First_service_is_quotation_sought varchar(2);
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_service_is_quotation_sought='Y'
	where B.Is_service_quotation_sought= 'Y' and A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;
	
	alter table FTD_Cust_txns
	add column service_segment int;

	update FTD_Cust_txns A,service B
	set A.service_segment=B.service_segment
	where A.service_id=B.id;

	select service_id,service_segment from FTD_Cust_txns limit 10;

	alter table FTD_Cust_txns
	add column Txn_type varchar(20);

	update FTD_Cust_txns
	set Txn_type = 
	case when service_segment=3 then 'Editing' else
	case when service_segment=6 then 'Translation' else 
	'others' end end;


	alter table SVOC_First_enquiry
	add column First_Txn_type varchar(20);

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_Txn_type=B.Txn_type
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;
	
	alter table SVOC 
	add column First_quotation_given varchar(2) default 'N';

	update SVOC A,Cust_txns B
	set A.First_quotation_given = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD=B.transact_date;

	alter table SVOC
	add column First_created_date varchar(10);

	update SVOC A,(select eos_user_id,min(created_date) as created_date
	from enquiry
	group by eos_user_id) B
	set A.First_created_date=left(B.created_date,10)
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC
	add column First_confirmed_date varchar(10);

	update SVOC A,(select eos_user_id,min(confirmed_date) as confirmed_date
	from Cust_txns
	group by eos_user_id) B
	set A.First_confirmed_date=B.confirmed_date
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC
	add column First_actual_time_for_job_confirmation int;

	update SVOC
	set First_actual_time_for_job_confirmation =DATEDIFF(First_confirmed_date,First_created_date)
	;
	
	
	
	
	

									###############     Customers        ###############

							###########         Creating Customer base with created_date
	
	/* creating a base of valid customers in the system */
	
	create temporary table Customers_1 as
	select id as Customer_id,partner_id,network_id,client_code,client_code_id,Extract(Year from created_date) as created_year /* computing created_year for the valid users */
	from EOS_USER
	where client_type='individual' and type='live' 
	group by Customer_id,partner_id,network_id,client_code,client_code_id;

	alter table Customers_1
	add index(Customer_id),
	add index(partner_id);

	##########     Appropriate enquiry base    ###############	
	/* creating a base of valid enquiries for each valid customer in the system */
	
	alter table enquiry
	add index(eos_user_id),
	add index(partner_id);
	
	set sql_safe_updates=0;
	drop table if exists Metrics;
	create temporary table Metrics as 
	select B.eos_user_id,B.id
	from Customers_1 A,enquiry B
	where A.Customer_id=B.eos_user_id 
	group by B.eos_user_id,B.id;

	alter table Metrics
	add index(id);
	alter table Orders
	add index(enquiry_id);

	############   entire_Base_valid_transactions      ################
	/* We have computed Cust_txns as a base of valid transactions, we will constantly refer to this transaction base for computing the SVOC table  */
	
	set sql_safe_updates=0;
	drop table Cust_txns;
	create table Cust_txns as 
	select A.eos_user_id,B.enquiry_id,B.unit_count,B.id as component_id,B.discount,B.subject_area_id,B.price_after_tax,B.delivery_date,B.sent_to_client_date,B.type,B.component_type,B.offer_code,B.allocation_type,B.file_type,B.journal_name,B.delivery_special_instruction,B.specialized_subject_area,B.created_date,B.service_id from Metrics A,component B
	where A.id=B.enquiry_id and B.status='send-to-client' and B.type='normal' and B.component_type='job' and B.price_after_tax is not null and B.price_after_tax > 0 ;
	#price_after_tax>0

	###############    adding subject SA1,SA 1_5 AND SA 1_6    ###############################


	CREATE TEMPORARY TABLE MAPPING AS 
	SELECT * FROM CACTUS.subject_area;

	alter table MAPPING
	add column SA1 varchar(500),
	add column SA1_5 varchar(500),
	add column SA1_6 varchar(500),
	add column SA1_name varchar(500),
	add column SA1_5_name varchar(500),
	add column SA1_6_name varchar(500);
	alter table MAPPING add index(SA1,SA1_5,SA1_6);
	alter table subject_area_mapping add index(id);
    alter table MAPPING add index(SA1,SA1_5,SA1_6,id);
	alter table Cust_txns add index(subject_area_id);
	alter table Cust_txns
	add column SA1 varchar(500),
	add column SA1_5 varchar(500),
	add column SA1_6 varchar(500);
	
	
	alter table Cust_txns
	add column SA1_id varchar(500),
	add column SA1_5_id varchar(500),
	add column SA1_6_id varchar(500);
 
	
	/* 1.   SA1 */
	set sql_safe_updates=0;
	update MAPPING
	set SA1 = JSON_UNQUOTE(JSON_EXTRACT(data, '$.sa1'));
    
	/* 2. SA1_5 */
	set sql_safe_updates=0;
	update MAPPING
	set SA1_5 = JSON_UNQUOTE(JSON_EXTRACT(data, '$.sa1_5'));

	/* 3. SA1_6  */
	set sql_safe_updates=0;
	update MAPPING
	set SA1_6 = JSON_UNQUOTE(JSON_EXTRACT(data, '$.sa1_6'));

	/* SA1 name */
	update MAPPING A,subject_area_mapping B
	set A.SA1_name=B.title	
	where A.SA1=B.id;
    
	/* SA1_5 name */
	update MAPPING A,subject_area_mapping B
	set A.SA1_5_name=B.title	
	where A.SA1_5=B.id;
    
	/* SA1_6 name */
	update MAPPING A,subject_area_mapping B
	set A.SA1_6_name=B.title	
	where A.SA1_6=B.id;

	
	/* SA1 name */
	update Cust_txns A,MAPPING B
	set A.SA1_6_id=B.SA1_6
	where A.subject_area_id=B.id;

	/* SA1_5 name */
	update Cust_txns A,MAPPING B
	set A.SA1_5=SA1_5_name
	where A.subject_area_id=B.id;

	/* SA1_6 name */
	update Cust_txns A,MAPPING B
	set A.SA1_6=SA1_6_name
	where A.subject_area_id=B.id

	
	/* SA1 name */
	update Cust_txns A,MAPPING B
	set A.SA1=SA1_name
	where A.subject_area_id=B.id;

	/* SA1_5 name */
	update Cust_txns A,MAPPING B
	set A.SA1_5=SA1_5_name
	where A.subject_area_id=B.id;

	/* SA1_6 name */
	update Cust_txns A,MAPPING B
	set A.SA1_6=SA1_6_name
	where A.subject_area_id=B.id

	/* Actual time for job completion is the difference between send-to-client-date and confirmed_date which is computed for each order */
	
	ALTER TABLE Cust_txns
	ADD COLUMN Act_Time_for_job_Completion int;

	alter table Cust_txns
	add column confirmed_date varchar(10);

	update Cust_txns A,component B
	set A.confirmed_date=left(B.confirmed_date,10)
	where A.component_id=B.id ;

	UPDATE Cust_txns
	set Act_Time_for_job_Completion = datediff(sent_to_client_date, confirmed_date); 

	/* Indicator variable whether quotation was sought by the customer */

	 alter table Cust_txns add column Quotation_given varchar(2);
	 update Cust_txns A,
	 (
	 select * from enquiry where source_url like 'ecf.online.editage.%'
	 or source_url like 'php_form/newncf' or source_url like 'ecf.app.editage.%'
	 or source_url like	 'ncf.editage.%'
	 or source_url like 'api.editage.%/existing'
	 or source_url like 'api.editage.com/newecf-skipwc'
	 ) B
	 set A.Quotation_given='Y'
	 where A.enquiry_id=B.id;
	 
	 
	 
	##############################   Other Metrics added to the Cust_txns
	
	alter table Cust_txns
	add column currency_code varchar(10),
	add column rate varchar(15),
	add column wb_user_id varchar(10),
	add index(component_id),
	add index(enquiry_id);
	alter table Cust_txns
	add column Delay int(5);
	alter table component_auction
	add index(enquiry_id);
    
	
	/* wb_user_id */
	update Cust_txns A,component_auction B
	set A.wb_user_id=B.wb_user_allocated_id
	where A.enquiry_id=B.enquiry_id;
 
    /* feedback rating */
	update Cust_txns A,client_feedback B
	set A.rate=B.rating
	where A.component_id=B.component_id;
	
	/* recoding rating to integer values */

	alter table Cust_txns add column calculated_rating  int;
	update Cust_txns
	set calculated_rating=
	case when rate='outstanding' then 3 else 
	case when rate='acceptable' then 2 else
	case when rate='not-acceptable' then 1 else
	null
	end end end;

	/* currency */
	update Cust_txns A,Orders B
	set A.currency_code=B.currency_code
	where A.enquiry_id=B.enquiry_id;
	
	/* Delay */
	update Cust_txns
	set Delay=case when Left(sent_to_client_date,10)>Left(delivery_date,10) then datediff(Left(sent_to_client_date,10),Left(delivery_date,10)) else 0 end;

	#################    Payment mode mapping   ######################
	
	
	/* Adding payment_type for each transaction */
	
	alter table Cust_txns
	add column payment_mode_id varchar(6),
	add column payment_type varchar(20)
	;
	
	/* Adding payment_mode_id from payment table for each transaction */
	
	create temporary table as migration
	select * from master;
	
	alter table migration
	add column payment_mode varchar(30);
	
	set sql_safe_updates=0;
	update migration
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode')); /* Extracting Payment mode from migration type */

	update Cust_txns A,(select payment_mode_id,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_mode_id=B.payment_mode_id
	where A.invoice_id=B.invoice_debit_note_id;
	
	
	alter table Cust_txns add column invoice_id int(9);
	update Cust_txns A,Orders B
	set A.invoice_id=B.invoice_id
	where A.enquiry_id=B.enquiry_id and B.invoice_id is not null;
	
	alter table Cust_txns add index(payment_mode_id);
	alter table mig add index(id);

	update Cust_txns A, mig B
	set A.payment_type=B.payment_mode	
	where A.payment_mode_id=B.id and B.config_id=48; /* mapping payment_mode_id with id from migration and config_id =48 */
	
	/* adding additional instructions of each job */
	
	alter table Cust_txns 
	add column client_instruction varchar(200),
	add column delivery_instruction varchar(200),
	add column title varchar(200),
	add column use_ediatge_card varchar(15),add column editage_card_id int(15),
	add column author_name varchar(30);

	update Cust_txns A,component B
	set 
	A.client_instruction=B.client_instruction,A.delivery_instruction=B.delivery_instruction,A.title=B.title,A.journal_name=B.journal_name,A.use_ediatge_card=B.use_ediatge_card,A.editage_card_id=B.editage_card_id,A.author_name=B.author_name
	where A.enquiry_id=B.enquiry_id;
	
	
	/* Ranking the Transactions of the Customer by Transact date */

	ALTER TABLE Cust_txns ADD Column Txn_No int(10);

	UPDATE Cust_txns A, (select eos_user_id, created_date, transact_date, ROW_NUMBER() Over(PARTITION BY eos_user_id ORDER BY created_date) as TXn_No FROM Cust_txns) B
	SET A.Txn_No = B.Txn_No 
	where A.eos_user_id = B.eos_user_id AND A.created_date = B.created_date;
	
	/* No of Questions */
	
	ALTER TABLE Cust_txns Add COLUMN NoOfQuestions Int;
	update Cust_txns B,component A
	set B.NoOfQuestions = (select count(*) from component where component_type='question' and A.enquiry_id= B.enquiry_id)
	where A.enquiry_id=B.enquiry_id;
	
	
	/* Computing whether an order led to paid_mre,valid_mre and quality-re_edit, this is computed for each valid order in Cust_txns */
	
	alter table Cust_txns
	add column Txn_to_paid_mre varchar(2),
	add column Txn_to_valid_mre varchar(2),
	add column Txn_to_quality_re_edit varchar(2);

	update 
	Cust_txns A
	,(SELECT enquiry_id,parent_id FROM component WHERE type = 'paid-mre' and price_after_tax is not null and price_after_tax >0 and status='send-to-client' and component_type='job') B
	set A.Txn_to_paid_mre = 'Y'
	where A.component_id=B.parent_id ;

	update 
	Cust_txns A
	,(SELECT enquiry_id,parent_id FROM component WHERE type = 'valid-mre' and price_after_tax is not null and price_after_tax >0 and status='send-to-client' and component_type='job') B
	set A.Txn_to_valid_mre = 'Y'
	where A.component_id=B.parent_id ;

	update 
	Cust_txns A
	,(SELECT enquiry_id,parent_id FROM component WHERE type = 'quality-re_edit' and price_after_tax is not null and price_after_tax >0 and status='send-to-client' and component_type='job') B
	set A.Txn_to_quality_re_edit = 'Y'
	where A.component_id=B.parent_id ;

	
	######################## 	% discount      ###############
	
	/*  SVOC  */
	
	/* 
	FTD- First enquiry date
	LTD - last enquiry date
	*/
	drop table SVOC;
	create table SVOC as
	select eos_user_id,round(count( case when rate ='not-acceptable'then rate end)/count(*),2) as percent_not_acceptable_cases,round(count( case when rate ='acceptable'then rate end)/count(*),2) as percent_acceptable_cases,round(count( case when rate is null then rate end)/count(*),2) as percent_not_rated_cases,round(count( case when rate ='outstanding'then rate end)/count(*),2) as percent_outstanding_cases/*order's with outstanding rating to the total orders*/,round(count( case when discount>0 then discount end)/count(*),2) as percent_discount_cases/*order's with discount to the total orders*/,round(count( case when delay>0 then delay end)/count(*),2) as percent_delay_cases/*order's with delay to the total orders*/,count(distinct(service_id)) as Range_of_services/*distinct service_id's*/,count(distinct(subject_area_id)) as Range_of_subjects/*distinct subject_area_id's*/,distinct(currency_code) as Currency_code,ROUND(avg(delay)) as Average_Delay/*average delay in orders*/,Count(Distinct(enquiry_id)) as Frequency/*distinct bills*/,MIN(Left(created_date,10)) as FTD,MAX(Left(created_date,10))  as LTD
	from Cust_txns
	group by eos_user_id;
	
	/* Temporal variables */
	alter table Cust_txns 
	add column Favourite_Month int(3),
	add column Favourite_Time int(2),
	add column Favourite_Day_Week varchar(2);
	alter table SVOC 
	add column maximum_rating varchar(20),add column Favourite_subject int(11);
	alter table SVOC add column Favourite_SA1_name varchar(30),add column Favourite_SA1_5_name varchar(30),add column Favourite_SA1_6_name varchar(30),
	add column Favourite_service int(11);			
	
	alter table SVOC add column Favourite_subject_name varchar(50),
	add column Favourite_service_name varchar(50);
	alter table SVOC add index(Favourite_subject);
	alter table subject_area add index(id);
	
	/* Average word count */
	
	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Average_word_count_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	
	/* Favourite_Month */
	update Cust_txns 
	set Favourite_Month=Extract(MONTH FROM created_date);

	/* Favourite_Time */
	update Cust_txns 
	set Favourite_Time=Extract(HOUR FROM created_date);

	/* Favourite_Day_Week */
	update Cust_txns 
	set Favourite_Day_Week=DAYOFWEEK(created_date);

	/* Favourite_week_number */
	update Cust_txns 
	set Week_number=FLOOR((DAYOFMONTH(created_date) - 1) / 7) + 1;
	
	/* Calculating most frequent Week_number, in case of tie, value is taken to into consideration*/
	
    UPDATE IGNORE
			SVOC A
		SET Favourite_Week_number=(
               SELECT 
						Week_number
					FROM (select eos_user_id,Week_number,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Week_number order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id 
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
	UPDATE IGNORE
			SVOC A
		SET Favourite_Month=(
                    SELECT 
						Favourite_Month
					FROM (select eos_user_id,Favourite_Month,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Favourite_Month order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
	/* Calculating most frequent Day of the Week, in case of tie, value is taken to into consideration*/	
	
    UPDATE IGNORE
			SVOC A
		SET Favourite_Day_Week=(
			SELECT 
						Favourite_Day_Week
					FROM (select eos_user_id,Favourite_Day_Week,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Favourite_Day_Week order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
    /* Calculating most frequent Time, in case of tie, value is taken to into consideration*/  						
    
	UPDATE IGNORE
			SVOC A
		SET Favourite_Time=(
			SELECT 
						Favourite_Time
					FROM (select eos_user_id,Favourite_Time,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,Favourite_Time order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);

	/* most_frequent rating given by the customer */				
					
	 UPDATE IGNORE
			SVOC A
		SET 
			maximum_rating = (
					SELECT 
						rate
					FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,rate order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);
				
				
	/* Calculating number of Number of MREs attached to a valid order in the Cust_txns */
	
	alter table Cust_txns
	add column No_OF_MRES int(4);

	update Cust_txns A,(select parent_id,count(*) as No_OF_MRES from component where component_type='job'  and type in ('quality-re_edit','paid-mre','valid-mre') group by parent_id) B
	set A.No_OF_MRES=B.No_OF_MRES
	where A.component_id=B.parent_id;

	###########       calculated_rating  ################# 	/*recoding ratings to numeric values */
	
	/* Computing average rating from the calculated  integer ratings */
	
	alter table SVOC add column average_calculated_rating double;

	update SVOC A,(select eos_user_id,avg(calculated_rating) as average_calculated_rating from Cust_txns where calculated_rating is not null group by eos_user_id) B
	set A.average_calculated_rating=B.average_calculated_rating
	where A.eos_user_id=B.eos_user_id;	
	
	/* Computing average rating from the calculated  integer ratings for time period 2017-2018 */
	
	alter table SVOC add column average_calculated_rating_2017_2018 double;

	update SVOC A,(select eos_user_id,avg(calculated_rating) as average_calculated_rating_2017_2018 from Cust_txns where calculated_rating is not null and transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.average_calculated_rating_2017_2018=B.average_calculated_rating_2017_2018
	where A.eos_user_id=B.eos_user_id;

	/* Computing average rating from the calculated  integer ratings for time period 2016-2017 */
	
	alter table SVOC add column average_calculated_rating_2016_2017 double;

	update SVOC A,(select eos_user_id,avg(calculated_rating) as average_calculated_rating_2016_2017 from Cust_txns where calculated_rating is not null and transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.average_calculated_rating_2016_2017=B.average_calculated_rating_2016_2017
	where A.eos_user_id=B.eos_user_id;
	
	/* most_frequent subject area denoted by the customer */
	
	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_subject= (
					SELECT 
						subject_area_id
					FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);
	
	/* most_frequent service_id allocated to the customer */	

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);			
	
	/* most_frequent SA1 allocated to the customer */	

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_SA1_name=(
					SELECT 
						SA1
					FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,SA1 order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		
				
	/* most_frequent SA1_5 allocated to the customer */

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_SA1_5_name=(
					SELECT 
						SA1_5
					FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

				/* most_frequent SA1_6 allocated to the customer */

	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_SA1_6_name=(
					SELECT 
						SA1_6
					FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

	/* allocating name to the most_frequent_subject_area */
	set sql_safe_updates=0;
	update SVOC A,(select * from subject_area) B
	set A.Favourite_subject_name=B.title
	where A.Favourite_subject=B.id;
	
	/* allocating name to the most_frequent_service_id */
`	set sql_safe_updates=0;
	update SVOC A,(select * from service) B
	set A.Favourite_service_name=B.name
	where A.Favourite_service=B.id;
	
	/*  ###############################			Calculating RFM VARIABLES AND DEMOGRAPHIC VARIABLES  ######################################*/
	
	
	alter table SVOC
	add column Recency int(10),
	add column ADGBT int(10),
	add column Tenure int(10),
	add column Recent_translator varchar(10),
	add column First_translator varchar(10),
	add index(eos_user_id),
	add index(LTD),
	add column partner_id int(10),
	add column network_id int(10),
	add column client_code varchar(10),
	add column client_code_id int(10),
	add column created_year varchar(10),
	add column network_name varchar(20),
	add column partner_name varchar(20),
	add column organisation varchar(150),
	add column dob varchar(50),
	add column Job_title varchar(20),
	add column Country varchar(20),
	add column Language varchar(10),
	add column Number_of_times_rated int(5);

	alter table Cust_txns
	add index(eos_user_id),
	add index(created_date);
	alter table Cust_txns
	add column transact_date varchar(10),
	add column rate_to_USD double;

	/* Taking into account the date attributes only */
	
	set sql_safe_updates=0;
	update Cust_txns
	set transact_date=Left(created_date,10);

	###############################             Translator                 ####################
	
	
	alter table Cust_txns add index(component_id);
	alter table component_detail add index(component_id);

	/* mapping enquiry with the wb_user_id */
	
	update Cust_txns A,
	(select component_id,wb_user_id,min(actual_end_date) as date from component_detail where status='accepted' group by component_id,wb_user_id )B
	set A.wb_user_id=B.wb_user_id
	where A.component_id=B.component_id;
	
	/* Calculating most frequent Translator for each customer */
	
	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_Translator = (
						SELECT 
							wb_user_id
						FROM (select eos_user_id,wb_user_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,wb_user_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);


	
	/* Calculating wb_user on most recent date */
	update SVOC A,Cust_txns B
	set A.Recent_translator=B.wb_user_id
	where A.eos_user_id=B.eos_user_id and A.LTD=B.transact_date;

	/* Calculating First_translator from the First Transaction date */
	
	update SVOC A,Cust_txns B
	set A.First_translator=B.wb_user_id
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;

	/* Calculating FTD and LTD based on first transact date and last transact_date */
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD,max(transact_date) as LTD from Cust_txns   group by eos_user_id) B
	set A.FTD=B.FTD,A.LTD=B.LTD
	where A.eos_user_id=B.eos_user_id;
	
	/* Average Days Gap Between Transactions: ADGBT = (LTD - FTD ) / (Frequency -1 ) */
	
	update SVOC
	set ADGBT=datediff(LTD,FTD)/(Frequency-1);

	/* calculating Days since last transaction */	

	update SVOC
	set Recency=datediff('2018-08-28',LTD);

	/* calculating Tenure for each customer in the system */
	
	update SVOC
	set Tenure=datediff('2018-08-28',FTD);


	##############################################    partner_id,service_id mapping    #########################
	
	/* adding demographics and geographical variables to each customers */
	
	update SVOC A,Customers_1 B
	set A.partner_id=B.partner_id,A.network_id=B.network_id,A.client_code=B.client_code,A.client_code_id=B.client_code_id,A.created_year=B.created_year
	where A.eos_user_id=B.Customer_id;
	
	update SVOC A,network B
	set network_name=B.name where A.network_id=B.id;

	update SVOC A,partner B
	set partner_name=B.name where A.partner_id=B.id;

	###############################        USER_PROFILE            ####################

	
	#################    email id domain 

	/* We have email_id from a  EOS_USER table where email_id compulsorily should not be MASKED*/

	alter table SVOC add column email_id_domain varchar(200);

	update SVOC A,
	(SELECT id,SUBSTRING(email_id, LOCATE('@', email_id) + 1) AS domain FROM EOS_USER_NEW) B
	set A.email_id_domain=B.domain
	where A.eos_user_id=B.id;
	
	/* Adding salutation  for each customer */
	
	CREATE TEMPORARY TABLE eos_USER AS 
	SELECT * FROM CACTUS.EOS_USER;

	alter table eos_USER
	add column salutation_code varchar(5);
	
	set sql_safe_updates=0;
	update eos_USER
	set salutation_code = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_salutation'));
	
	
	CREATE TEMPORARY TABLE masters1 AS 
	SELECT * FROM CACTUS.masters;

	alter table masters1
	add column salutation varchar(5);
	
	set sql_safe_updates=0;
	update masters1
	set salutation = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_salutation_name'));
	
	alter table eos_USER
	add column salutation varchar(20);
	
	update eos_USER A,masters1 B
	set A.salutation=B.salutation
	where A.salutation_code=B.id;
	
	alter table SVOC
    add column salutation varchar(10);
    
	update SVOC A,eos_USER B
	set A.salutation=B.salutation
	where A.eos_user_id=B.id;
	
	
	/* #1 ORGANIZATION  */
	
	alter table eos_USER
	add column org1 varchar(500);

	set sql_safe_updates=0;
	update eos_USER
	set org1 = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_org'));

	/* #2 Date of Birth */
 	alter table eos_USER
	add column dob varchar(20);

	set sql_safe_updates=0;
	update eos_USER
	set dob = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_dob'));

	/* #3	Job_title */
	alter table eos_USER
	add column Job_title varchar(20);

	set sql_safe_updates=0;
	update eos_USER
	set Job_title = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_job_title'));


	/* #4  Country */

	alter table eos_USER
	add column Country varchar(20);

	set sql_safe_updates=0;
	update eos_USER
	set Country = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_address_country'));

	/* #5 Reference Source */

	alter table eos_USER
	add column Source int(10);

	set sql_safe_updates=0;
	update eos_USER
	set Source=JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_ref_source'));

	/* # 6 organization variables */

	alter table SVOC
	add index(eos_user_id);

	alter table eos_USER
	add index(id);

	update SVOC A, eos_USER B
	set A.organisation=B.org1,A.dob=B.dob,A.Job_title=B.Job_title,A.Country=B.Country,A.Language=B.Language
	where A.eos_user_id=B.id;

	/* Number of times Customer has rated */
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns group by eos_user_id) B
	set Number_of_times_rated=rate_count
	where A.eos_user_id=B.eos_user_id;

	/* Converting currency to USD*/

	alter table Cust_txns
	add column transact_date varchar(10),
	add column rate_to_USD double;

	/* we need to remove cases where payment master had improper currency currency values */
	
	alter table Cust_txns
	add column transact_date_1 date;

	alter table Cust_txns
	add index(transact_date_1,currency_code);
	
	/* Exchange_rate table is referred for standardizing prices to USD */
	
	alter table exchange_rate
	add column currency_date_val varchar(10);
	
	alter table exchange_rate 
	add index(currency_date_val,currency_from);

	
	update Cust_txns /* We have created transact_date_1 because transact_date in the given days need to have previous day's rate to dollar  */
	set transact_date_1=case when transact_date ='2017-12-22' then '2017-12-21' else 
	case when transact_date in ('2018-01-26','2018-01-27','2018-01-28','2018-01-29') then '2018-01-25' else
	case when transact_date ='2018-02-02' then '2018-02-01' else transact_date end end end;
	
	/* rate to USD  */
	
	update Cust_txns A,exchange_rate B
	set rate_to_USD=B.exchange_rate 
	where
	A.transact_date_1=B.currency_date_val and B.currency_to='USD' and A.currency_code=B.currency_from;
	select transact_date,created_date from Cust_txns;

	set sql_safe_updates=0;
	update exchange_rate
	set currency_date_val=Left(currency_date,10);

	alter table Cust_txns
	add column rate_to_USD double;

	###############################             currency_conversion                 ####################
	
	/* We are creating Standardised_Price variables which is contains conversion rate to USD for all the currencies */
	
	alter table Cust_txns
	add column Standardised_Price double;

	alter table Cust_txns
	add index(transact_date_1);

	update Cust_txns
	set rate_to_USD=1
	where currency_code='USD';

	/*We have taken all non negative and non-null currency rates to USD , we will average it out across all the time periods */
	
	update Cust_txns A,(select currency_from,currency_to,avg(exchange_rate) as forex
	from exchange_rate
	where currency_to='USD' 
	and exchange_rate>0 and exchange_rate is not null
	group by currency_from,currency_to) B
	set rate_to_USD= forex
	where A.currency_code=B.currency_from and currency_code is not null;

	/* Multiplying all price_after_tax with USD */
	
	update Cust_txns
	set Standardised_Price=rate_to_USD*price_after_tax;
	
	/* adding coupon code to each transaction */
	
	alter table Cust_txns 
	add column offer_code varchar(25);

	update Cust_txns A,coupon_tracker B
	set A.offer_code=B.coupon_code where A.enquiry_id=B.enquiry_id;


	#############################        Year Tags

	/* In our model building base, we have taken base from 
	in Aug to Aug cycle */
	
	/* Therefore we have created tags for customer for each year */
	
	alter table SVOC
	add column Sept_2018 varchar(5),
	add column Sept_2017 varchar(5),
	add column Sept_2016 varchar(5),
	add column Sept_2015 varchar(5),
	add column Sept_2014 varchar(5),
	add column Sept_2013 varchar(5),
	add column Sept_2012 varchar(5),
	add column Sept_2011 varchar(5),
	add column Sept_2010 varchar(5),
	add column Sept_2009 varchar(5),
	add column Sept_2008 varchar(5),
	add column Sept_2007 varchar(5),
	add column Sept_2006 varchar(5),
	add column Sept_2005 varchar(5);

	
	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') B
	set Sept_2018='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set Sept_2017='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') B
	set Sept_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2014-08-29' and '2015-08-28') B
	set Sept_2015='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2013-08-29' and '2014-08-28') B
	set Sept_2014='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2012-08-29' and '2013-08-28') B
	set Sept_2013='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2011-08-29' and '2012-08-28') B
	set Sept_2012='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2010-08-29' and '2011-08-28') B
	set Sept_2011='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2009-08-29' and '2010-08-28') B
	set Sept_2010='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2008-08-29' and '2009-08-28') B
	set Sept_2009='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2007-08-29' and '2008-08-28') B
	set Sept_2008='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2006-08-29' and '2007-08-28') B
	set Sept_2007='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2005-08-29' and '2006-08-28') B
	set Sept_2006='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2004-08-29' and '2005-08-28') B
	set Sept_2005='Y'
	where A.eos_user_id=B.eos_user_id;


	###############################              Recency - Frequency - Monetary Value Parameters                        ####################
	
	/* Creating key metrics for two different time periods 
		1)  1_years :- 29-Aug-2017 to 28-Aug-2018 indicated by _1_year
		2)	2_years :- 29-Aug-2016 to 28-Aug-2018 indicated by 2016_2017  _2_year
	
	*/ 
	
	/* FTD - first transaction date
	   LTD - last transaction date
	   frequency - number of transactions 
	   
	   
	/* RFM variables */
	
	alter table SVOC 
	add column ATV_entire int(20),
	add column ATV_1_year int(10),/* for time period 29-Aug-2017 to 28-Aug-2018  */
	add column ATV_2_year int(10), /* for time period 29-Aug-2016 to 28-Aug-2018 */
	add column Total_Standard_price int(15),
	add column Total_Standard_price_1_year int(15),/* for time period 29-Aug-2017 to 28-Aug-2018  */
	add column Total_Standard_price_2_year int(15), /* for time period 29-Aug-2016 to 28-Aug-2018 */
	add column FTD_1_years date, 
	add column LTD_1_years date,
	add column frequency_1_year int(4),
	add column ATV_1_year int(10),add column Recency_1_year int(5),add column ADGBT_1_Year int(5),add column Inactivity_ratio_1_year double,
	add column FTD_2_years date,
	add column LTD_2_years date,
	add column frequency_2_year int(4),
	add column ATV_2_year int(10),add column Recency_2_year int(5),add column ADGBT_2_Year int(5),
	add column ATV_entire int(10),
	add column  ATV_1_year int(10),
	add column ATV_2_year int(10);
	
    update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') B group by eos_user_id) B
	set A.FTD_1_years=B.FTD_1_years,A.LTD_1_years=B.LTD_1_years,A.frequency_1_year=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' );

	update SVOC
	set Recency_1_year=datediff('2018-08-28',LTD_1_years)
	where (Sept_2018='Y' ) and frequency_1_year is not null;

	update SVOC
	set ADGBT_1_Year=datediff(LTD_1_years,FTD_1_years)/(frequency_1_year-1)
	 where (Sept_2018='Y' ) and frequency_1_year is not null;
	
	/* ATV is average transaction value = Avg(total_sales_orders) 
	   Total_Standard_price is the sum of all Standardized Price After Tax 
	   ADGBT is the average days gap between transactions */
	 
	update SVOC A,(select eos_user_id,avg(Standardised_Price) as ATV_entire from Cust_txns group by eos_user_id) B
	set A.ATV_entire=B.ATV_entire
	where A.eos_user_id=B.eos_user_id;
	
	update SVOC A,(select eos_user_id,avg(case when transact_date between '2017-08-29' and '2018-08-28' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_1_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' );
	
	update SVOC A,(select eos_user_id,sum(case when transact_date between '2017-08-29' and '2018-08-28' then Standardised_Price end) as Total_Standard_price_1_year from Cust_txns  group by eos_user_id) B
	set A.Total_Standard_price_1_year=B.Total_Standard_price_1_year
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(case when transact_date between '2016-08-29' and '2018-08-28' then Standardised_Price end) as Total_Standard_price_2_year from Cust_txns  group by eos_user_id) B
	set A.Total_Standard_price_2_year=B.Total_Standard_price_2_year
	where A.eos_user_id=B.eos_user_id;
	
	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Total_Standard_price from Cust_txns  group by eos_user_id) B
	set A.Total_Standard_price=B.Total_Standard_price
	where A.eos_user_id=B.eos_user_id;
	
	/* */
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_2_years,max(transact_date) as LTD_2_years, count(distinct(enquiry_id)) as frequency_2_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2016-08-29' and '2018-08-28') B group by eos_user_id) B
	set A.FTD_2_years=B.FTD_2_years,A.LTD_2_years=B.LTD_2_years,A.frequency_2_year=B.frequency_2_year
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' or Sept_2017='Y');

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2016-08-29' and '2018-08-28' then Standardised_Price end) as ATV_2_year from Cust_txns group by eos_user_id) B
	set A.ATV_2_year=
	case when 
	B.ATV_2_year is null then 0 else B.ATV_2_year end
	where A.eos_user_id=B.eos_user_id and (Sept_2018='Y' or Sept_2017='Y');

	update SVOC
	set Recency_2_year=datediff('2018-08-28',LTD_2_years)
	where (Sept_2018='Y' or Sept_2017='Y') and frequency_2_year is not null;

	update SVOC
	set ADGBT_2_Year=datediff(LTD_2_years,FTD_2_years)/(frequency_2_year-1)
	 where (Sept_2018='Y' or Sept_2017='Y') and frequency_2_year is not null;
	
	########################     L2_segment for 2016_2017 #################
	
	alter table SVOC
	add column  ATV_2016_2017_year int(10),
	add column frequency_2016_2017_year int(4),
	add column Recency_2016_2017_year int(5),
	add column FTD_2016_2017_years date,
	add column LTD_2016_2017_years date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B group by eos_user_id) B
	set A.FTD_2016_2017_years=B.FTD_1_years,A.LTD_2016_2017_years=B.LTD_1_years,A.frequency_2016_2017_year=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id ;

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2016-08-29' and '2017-08-28' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_2016_2017_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_2016_2017_year=datediff('2017-08-28',LTD_2016_2017_years)
	where frequency_2016_2017_year is not null;
	
	
	##################################          Second Transaction Date                 ###############################################
	
	
	
	/* 
	   STD indicates second transaction date
	   STD_1_Year indicates second transaction date in the time period - 29-Aug-2017 to 28-Aug-2018 
	   STD_2_Year indicates second transaction date in the time period - 29-Aug-2016 to 28-Aug-2018
	*/
	
	alter table SVOC 
	add column Bounce_Curve int,
	add column STD date,
	add column STD_2_Year date,
	add column STD_1_Year date,
	add column Bounce_2_year int,
	add column Bounce_Curve int,
	add column Bounce_1_year int;
	
	
	set sql_safe_updates=0;
	UPDATE IGNORE
			SVOC A
	SET 
		STD = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
	WHERE 
			Frequency > 1 ;

	
		set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_1_Year = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2017-08-29' and '2018-08-28'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_1_year > 1 ;
			
			
		set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_2_Year = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2016-08-29' and '2018-08-28'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_2_year > 1 ;
	

	/* Bounce Curve is the difference between the STD and FTD, where eos_user has more than one transactions */
	
	update SVOC
	set Bounce_2_year = datediff(STD_2_Year,FTD_2_years)
	where frequency_2_year>1 and STD_2_Year is not null;/* for the time period - 29-Aug-2016 to 28-Aug-2018 */

	update SVOC
	set Bounce_Curve = datediff(STD,FTD)
	where Frequency>1 and STD is not null;

	update SVOC
	set Bounce_1_year = datediff(STD_1_Year,FTD_1_years)
	where frequency_1_year>1 and STD_1_Year is not null;/* for the time period - 29-Aug-2017 to 28-Aug-2018 */
	
	
	
	
	/*      Inactivity ratio is the indicator variable for a customer to showcase if a customer is currently transacting below,*/
			
	update SVOC
	set Inactivity_ratio_1_year=recency_1_year/ADGBT_1_year;

	
	#############################      Referral       #########################
	
	/* Source name extraction */
	
	drop table if exists eos_USER;
	create temporary table eos_USER as
	select * from EOS_USER;
	alter table eos_USER
	add column Source int(10);


	set sql_safe_updates=0;
	update eos_USER
	set Source=JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_ref_source'));

	alter table SVOC
	add column is_referred varchar(3);
	
	/* is_referred for customer referred customers */
	
	update SVOC A,eos_USER B
	set is_referred=
	case when Source is not null then 'Y' else 'N' end
	where A.eos_user_id=B.id and Source in ('77030','77016','13300',			
	'13303',
	'13304',
	'28563',
	'13297',
	'13309',
	'13310',
	'13311',
	'13312',
	'13307',
	'13305',
	'13298',
	'13424',
	'13421',
	'13422',
	'13431',
	'13425',
	'13426',
	'28572',
	'13419',
	'13423',
	'13420',
	'13432',
	'13416',
	'13417',
	'13418',
	'13427',
	'13429',
	'52518',
	'52519');

	alter table SVOC
	add column Referrer int(10);

	update SVOC A,eos_USER B
	set Referrer=B.Source
	where A.eos_user_id=B.id;
	
    /* adding Source_name to SVOC */
	
    alter table SVOC 
    add column Source int,
    add column Source_name varchar(100);
    
    update SVOC A,eos_USER B
    set A.Source =B.Source
    where A.eos_user_id=B.id;
    
	alter table SVOC
	add column Favourite_payment_type varchar(20);

	UPDATE IGNORE
			SVOC A
	SET Favourite_payment_type=(
	SELECT 
		payment_type 
					FROM (select eos_user_id,payment_type ,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns group by eos_user_id,payment_type  order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
					
    alter table SVOC add index(Source);
    alter table masters add index(id);
    
    update SVOC A,masters B
    set A.Source_name =B.name
    where A.Source=B.id;
    
	#############################  country
	
	/* Country of the user */
	
	alter table SVOC
	add index(Country);

	alter table country
	add index(iso_alpha2 );

	update SVOC A,(select name,iso_alpha2 from country) B
	set A.Country=
	name
	where A.Country=B.iso_alpha2;


/*
	##############################                  Number of reedits     ###########################
	
	
	
	alter table Cust_txns
	add column nummber_of_re_edits int(4);

	update Cust_txns A,
	(select enquiry_id,count(distinct(B.parent_id)) as nummber_of_re_edits
	from component A,
	(SELECT parent_id FROM component where parent_id is not null) B
	where A.enquiry_id=B.parent_id
	group by enquiry_id) B
	set A.nummber_of_re_edits=B.nummber_of_re_edits
	where A.enquiry_id=B.enquiry_id;

	/*
	alter table SVOC
	add column Number_of_reedits int(5);

	update SVOC A,(select eos_user_id,sum(case when nummber_of_re_edits is not null then nummber_of_re_edits end) as Number_of_reedits from Cust_txns group by eos_user_id) B
	set A.Number_of_reedits=B.Number_of_reedits
	where A.eos_user_id=B.eos_user_id;
	*/
	
	######################################### editage card #############################################
	
	/* mapping editage_card user */
	
	alter table SVOC
	add column editage_card_user varchar(2),
	add column editage_card_id int(5);


	update SVOC A,
	(select eos_user_id,B.editage_card_id from Cust_txns A,component B where A.enquiry_id=B.enquiry_id and B.editage_card_id is not null and use_ediatge_card='Yes') B
	set editage_card_user='Y',A.editage_card_id=B.editage_card_id
	where A.eos_user_id=B.eos_user_id;


	##########################priority ########################
	
	/* preferred_translator for each user */
	
	alter table SVOC
	add column preferred_translator int(10);

	update SVOC A,
	(select eos_user_id,wb_user_id from favourite_editor where status='favourite') B
	set preferred_translator=B.wb_user_id 
	where A.eos_user_id=B.eos_user_id;
	/* is_preferred_transalator */
	
	alter table SVOC 
	add column is_preferred_transalator varchar(2);/* indicator variable whether the customer has preferred translator or not in the entire_lifetime Aug-Aug cycle */

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2015-08-29' and '2016-08-28') B
	set A.is_preferred_transalator_2015_2016='Y'
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC 
	add column is_preferred_transalator_2015_2016 varchar(2);/* indicator variable whether the customer has preferred translator or not in the entire_lifetime Aug-Aug cycle 2015-2016 */

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2015-08-29' and '2016-08-28') B
	set A.is_preferred_transalator_2015_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	####################  promo_code
	
	/* cases offer_code for each customer */

	alter table SVOC
	add column percent_offer_cases int(8);

	update SVOC A,(select eos_user_id,round(count( case when offer_code is not null then offer_code end) *100/count(*),2) as percent_offer_cases from Cust_txns group by eos_user_id) B
	set A.percent_offer_cases=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;


	####################   Group 

	/* mapping group for each customer */
	
	alter table SVOC
	add column is_part_of_group varchar(3),/* indicator variable for mapping grouped customer */
	add column Number_of_group int(8);/* count of number of groups each user is part of */

	update SVOC A,(select distinct(eos_user_id) from group_author_association where eos_user_id is not null and group_id is not null) B
	set is_part_of_group ='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(distinct(group_id)) as Number_of_group from group_author_association where eos_user_id is not null or group_id is not null group by eos_user_id) B
	set A.Number_of_group =B.Number_of_group 
	where A.eos_user_id=B.eos_user_id;


	############# annualized_returns
	########### 

	/* indicator flags for transact period from Aug-to-Aug cycle */
	
	alter table Cust_txns
	add column update_transact_year int(5);

	update Cust_txns
	set update_transact_year=
	case when transact_date between '2004-08-29' and '2005-08-28' then 2005 else
	case when transact_date between '2005-08-29' and '2006-08-28' then 2006 else
	case when transact_date between '2006-08-29' and '2007-08-28' then 2007 else
	case when transact_date between '2007-08-29' and '2008-08-28' then 2008 else
	case when transact_date between '2008-08-29' and '2009-08-28' then 2009 else
	case when transact_date between '2009-08-29' and '2010-08-28' then 2010 else
	case when transact_date between '2010-08-29' and '2011-08-28' then 2011 else
	case when transact_date between '2011-08-29' and '2012-08-28' then 2012 else
	case when transact_date between '2012-08-29' and '2013-08-28' then 2013 else
	case when transact_date between '2013-08-29' and '2014-08-28' then 2014 else
	case when transact_date between '2014-08-29' and '2015-08-28' then 2015 else
	case when transact_date between '2015-08-29' and '2016-08-28' then 2016 else
	case when transact_date between '2016-08-29' and '2017-08-28' then 2017 else
	case when transact_date between '2017-08-29' and '2018-08-28' then 2018 else 'NA'
	end end end end end end end end end end end  end end  end ;

	/* indicator flags for transact period from April-to-March cycle */
	
	alter table Cust_txns
	add column fiscal_transact_year int(5);

	update Cust_txns
	set fiscal_transact_year=
	case when transact_date between '2004-04-01' and '2005-03-31' then 2004 else
	case when transact_date between '2005-04-01' and '2006-03-31' then 2005 else
	case when transact_date between '2006-04-01' and '2007-03-31' then 2006 else
	case when transact_date between '2007-04-01' and '2008-03-31' then 2007 else
	case when transact_date between '2008-04-01' and '2009-03-31' then 2008 else
	case when transact_date between '2009-04-01' and '2010-03-31' then 2009 else
	case when transact_date between '2010-04-01' and '2011-03-31' then 2010 else
	case when transact_date between '2011-04-01' and '2012-03-31' then 2011 else
	case when transact_date between '2012-04-01' and '2013-03-31' then 2012 else
	case when transact_date between '2013-04-01' and '2014-03-31' then 2013 else
	case when transact_date between '2014-04-01' and '2015-03-31' then 2014 else
	case when transact_date between '2015-04-01' and '2016-03-31' then 2015 else
	case when transact_date between '2016-04-01' and '2017-03-31' then 2016 else
	case when transact_date between '2017-04-01' and '2018-03-31' then 2017 else 
	case when transact_date between '2018-04-01' and '2019-03-31' then 2018 else 'NA'
	end end end end end end end end end end end  end end  end end;

	/* 1 Year fiscal frequency - april 17 to Mar 18 */
	
	alter table SVOC
	add column Frequency_fy_17_18 int(5);
	
	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as Frequency_fy_17_18 from Cust_txns where fiscal_transact_year=2017 group by eos_user_id) B
	set A.Frequency_fy_17_18=B.Frequency_fy_17_18
	where A.eos_user_id=B.eos_user_id and fiscal_2017='Y';
	
	alter table SVOC
	add column  ATV_fy_17_18_year int(10),
	add column Recency_fy_17_18_year int(5),
	add column FTD_fy_17_18_years date,
	add column LTD_fy_17_18_years date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2017-04-01' and '2018-03-31') B group by eos_user_id) B
	set A.FTD_fy_17_18_years=B.FTD_1_years,A.LTD_fy_17_18_years=B.LTD_1_years
	where A.eos_user_id=B.eos_user_id ;

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2017-04-01' and '2018-03-31' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_fy_17_18_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_fy_17_18_year=datediff('2018-03-31',LTD_fy_17_18_years)
	where Frequency_fy_17_18 is not null;
	
	/* distinct active year (fiscal-wise) */
	
	alter table SVOC
	add column Active_fiscal_years int(5);
	
	update SVOC A,
	(select eos_user_id,count(distinct(fiscal_transact_year)) as Distinct_years from Cust_txns where transact_date between '2004-04-01' and '2018-03-31' group by eos_user_id) B
	set A.Active_fiscal_years=B.Distinct_years
	where A.eos_user_id=B.eos_user_id;
	
	/* Total spend fiscal wise */
	
	alter table SVOC add column fiscal_Standardised_Value double;
	
	update SVOC A,
	(select eos_user_id,sum(Standardised_Price) as fiscal_Standardised_Value from Cust_txns where transact_date between '2004-04-01' and '2018-03-31' group by eos_user_id) B
	set A.fiscal_Standardised_Value=B.fiscal_Standardised_Value
	where A.eos_user_id=B.eos_user_id;
	
	/* Calculating annualized value for fiscal years between 01 April 2004 and  31st March 2018*/
	
	alter table SVOC
	add column Annualized_fiscal_value double;
	
	update SVOC
	set Annualized_fiscal_value=(fiscal_Standardised_Value/Active_fiscal_years);

	/*select eos_user_id,Frequency_fy_17_18,Active_fiscal_years,fiscal_Standardised_Value,Annualized_fiscal_value
	from SVOC;*/
	##################   fiscal
	
	/* fiscal indicator for each year */

	alter table SVOC
	add column fiscal_2018 varchar(5),
	add column fiscal_2017 varchar(5),
	add column fiscal_2016 varchar(5),
	add column fiscal_2015 varchar(5),
	add column fiscal_2014 varchar(5),
	add column fiscal_2013 varchar(5),
	add column fiscal_2012 varchar(5),
	add column fiscal_2011 varchar(5),
	add column fiscal_2010 varchar(5),
	add column fiscal_2009 varchar(5),
	add column fiscal_2008 varchar(5),
	add column fiscal_2007 varchar(5),
	add column fiscal_2006 varchar(5),
	add column fiscal_2005 varchar(5),
	add column fiscal_2004 varchar(5);


	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2018-04-01' and '2019-03-31') B
	set fiscal_2018='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2017-04-01' and '2018-03-31') B
	set fiscal_2017='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2016-04-01' and '2017-03-31') B
	set fiscal_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2015-04-01' and '2016-03-31') B
	set fiscal_2015='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2014-04-01' and '2015-03-31') B
	set fiscal_2014='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2013-04-01' and '2014-03-31') B
	set fiscal_2013='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2012-04-01' and '2013-03-31') B
	set fiscal_2012='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2011-04-01' and '2012-03-31') B
	set fiscal_2011='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2010-04-01' and '2011-03-31') B
	set fiscal_2010='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2009-04-01' and '2010-03-31') B
	set fiscal_2009='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2008-04-01' and '2009-03-31') B
	set fiscal_2008='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2007-04-01' and '2008-03-31') B
	set fiscal_2007='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2006-04-01' and '2007-03-31') B
	set fiscal_2006='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2005-04-01' and '2006-03-31') B
	set fiscal_2005='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,
	(select eos_user_id from Cust_txns where transact_date between '2004-04-01' and '2005-03-31') B
	set fiscal_2004='Y'
	where A.eos_user_id=B.eos_user_id;


	##############################################         fiscal created Year
	
	/* indicator variable as per fiscal for eos_user created date */

	alter table SVOC
	add column fiscal_created_year varchar(5),

	update SVOC A,
	(select created_date,id from  EOS_USER where type='live' and client_type='individual' ) B
	set fiscal_created_year=
	case when left(created_date,10) between '2002-04-01' and '2003-03-31' then 2002
	when left(created_date,10) between '2003-04-01' and '2004-03-31' then 2003
	when left(created_date,10) between '2004-04-01' and '2005-03-31' then 2004 
	when left(created_date,10) between '2005-04-01' and '2006-03-31' then 2005 
	when left(created_date,10) between '2006-04-01' and '2007-03-31' then 2006 
	when left(created_date,10) between '2007-04-01' and '2008-03-31' then 2007 
	when left(created_date,10) between '2008-04-01' and '2009-03-31' then 2008 
	when left(created_date,10) between '2009-04-01' and '2010-03-31' then 2009 
	when left(created_date,10) between '2010-04-01' and '2011-03-31' then 2010 
	when left(created_date,10) between '2011-04-01' and '2012-03-31' then 2011 
	when left(created_date,10) between '2012-04-01' and '2013-03-31' then 2012 
	when left(created_date,10) between '2013-04-01' and '2014-03-31' then 2013 
	when left(created_date,10) between '2014-04-01' and '2015-03-31' then 2014 
	when left(created_date,10) between '2015-04-01' and '2016-03-31' then 2015 
	when left(created_date,10) between '2016-04-01' and '2017-03-31' then 2016 
	when left(created_date,10) between '2017-04-01' and '2018-03-31' then 2017 
	when left(created_date,10) between '2018-04-01' and '2019-03-31' then 2018 else 'NA' end
	where A.eos_user_id=B.id;

	###########################3

	/* indicator variable as per calendar year for eos_user created date */
	
	alter table SVOC
	add column calendar_2018 varchar(5),
	add column calendar_2017 varchar(5),
	add column calendar_2016 varchar(5),
	add column calendar_2015 varchar(5),
	add column calendar_2014 varchar(5),
	add column calendar_2013 varchar(5),
	add column calendar_2012 varchar(5),
	add column calendar_2011 varchar(5),
	add column calendar_2010 varchar(5),
	add column calendar_2009 varchar(5),
	add column calendar_2008 varchar(5),
	add column calendar_2007 varchar(5),
	add column calendar_2006 varchar(5),
	add column calendar_2005 varchar(5),
	add column calendar_2004 varchar(5);


	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2018) B
	set calendar_2018='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2017) B
	set calendar_2017='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2016) B
	set calendar_2016='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2015) B
	set calendar_2015='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2014) B
	set calendar_2014='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2013) B
	set calendar_2013='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2012) B
	set calendar_2012='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2011) B
	set calendar_2011='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2010) B
	set calendar_2010='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2009) B
	set calendar_2009='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2008) B
	set calendar_2008='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2007) B
	set calendar_2007='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2006) B
	set calendar_2006='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2005) B
	set calendar_2005='Y'
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id from Cust_txns where year(transact_date)=2004) B
	set calendar_2004='Y'
	where A.eos_user_id=B.eos_user_id;


	##################   total value

	/* Obtaining Annualized sum for each customer where  Annualized sum = sum of Lifetime sales/Number of active years  */
	/* we have taken update_transact_year tag for calculating active years for each customer, as we took into consideration Aug-Aug cycle for active years */
	
	##################  Annualized Entire lifetime ############################
	
	alter table SVOC
	add column sum_entire int(10);
	
	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_entire from Cust_txns where transact_date between '2004-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_entire=B.sum_entire
	where A.eos_user_id=B.eos_user_id; /* we are calculating total sales for entire lifetime*/
	
	
	######  Annualized_sum_entire  ###
	
	alter table SVOC
	add column Annualized_sum_entire_F int(10); /* F indicates the variable of Annualized sum*/

	update SVOC A, (select eos_user_id,count(distinct(update_transact_year)) as Distinct_years from Cust_txns where transact_date between '2004-08-29' and '2018-08-28' group by eos_user_id) B
	set Annualized_sum_entire_F=(A.sum_entire)/Distinct_years
	where A.eos_user_id=B.eos_user_id; /* we are calculating Annualized_sum by dividing total sales by active years for entire lifetime*/
	
	##################  one year

	#Annualized_sum_2018

	alter table SVOC 
	add column sum_2018 int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_2018 from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_2018=B.sum_2018
	where A.eos_user_id=B.eos_user_id;/* we are calculating annualized sum for 2018, hence in this case the denominator will be 1 */
  
	alter table SVOC
	add column Annualized_sum_2018_F int(10);

	update SVOC
	set Annualized_sum_2018_F=sum_2018;/* we are calculating annualized sums for 2018,we are calculating annualized sum for 2018, hence in this case the denominator will be 1*/


	################# Annualized_2017_2018

	alter table SVOC
	add column sum_2017_2018 int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_2017_2018 from Cust_txns where transact_date between '2016-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_2017_2018=B.sum_2017_2018/* we are calculating total sales for 2017 and 2018*/
	where A.eos_user_id=B.eos_user_id;

	#Annualized_2017_2018

	alter table SVOC
	add column Annualized_sum_2017_2018 int(10);

	update SVOC A, (select eos_user_id,count(distinct(update_transact_year)) as Distinct_years from Cust_txns where transact_date between '2016-08-29' and '2018-08-28' group by eos_user_id) B
	set Annualized_sum_2017_2018=(A.sum_2017_2018)/B.Distinct_years
	where A.eos_user_id=B.eos_user_id;/* we are calculating annualized sums for 2017 and 2018*/

	

	/* Year on year Annualized sum */
	/*
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2012 int(10);
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2011 int(10);
	alter table SVOC add column Annualized_2012 int(10);
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2011 int(10);
	alter table SVOC add column Annualized_2012 int(10);
	alter table SVOC add column Annualized_2013 int(10);
	alter table SVOC add column Annualized_2014 int(10);
	alter table SVOC add column Annualized_2015 int(10);
	alter table SVOC add column Annualized_2016 int(10);
	alter table SVOC add column Annualized_2017 int(10);
	alter table SVOC add column Annualized_sum_2018 int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2013 from Cust_txns where transact_date between '2004-08-29' and '2005-08-28' group by eos_user_id) B
	set A.Annualized_2005=B.Annualized_2005
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2012 from Cust_txns where transact_date between '2005-08-29' and '2006-08-28' group by eos_user_id) B
	set A.Annualized_2012=B.Annualized_2012
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2013 from Cust_txns where transact_date between '2006-08-29' and '2007-08-28' group by eos_user_id) B
	set A.Annualized_2013=B.Annualized_2013
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2011 from Cust_txns where transact_date between '2010-08-29' and '2011-08-28' group by eos_user_id) B
	set A.Annualized_2011=B.Annualized_2011
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2012 from Cust_txns where transact_date between '2011-08-29' and '2012-08-28' group by eos_user_id) B
	set A.Annualized_2012=B.Annualized_2012
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2013 from Cust_txns where transact_date between '2012-08-29' and '2013-08-28' group by eos_user_id) B
	set A.Annualized_2013=B.Annualized_2013
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2014 from Cust_txns where transact_date between '2013-08-29' and '2014-08-28' group by eos_user_id) B
	set A.Annualized_2014=B.Annualized_2014
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2015 from Cust_txns where transact_date between '2014-08-29' and '2015-08-28' group by eos_user_id) B
	set A.Annualized_2015=B.Annualized_2015
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2016 from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.Annualized_2016=B.Annualized_2016
	where A.eos_user_id=B.eos_user_id;


	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_2017 from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.Annualized_2017=B.Annualized_2017
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as Annualized_sum_2018 from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.Annualized_sum_2018=B.Annualized_sum_2018
	where A.eos_user_id=B.eos_user_id;
	*/
	alter table SVOC
	add column sum_entire int(10),
	add column Annualized_sum_entire int(10);

	update SVOC A,(select eos_user_id,sum(Standardised_Price) as sum_entire from Cust_txns where transact_date between '2004-08-29' and '2018-08-28' group by eos_user_id) B
	set A.sum_entire=B.sum_entire
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(update_transact_year)) as Distinct_years from Cust_txns group by eos_user_id) B
	set Annualized_sum_entire=(A.sum_entire)/B.Distinct_years
	where A.eos_user_id=B.eos_user_id;
	###########################  segment
	
	/* mapping service segment for each Favourite Serivce ( Most frequent service used for each user )*/
	
	
	alter table SVOC
	add column Favourite_service_segment int(5);

	alter table SVOC
	add index(Favourite_service);

	alter table service
	add index(id);

	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment=B.service_segment
	where A.Favourite_service=B.id;



	###########################   Is_delay

	/* Creating indicator variable for each customer, whether that particular customer faced any delay or not */
	
	alter table SVOC
	add column is_delay varchar(2);

	update SVOC A
	set A.is_delay= 'Y'
	where Average_Delay>0;
	
	########################    L1 - SEGMENTATION    ##########################
    
	/* 
	
		L1 Segment - Using ATV and frequency for period 29th August 2017 and 28th August 2018 segmenting customers into 
		1) High Value High Frequency 
		2) High Value Low Frequency
		3) Low Value High Frequency
		4) Low Value Low Frequency
	*/

	alter table SVOC
	add column L1_SEGMENT varchar(5);
	
	UPDATE SVOC
	SET L1_SEGMENT = CASE WHEN ATV_1_year >= 480 AND frequency_1_year>= 3  THEN 'HH'
	WHEN ATV_1_year >= 480 AND frequency_1_year < 3   THEN 'HL'
	WHEN ATV_1_year < 480 AND frequency_1_year >= 3   THEN 'LH'
	WHEN ATV_1_year < 480 AND frequency_1_year < 3   THEN 'LL'
	ELSE NULL END;

	/* 
	
		L2 Segment - Using ATV, monetary value and frequency for period 29th August 2017 and 28th August 2018 segmenting customers into 22 different segments
		Customers not active in the given time period are also considered in the segments 14 to 18 and 21 to 22
	*/
	
	alter table SVOC
	add column L2_SEGMENT varchar(10);

	UPDATE SVOC
	SET L2_SEGMENT = 
	case when recency_1_year between 0 and 50 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '1' 
	when recency_1_year between 0 and 50 and frequency_1_year >= 3  AND ATV_1_year  <480 then '2'
	when recency_1_year between 0 and 50 and frequency_1_year =2 then '3'
	when recency_1_year between 51 and 100 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '4' 
	when recency_1_year between 51 and 100 and frequency_1_year >= 3  AND ATV_1_year  <480 then '5'
	when recency_1_year between 51 and 100 and frequency_1_year =2 then '6'
	when recency_1_year between 101 and 150 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '7' 
	when recency_1_year between 101 and 150 and frequency_1_year >= 3  AND ATV_1_year  <480 then '8'
	when recency_1_year between 101 and 150 and frequency_1_year =2 then '9'
	when recency_1_year between 151 and 250 and frequency_1_year>=3 then '10' 
	when recency_1_year between 151 and 250 and frequency_1_year=2 then '11'
	when recency_1_year between 251 and 365   and frequency_1_year>=3 then '12' 
	when recency_1_year between 251 and 365    and frequency_1_year=2 then '13'
	when Recency between 365 and 500 and Frequency >=4 and ATV_entire>=480 then '14'
	when Recency between 365 and 500 and Frequency >=4 and ATV_entire<480 then '15'
	when Recency between 365 and 500 and Frequency BETWEEN 2 and 3 then '16'
	when Recency between 500 and 730 and Frequency >1 then '17'
	when Recency > 730  and Frequency >1 then '18'  
	WHEN recency_1_year < 365 AND ATV_1_year >=480 and frequency_1_year=1 THEN '19' 
	WHEN recency_1_year < 365 AND ATV_1_year <480 and frequency_1_year =1 THEN '20' 
	when Recency >= 365 AND ATV_entire  >=480 and Frequency =1 THEN '21'
	WHEN Recency >= 365 AND ATV_entire  <480 and Frequency=1 THEN '22' 
	ELSE NULL END; 
	
	
	/* 
	
		Combining previous L2 Segments into 18 different segments
	*/

	
	ALTER TABLE SVOC add column  L2_SEGMENT_new varchar(2);
	UPDATE SVOC
	SET L2_SEGMENT_new = 
	case when recency_1_year between 0 and 50 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '1' 
	when recency_1_year between 0 and 50 and frequency_1_year >= 3  AND ATV_1_year  <480 then '2'
	when recency_1_year between 0 and 50 and frequency_1_year =2 then '3'
	when recency_1_year between 51 and 150 and frequency_1_year >= 3 AND ATV_1_year  >=480 then '4' 
	when recency_1_year between 51 and 150 and frequency_1_year >= 3  AND ATV_1_year  <480 then '5'
	when recency_1_year between 51 and 150 and frequency_1_year =2 then '6'
	when recency_1_year between 151 and 365 and frequency_1_year>=3 then '7' 
	when recency_1_year between 151 and 365 and frequency_1_year=2 then '8'
	when Recency between 365 and 730 and Frequency >1  then '9'
	when Recency > 730  and Frequency >1 then '10'  
	WHEN recency_1_year < 365  AND frequency_1_year=1 THEN '11' 
	WHEN Recency >= 365 and Frequency=1 THEN '12' 
	ELSE NULL END; 

    /* L2_SEGMENT for 2015-2016  we are using frequency,ATV and recency cutoffs as we did for 2017-2018 */
	
	AlTER TABLE SVOC add column  L2_SEGMENT_new_2015_2016 varchar(2);
	
	set sql_safe_updates=0;
    UPDATE SVOC
	SET L2_SEGMENT_new_2015_2016 = 
	case when Recency_2015_2016_year between 0 and 50 and frequency_2015_2016_year >= 3 AND ATV_2015_2016_year  >=480 then '1' 
	when Recency_2015_2016_year between 0 and 50 and frequency_2015_2016_year >= 3  AND ATV_2015_2016_year  <480 then '2'
	when Recency_2015_2016_year between 0 and 50 and frequency_2015_2016_year =2 then '3'
	when Recency_2015_2016_year between 51 and 150 and frequency_2015_2016_year >= 3 AND ATV_2015_2016_year  >=480 then '4' 
	when Recency_2015_2016_year between 51 and 150 and frequency_2015_2016_year >= 3  AND ATV_2015_2016_year  <480 then '5'
	when Recency_2015_2016_year between 51 and 150 and frequency_2015_2016_year =2 then '6'
	when Recency_2015_2016_year between 151 and 365 and frequency_2015_2016_year>=3 then '7' 
	when Recency_2015_2016_year between 151 and 365 and frequency_2015_2016_year=2 then '8'
	when Recency between 365 and 730 and Frequency >1  then '9'
	when Recency > 730  and Frequency >1 then '10'  
	WHEN Recency_2015_2016_year < 365  AND frequency_2015_2016_year=1 THEN '11' 
	WHEN Recency >= 365 and Frequency=1 THEN '12' 
	ELSE NULL END; 
	
	 /* L2_SEGMENT for 2016-2017, we are using frequency,ATV and recency cutoffs as we did for 2017-2018 */
	
	ALTER TABLE SVOC add column  L2_SEGMENT_new_2016_2017 varchar(2);
	UPDATE SVOC
	SET L2_SEGMENT_new_2016_2017 = 
	case when Recency_2016_2017_year between 0 and 50 and frequency_2016_2017_year >= 3 AND ATV_2016_2017_year  >=480 then '1' 
	when Recency_2016_2017_year between 0 and 50 and frequency_2016_2017_year >= 3  AND ATV_2016_2017_year  <480 then '2'
	when Recency_2016_2017_year between 0 and 50 and frequency_2016_2017_year =2 then '3'
	when Recency_2016_2017_year between 51 and 150 and frequency_2016_2017_year >= 3 AND ATV_2016_2017_year  >=480 then '4' 
	when Recency_2016_2017_year between 51 and 150 and frequency_2016_2017_year >= 3  AND ATV_2016_2017_year  <480 then '5'
	when Recency_2016_2017_year between 51 and 150 and frequency_2016_2017_year =2 then '6'
	when Recency_2016_2017_year between 151 and 365 and frequency_2016_2017_year>=3 then '7' 
	when Recency_2016_2017_year between 151 and 365 and frequency_2016_2017_year=2 then '8'
	when Recency between 365 and 730 and Frequency >1  then '9'
	when Recency > 730  and Frequency >1 then '10'  
	WHEN Recency_2016_2017_year < 365  AND frequency_2016_2017_year=1 THEN '11' 
	WHEN Recency >= 365 and Frequency=1 THEN '12' 
	ELSE NULL END; 
	
	################      CAMPAIGN DATA  ##############

	/* Adding campaign variables for each customer based on aditya's mail of 10th October 2018 */

	create table hub 
	(Client_code varchar(10),
	First_Name varchar(25),
	Last_Name varchar(25),
	Partner int(5),
	Recent_Sales_Email_Replied_Date date,
	Type_of_Client varchar(15),
	Sends_Since_Last_Engagement int(5),
	Emails_Delivered int(5),
	Emails_Opened int(5),
	Emails_Clicked int(5),
	Emails_Bounced int(5),
	Unsubscribed_from_of_all_email varchar(1),
	Last_email_name varchar(100),
	Last_email_send_date date,
	Last_email_open_date date,
	Last_email_click_date date,
	First_email_send_date date,
	First_email_open_date date,
	First_email_click_date date
	);


	LOAD DATA LOCAL INFILE '/opt/cactusops/hub_spot.csv' IGNORE INTO TABLE hub
	FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
	LINES TERMINATED BY '\r\n'
	IGNORE 1 LINES
	(	
		Client_code ,
	First_Name ,
	Last_Name ,
	Partner ,
	Recent_Sales_Email_Replied_Date ,
	Type_of_Client ,
	Sends_Since_Last_Engagement ,
	Emails_Delivered ,
	Emails_Opened ,
	Emails_Clicked ,
	Emails_Bounced ,
	Unsubscribed_from_of_all_email ,
	Last_email_name ,
	Last_email_send_date ,
	Last_email_open_date ,
	Last_email_click_date ,
	First_email_send_date ,
	First_email_open_date ,
	First_email_click_date
	);

	/* adding campaign variables in the SVOC */

	alter table SVOC add column Client_code varchar(10) ;
	alter table SVOC add column First_Name varchar(25) ;
	alter table SVOC add column Last_Name varchar(25) ;
	alter table SVOC add column Partner int(5) ;
	alter table SVOC add column Recent_Sales_Email_Replied_Date date ;
	alter table SVOC add column Type_of_Client varchar(15) ;
	alter table SVOC add column Sends_Since_Last_Engagement int(5) ;
	alter table SVOC add column Emails_Delivered int(5) ;
	alter table SVOC add column Emails_Opened int(5) ;
	alter table SVOC add column Emails_Clicked int(5) ;
	alter table SVOC add column Emails_Bounced int(5) ;
	alter table SVOC add column Unsubscribed_from_of_all_email varchar(10) ;
	alter table SVOC add column Last_email_name varchar(100) ;
	alter table SVOC add column Last_email_send_date date ;
	alter table SVOC add column Last_email_open_date date ;
	alter table SVOC add column Last_email_click_date date ;
	alter table SVOC add column First_email_send_date date ;
	alter table SVOC add column First_email_open_date date ;
	alter table SVOC add column First_email_click_date date ;


	alter table SVOC add index(client_code);
	
	/* Hub is the hubspot campaign data  aggregated at the date level, which was given by the cacus team */
	
	alter table hub add index(client_code);

	update SVOC A,hub B set A.Recent_Sales_Email_Replied_Date=B.Recent_Sales_Email_Replied_Date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Sends_Since_Last_Engagement=B.Sends_Since_Last_Engagement where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Delivered=B.Emails_Delivered where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Opened=B.Emails_Opened where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Clicked=B.Emails_Clicked where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Emails_Bounced=B.Emails_Bounced where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Unsubscribed_from_of_all_email=B.Unsubscribed_from_of_all_email where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_name=B.Last_email_name where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_send_date=B.Last_email_send_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_open_date=B.Last_email_open_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.Last_email_click_date=B.Last_email_click_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.First_email_send_date=B.First_email_send_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.First_email_open_date=B.First_email_open_date where A.Client_code=B.Client_code;
	update SVOC A,hub B set A.First_email_click_date=B.First_email_click_date where A.Client_code=B.Client_code;


	#######################     NEW_VARIABLES   HUBSPOT

	/* Derived Variables from campaign data */

	alter table SVOC add column Communication_tenure int(8),
	add column Communication_recency int(8),
	add column Was_last_mail_opened varchar(2),
	add column Open_rate double,
	add column Click_rate double, 
	add column Order_by_send_ratio double,
	add column Order_by_open_ratio double,
	add column Last_order_email int(8); 

	/*calculating tenure of campaign related communication for each customer */

	 update SVOC 
	 set Communication_tenure=datediff(Last_email_send_date,First_email_send_date);
	 
	/*calculating days since latest communication for each customer */
	 
	 update SVOC 
	 set Communication_recency=datediff(Last_email_send_date,'2018-08-28');

	 
	 /* Identifying whether last email was opened by the customer or not */
	 
	update SVOC 
	 set Was_last_mail_opened=
	 case when Last_email_open_date>Last_email_send_date
	 then 'Y' else 'N' end
	 where Last_email_open_date is not null and Last_email_send_date is not null;
	 
	 /* Percentage of the mails opened by the customer */
	 
	 update SVOC
	 set Open_rate=round((Emails_Opened/Emails_Delivered),3);
	 
	 /* Percentage of the mails clicked by the customer */
	 
	 update SVOC
	 set Click_rate=round((Emails_Clicked/Emails_Delivered),3);
	 
	 /* Ratio frequency of the customer to the emails delivered of the customer */
	 
	 update SVOC 
	 set Order_by_send_ratio=round((Frequency/Emails_Delivered),2);

	 /* Ratio frequency of the customer to the emails opened of the customer */
	 
	 update SVOC 
	 set Order_by_open_ratio=round((Frequency/Emails_Opened),2);
	 
	 /* Difference between the Last Transaction date of the customer and last email send date */
	 
	  update SVOC 
	 set Last_order_email=datediff(LTD,Last_email_send_date);
		
		#### TimeforJobCompletion ####

		/* computing the time taken for completion for each order */
		
	 alter table Cust_txns 
	 add column TimeForJobCompletion bigint;
	 
	 Update Cust_txns as A, 
	 (select ConfirmDate.id, TIMESTAMPDIFF(SECOND,ConfirmDate.ConfirmDate,SendToClientDate.SendToClientDate) as TimeToCompleteJob
	 from 
	 (SELECT id, min(confirmed_date) as ConfirmDate FROM
	 (SELECT id,sent_to_client_date,confirmed_date,type,component_type,parent_id
	 FROM component
	 order by id) B
	 where parent_id IS NULL
	 GROUP BY id) AS ConfirmDate JOIN
	 ( SELECT parent_id, max(sent_to_client_date) as SendToClientDate FROM
	 (SELECT id,sent_to_client_date,confirmed_date,type,component_type,parent_id
	 FROM component
	 order by id) B
	 where parent_id IS NOT NULL
	 GROUP BY parent_id) as SendToClientDate
	 ON ConfirmDate.id = SendToClientDate.parent_id) as TIMETABLE
	 SET A.TimeForJobCompletion =TIMETABLE.TimeToCompleteJob
	 where A.component_id=TIMETABLE.id
	 ;
	
	
	############## Updating Avg_days_for_jobCompl in SVOC ##############
	
	ALTER TABLE SVOC
	add column Avg_days_for_jobCompl int; 

	UPDATE SVOC A, 
	(SELECT eos_user_id, Cast(Avg(TimeForJobCompletion)/(3600*24) as int) as Avg_Time_for_Compl  FROM Cust_txns
	WHERE left(Created_date, 10) > '2015-08-28'
	GROUP BY eos_user_id) as ComplTimeTable
	set A.Avg_days_for_jobCompl = ComplTimeTable.Avg_Time_for_Compl
	WHERE A.eos_user_id = ComplTimeTable.eos_user_id;

	 ############
	 # 4. First_subject_in_top_subject_areas (Is the subject in first transaction is in top subjects)
	-- # Is_in_top_sub_Area (Is subject_area_id in top Subject Areas) in Cust_txns
	
	/* Indicator variable whether the customer's subject area is among the top subject areas */
	
	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area varchar(2) default 'N',

	UPDATE Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,1088,524,742,921,1072,1075,1388,168,207,500,528,554,560,597,616,710,812,827,840,861,863,898,914,935,936,979,1016,1018,1053,1078,1127,1155,1173,1183,1219,1223,1240,1274,1326,1391,1394,1422,1456,1496,2062,858,962,1265,161,1190,196,689,705,799,922,934,1021,1259,1387,1414,1446,1460,604,804,1095,1296,630,247,214,942,1564,888,1325,290,1405,1157,1312,797,1567,598,1070,628,824,205,573,41,600,932,1220,474,481,502,523,590,612,624,632,682,709,819,826,866,868,881,893,967,1017,1038,1152,1199,1225,1241,1243,1340,1351,1354,1364,1462,1467,1573,303,1092,1282);
	
	/* Indicator variable whether the customer's subject area is among the top subject areas for the time period 2015-2016*/
	
	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2015_2016 varchar(2) default 'N',

	UPDATE SVOC  
	SET Is_in_top_sub_Area_2015_2016 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area = 'Y' and transact_date BETWEEN '2015-08-29' AND '2016-08-28');
	
	/* Indicator variable whether the customer's First subject area is among the top subject areas for the time period 2015-2016*/
	
	ALTER TABLE SVOC
	ADD Column First_subject_in_top_subject_areas varchar(2) default 'N';

	UPDATE SVOC A, Cust_txns B
	set A.First_subject_in_top_subject_areas = 'Y'
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.Is_in_top_sub_Area = 'Y';
		
	/* Adding  Revision variables for each customer */
	
	#####################     revision table
	/* mapping enquiry_id for each order in the revisions table */
	
	alter table content_type_enquiry add index(nid);
	alter table migration add index(whiteboard_id);

	update content_type_enquiry A,migration B
	set A.enquiry_id=B.crm_id
	where A.nid=B.whiteboard_id and B.whiteboard_table='enquiry';

	/* Calculating revision tags for each enquiry from revision data */
	
	/* For each node id calculating earliest version id and the latest version id */
	
	create temporary table revise as
	select A.* from
	content_type_enquiry A,
	(select nid,min(vid) as first_revision,max(vid) as last_revision from content_type_enquiry
	group by nid) B
	where (vid=first_revision or vid=last_revision) and A.nid=B.nid;


	alter table content_type_enquiry add index(vid),add index(nid);

	/* 
	
	we are measuring revision in four cases 
	1) price_after_tax
	2) subject_area
	3) service_id
	4) delivery_date 
	
	*/
	alter table enquiry add column Revision_in_subject_area varchar(2),add column Revision_in_price_after_tax varchar(2),add column Revision_in_service_id varchar(2),add column Revision_in_delivery_date varchar(2),add index(id);

	alter table revise add index(nid,vid),add index(enquiry_id),add index(enquiry_id);

	/* For calculating revision in one particular field for example, subject area we measure whether field_enquiry_subjectarea_value for earliest version id is different from the latest version id for each node id, if it is true then we define that revision existed in the enquiry */
	
	# 1  Subject

	create temporary table subject as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_subjectarea_value <>
		  ( SELECT b.field_enquiry_subjectarea_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
		  
	set sql_safe_updates=0;
	alter table subject add index(enquiry_id);

	update enquiry A,subject B
	set Revision_in_subject_area='Y' where A.id=B.enquiry_id;

		  

	#  2 price_after_tax
	 
	create temporary table price_after_tax as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_price_after_tax_value <>
		  ( SELECT b.field_enquiry_price_after_tax_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table price_after_tax add index(enquiry_id);
	  
	update enquiry A,price_after_tax B
	set Revision_in_price_after_tax='Y' where A.id=B.enquiry_id;


	# 3 Service
	 
	create temporary table service as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_service_nid <>
		  ( SELECT b.field_enquiry_service_nid
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table service add index(enquiry_id);
	  
	update enquiry A,service B
	set Revision_in_service_id='Y' where A.id=B.enquiry_id;


	#  4   Delivery Date

	create temporary table delivery_date as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_delivery_date_value <>
		  ( SELECT b.field_enquiry_delivery_date_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table delivery_date add index(enquiry_id);
	  
	update enquiry A,delivery_date B
	set Revision_in_delivery_date='Y' where A.id=B.enquiry_id;


	#  5 words

	alter table enquiry add column Revision_in_words varchar(2);
	create temporary table words as
	(SELECT distinct a.enquiry_id
	FROM revise AS a
	WHERE a.field_enquiry_unit_count_value <>
		  ( SELECT b.field_enquiry_unit_count_value
			FROM revise AS b
			WHERE a.nid= b.nid
			  AND a.vid < b.vid
		  ));
	set sql_safe_updates=0;
	alter table words add index(enquiry_id);
	  
	update enquiry A,words  B
	set Revision_in_words='Y' where A.id=B.enquiry_id;
	
	
-- Updating Revision variables in Cust_txns from enquiry 

	alter table Cust_txns add column Revision_in_subject_area varchar(2);
	alter table Cust_txns add column Revision_in_price_after_tax varchar(2);
	alter table Cust_txns add column Revision_in_service_id varchar(2);
	alter table Cust_txns add column Revision_in_delivery_date varchar(2);
	alter table Cust_txns add column Revision_in_words varchar(2);

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	UPDATE Cust_txns A, enquiry B
	set A.Revision_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A.enquiry_id = B.id;

	-- Updating Revision variables in SVOC from Cust_txns


	ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area int,
	add column No_of_Revision_in_price_after_tax int,
	add column No_of_Revision_in_service_id int,
	add column No_of_Revision_in_delivery_date int,
	add column No_of_Revision_in_words int;
	
	
	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;
			
	


	ALTER TABLE SVOC
	add column ratio_of_Revision_in_subject_area_2016_2017 double,
	add column ratio_of_Revision_in_price_after_tax_2016_2017 double,
	add column ratio_of_Revision_in_service_id_2016_2017 double,
	add column ratio_of_Revision_in_delivery_date_2016_2017 double,
	add column ratio_of_Revision_in_words_2016_2017 double;

	update SVOC
	set 
	ratio_of_Revision_in_subject_area_2016_2017 =No_of_Revision_in_subject_area_2016_2017/frequency_2016_2017_year
	,ratio_of_Revision_in_price_after_tax_2016_2017 =No_of_Revision_in_price_after_tax_2016_2017/frequency_2016_2017_year,
	ratio_of_Revision_in_service_id_2016_2017 =No_of_Revision_in_service_id_2016_2017/frequency_2016_2017_year,
	ratio_of_Revision_in_delivery_date_2016_2017 =No_of_Revision_in_delivery_date_2016_2017/frequency_2016_2017_year,
	ratio_of_Revision_in_words_2016_2017=No_of_Revision_in_words_2016_2017/frequency_2016_2017_year;


	alter table SVOC 
	add column No_of_premium_orders_2016_2017 int(5),add column No_of_non_premium_orders_2016_2017 int(5);

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' and Premium='Yes' group by eos_user_id) B
	set A.No_of_premium_orders_2016_2017=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC add column No_of_non_premium_orders int(5);

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where transact_date between '2016-08-29' and '2017-08-28'  and Premium='No' group by eos_user_id) B
	set A.No_of_non_premium_orders_2016_2017=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC 
	add column Ratio_of_premium_to_total_2016_2017 double,add column Ratio_of_non_premium_to_total_2016_2017 double;

	update SVOC
	set Ratio_of_premium_to_total_2016_2017=(No_of_premium_orders_2016_2017)/(frequency_2016_2017_year);

	update SVOC
	set Ratio_of_non_premium_to_total_2016_2017=(No_of_non_premium_orders_2016_2017)/(frequency_2016_2017_year);

	alter table SVOC
	add column Ratio_of_premium_to_total_2016_2017_band varchar(10);

	update SVOC
	set Ratio_of_premium_to_total_2016_2017_band=
	case when (Ratio_of_premium_to_total_2016_2017 between 0 and 0.1 or Ratio_of_premium_to_total_2016_2017 
	is null) then '0% - 10%' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.1 and 0.2 then '10% -20% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.2 and 0.3 then '20% -30% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.3 and 0.4 then '30% - 40%' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.4 and 0.5 then '40% -50% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.5 and 0.6 then '50% -60% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.6 and 0.7 then '60% - 70%' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.7 and 0.8 then '70% - 80% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.8 and 0.9 then '80% - 90% ' else
	case when Ratio_of_premium_to_total_2016_2017 between 0.9 and 1 then '90% - 100% ' else null
	end end end end end end end end end end;

	######################     new variables created - nov 9

	alter table SVOC  add column enquiry_job_ratio double,paid_mre_percent_to_total double,distinct_translators int(3);		
	alter table SVOC  add column (enquiry_job_ratio double,paid_mre_percent_to_total double,distinct_translators int(3));
	
	# Distinct Translators /* Distinct wb_user_ids allocated for a customer */

	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators from Cust_txns group by eos_user_id) B
	set A.distinct_translators=B.distinct_translators
	where A.eos_user_id=B.eos_user_id;/* Lifetime different types of translators for each customer */

	alter table SVOC add column distinct_translators_2015_2016 int;
	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators_2015_2016 from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.distinct_translators_2015_2016=B.distinct_translators_2015_2016
	where A.eos_user_id=B.eos_user_id; /* Different types of translators for each customer in the time period 2015-08-29 and 2016-08-28*/

	
	# Enquiry_job
	
	/* Number of valid orders to the number of enquiries calculated for each customer */
	
	update SVOC A,(select B.eos_user_id,count(case when component_type='job' and price_after_tax is not null and price_after_tax>0 and type='normal' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio=A.Frequency/B.enquiries
	where A.eos_user_id=B.eos_user_id;
	
	/* Number of valid orders to the number of enquiries calculated for each customer for 2015-2016 (Aug-Aug cycle*/
	
	alter table SVOC add column enquiry_job_ratio_2015_2016 double; 
	update SVOC A,(select B.eos_user_id,count(case when  component_type='job' and price_after_tax is not null and price_after_tax>0type='normal' and left(A.created_date,10) between '2015-08-29' and '2016-08-28' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio_2015_2016=A.frequency_2015_2016_year/B.enquiries
	where A.eos_user_id=B.eos_user_id;
	
	/* 2015_2016 RFM variables year */
	
	alter table SVOC
	add column  ATV_2015_2016_year int(10),
	add column frequency_2015_2016_year int(4),
	add column Recency_2015_2016_year int(5),
	add column FTD_2015_2016_years date,
	add column LTD_2015_2016_years date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') B group by eos_user_id) B
	set A.FTD_2015_2016_years=B.FTD_1_years,A.LTD_2015_2016_years=B.LTD_1_years,A.frequency_2015_2016_year=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id ;

	update SVOC A,(select eos_user_id,avg(case when transact_date between '2015-08-29' and '2016-08-28' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_2015_2016_year=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_2015_2016_year=datediff('2016-08-28',LTD_2015_2016_years)
	where frequency_2015_2016_year is not null;
    
	alter table SVOC
    add column ADGBT_2015_2016_year int(5),
    add column Inactivity_ratio_2015_2016_year double,
    add column STD_2015_2016_year date,
    add column Bounce_2015_2016_year int(11),
    add column Total_Standard_price_2015_2016_year decimal(18,6);
    
	update SVOC
	set ADGBT_2015_2016_year=datediff(LTD_2015_2016_years,FTD_2015_2016_years)/(frequency_2015_2016_year-1)
	 where (Sept_2016='Y' ) and frequency_2015_2016_year is not null;

	update SVOC
	set Inactivity_ratio_2015_2016_year = Recency_2015_2016_year/ADGBT_2015_2016_year;

	set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_2015_2016_year = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2015-08-29' and '2016-08-28'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_2015_2016_year > 1 ;
            
	update SVOC
	set Bounce_2015_2016_year = datediff(STD_2015_2016_year,FTD_2015_2016_years)
	where frequency_2015_2016_year>1 and STD_2015_2016_year is not null;
    
	update SVOC A,(select eos_user_id,
	sum(case when transact_date between '2015-08-29' and '2016-08-28' then Standardised_Price end) as Total_Standard_price_2015_2016_year 
	from Cust_txns  group by eos_user_id) B
		set A.Total_Standard_price_2015_2016_year=B.Total_Standard_price_2015_2016_year
	where A.eos_user_id=B.eos_user_id;
    
	######################		Premium			#########################

	/* Mapping service with the premium service */  
	
	alter table service add column Premium varchar(5);

	update service  A, premium B
	set A.Premium =B.Premium 
	where A.name=B.Name;

	alter table Cust_txns
	add column Premium varchar(5);

	update Cust_txns  A, service B
	set A.Premium =B.Premium 
	where A.service_id=B.id;

	/* 
	No_of_premium_orders - total premium orders by the customer 
	No_of_non_premium_orders - total non-premium orders by the customer 
	Ratio_of_premium_to_non_premium - (No_of_premium_orders)/(No_of_non_premium_orders)
	first_order_premium - indicator variable for each customer whether first order by customer is a premium order
	*/
	
	alter table SVOC 
	add column No_of_premium_orders int(5),add column No_of_non_premium_orders int(5),add column Ratio_of_premium_to_non_premium double,add column first_order_premium varchar(2) default 'N';

	
	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where Premium='Yes' group by eos_user_id) B
	set A.No_of_premium_orders=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where Premium='No' group by eos_user_id) B
	set A.No_of_non_premium_orders=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC
	set Ratio_of_premium_to_non_premium=(No_of_premium_orders)/(No_of_non_premium_orders);

	update SVOC A,Cust_txns B
	set A.first_order_premium ='Y'
	where A.FTD=B.transact_date and A.eos_user_id=B.eos_user_id and B.Premium='Yes';
	/* for mapping first transaction order for customer we equate the FTD of the customer with the transact_date of the customer, this practice automatically maps details of FTD with the first transact_date */

	
	/* To identify whether the customer has ever transacted */
	
	 alter table SVOC
	 add column is_ever_premium_buyer varchar(2) default 'N';
	 
	 update SVOC A,(select distinct eos_user_id from Cust_txns where Premium='Yes') B
	 set A.is_ever_premium_buyer='Y'
	 where A.eos_user_id=B.eos_user_id;
	 
	 /* 
		
	No_of_premium_orders_2017_2018 - total premium orders by the customer for 17-18 Aug-Aug cycle
	No_of_non_premium_orders_2017_2018 - total non-premium orders by the customer for 17-18 Aug-Aug cycle
	Ratio_of_premium_to_non_premium_2017_2018 - (No_of_premium_orders)/(No_of_non_premium_orders) for 17-18 Aug-Aug cycle
	
	*/

	alter table SVOC 
	add column No_of_premium_orders_2017_2018 int(5),add column No_of_non_premium_orders_2017_2018 int(5),add column Ratio_of_premium_to_non_premium_2017_2018 double;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_premium_orders from Cust_txns where Premium='Yes' and transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.No_of_premium_orders_2017_2018=B.No_of_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as No_of_non_premium_orders from Cust_txns where Premium='No' and transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.No_of_non_premium_orders_2017_2018=B.No_of_non_premium_orders
	where A.eos_user_id=B.eos_user_id;

	update SVOC
	set Ratio_of_premium_to_non_premium_2017_2018=(No_of_premium_orders_2017_2018)/(No_of_non_premium_orders_2017_2018);

	
		

	###########################              fill_rate

	/* fill rating is the ratio of the cases where rating was not null divided by the total orders */
	
	alter table SVOC add column fill_rating_2017_2018 double;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as fill_rating_2017_2018 from Cust_txns where rate is not null and transact_date between '2017-08-29'
	 and '2018-08-28' group by eos_user_id) B
	 set A.fill_rating_2017_2018=(B.fill_rating_2017_2018)/A.frequency_1_year
	 where A.eos_user_id=B.eos_user_id;/*fill rating with order in the period 29th Aug 2017 to 28th Aug 2018 */


	alter table SVOC add column fill_rating_2016_2017 double;

	update SVOC A,(select eos_user_id,count(distinct enquiry_id) as fill_rating_2016_2017 from Cust_txns where rate is not null and transact_date between '2016-08-29'
	 and '2017-08-28' group by eos_user_id) B
	 set A.fill_rating_2016_2017=(B.fill_rating_2016_2017)/A.frequency_2016_2017_year
	 where A.eos_user_id=B.eos_user_id;/*fill rating with order in the period 29th Aug 2016 to 28th Aug 2017 */
	
	/* 
	Mapping translated name for each university to the respective user
	User_University - is a table which contains translated_name of each university 
	
	- eos_user_id, partner_id, original_name, translated_name
	So we map each eos_user_id with the translated University_name 
	
	*/

	alter table SVOC
	add column University_name varchar(500);

	update SVOC A,User_University B
	set A.University_name=B.TranslatedName
	where A.eos_user_id=B.eos_user_id;


	#############################    Feedback CLassifier
	
	/*
	feedback classifier - we have created this variable for the time period 2016-08-29 and 2017-08-28
	Creating indicator variables based on the rating history of the customer 
	If the customer has single rating as outstanding then we tag as '3'
	If the customer has single rating as not rated cases then we tag as '1'
	If the customer has single rating as acceptable or not-acceptable then we tag '2'
	If the customer has rated twice, as Outstanding and Not-Rated then we tag '3'
	Rest all cases are tagged as '2'
	*/
	
	drop table distinct_rating_16_17;
	create temporary table distinct_rating_16_17 as
	select eos_user_id,count(distinct IFNULL(rate,0)) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' 
	group by eos_user_id;

	alter table distinct_rating_16_17
	add column O varchar(2) default 'N',
	add column A varchar(2) default 'N',
	add column NA varchar(2) default 'N',
	add column NR varchar(2) default 'N';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.O='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate='outstanding';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.A='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate='acceptable';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.NA='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate='not-acceptable';

	set sql_safe_updates=0;
	update distinct_rating_16_17 A,(select * from  Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
	set A.NR='Y'
	where 
	A.eos_user_id=B.eos_user_id and B.rate is null;

	alter table SVOC
	add column Feedback_Classifier varchar(3);

	update SVOC A,distinct_rating_16_17 B
	set A.Feedback_Classifier=
	case when 
	B.rate =1 and O='Y' then '3' else
	case when
	B.rate =1 and NR='Y' then '1' else
	case when
	B.rate =1 and (NA='Y' or A='Y') then '2' else
	case when 
	B.rate =2 and (O='Y' and NR='Y') then '3' else '2'
	end end end end 
	where 
	A.eos_user_id=B.eos_user_id;


	##################   creating variables for 2016-2017     ##########################
	
	alter table SVOC add column percent_not_acceptable_cases_2016_2017 float(2);
	alter table SVOC add column percent_acceptable_cases_2016_2017 double;
	alter table SVOC add column percent_not_rated_cases_2016_2017 double;
	alter table SVOC add column percent_outstanding_cases_2016_2017 double;
	alter table SVOC add column percent_discount_cases_2016_2017 double;
	alter table SVOC add column percent_delay_cases_2016_2017 double;
	alter table SVOC add column Range_of_services_2016_2017 int(5);
	alter table SVOC add column Range_of_subjects_2016_2017 int(5);
	alter table SVOC add column Average_word_count_2016_2017 int(5);
	alter table SVOC add column Average_Delay_2016_2017 int(5);
	alter table SVOC add column Favourite_Week_number_2016_2017 varchar(2);
	alter table SVOC add column Favourite_Month_2016_2017 varchar(2);
	alter table SVOC add column Favourite_Time_2016_2017 varchar(4);
	alter table SVOC add column Favourite_Day_Week_2016_2017 varchar(2);
	alter table SVOC add column maximum_rating_2016_2017 varchar(20);
	alter table SVOC add column Range_of_subjects_1_6_2016_2017 int(5);

	update SVOC A,(select eos_user_id,count(distinct SA1_6_id) as Range_of_subjects_1_6_2016_2017 from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.Range_of_subjects_1_6_2016_2017=B.Range_of_subjects_1_6_2016_2017
	where
	A.eos_user_id=B.eos_user_id;
	
	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2016_2017=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_acceptable_cases_2016_2017 =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_not_rated_cases_2016_2017=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_outstanding_cases_2016_2017=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_discount_cases_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.percent_delay_cases_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.Range_of_services_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.Range_of_subjects_2016_2017= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B 
	set A.Average_word_count_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.Average_Delay_2016_2017= B.rate
	where A.eos_user_id=B.eos_user_id;


	UPDATE IGNORE
				SVOC A
			SET Favourite_Week_number_2016_2017=(
	SELECT 
							Week_number
						FROM (select eos_user_id,Week_number,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Week_number order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id 
						ORDER BY ratings desc,sum desc
						LIMIT 1);
	UPDATE IGNORE
				SVOC A
			SET Favourite_Month_2016_2017=(
	SELECT 
							Favourite_Month
						FROM (select eos_user_id,Favourite_Month,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Favourite_Month order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
	UPDATE IGNORE
				SVOC A
			SET Favourite_Day_Week_2016_2017=(
	SELECT 
							Favourite_Day_Week
						FROM (select eos_user_id,Favourite_Day_Week,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Favourite_Day_Week order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
						
	 UPDATE IGNORE
				SVOC A
			SET Favourite_Time_2016_2017=(
	SELECT 
							Favourite_Time
						FROM (select eos_user_id,Favourite_Time,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,Favourite_Time order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);


	UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2016_2017 = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

		SELECT eos_useR_id, maximum_rating_2016_2017 FROM SVOC
		WHERE eos_user_id = 228307;
	   

	alter table SVOC
		add column percent_offer_cases_2016_2017 int(8);

		update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
		set A.percent_offer_cases_2016_2017=B.percent_offer_cases 
		where A.eos_user_id=B.eos_user_id;
		
		
		alter table SVOC add column 
		Number_of_times_rated_2016_2017 int(5);
		
		update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
		set Number_of_times_rated_2016_2017=rate_count
		where A.eos_user_id=B.eos_user_id;
		
		alter table SVOC add column is_delay_2016_2017 varchar(2);
		
		update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2016-08-29' and '2017-08-28') B
		set is_delay_2016_2017='Y'
		where Average_Delay_2016_2017 >0  and Average_Delay_2016_2017 is not null and A.eos_user_id=B.eos_user_id;

		
	#################    Favourite Service

		alter table SVOC
		add column Favourite_service_segment_2016_2017 int(5);

		alter table service
		add index(id);

	alter table SVOC add column Favourite_service_2016_2017 varchar(20);
		 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_service_2016_2017=(
						SELECT 
							service_id
						FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,service_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

		set sql_safe_updates=0;
		update SVOC A,service B
		set A.Favourite_service_segment_2016_2017=B.service_segment
		where A.Favourite_service_2016_2017=B.id;	
		

	##### 

	ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area_2016_2017 int,
	add column No_of_Revision_in_price_after_tax_2016_2017 int,
	add column No_of_Revision_in_service_id_2016_2017 int,
	add column No_of_Revision_in_delivery_date_2016_2017 int,
	add column No_of_Revision_in_words_2016_2017 int;


	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area_2016_2017 = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax_2016_2017 = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id_2016_2017 = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date_2016_2017 = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	where transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words_2016_2017 = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;
 
	ALTER TABLE SVOC
	add column Favourite_subject_2016_2017 int(11),
	add column Favourite_SA1_name_2016_2017 varchar(100) ,
	add column Favourite_SA1_5_name_2016_2017 varchar(100),
	add column Favourite_SA1_6_name_2016_2017 varchar(100);

	/*ALTER TABLE SVOC
	change Favourite_SA1_name_2016_2017 Favourite_SA1_name_2016_2017 varchar(100),
	change Favourite_SA1_5_name_2016_2017 Favourite_SA1_5_name_2016_2017 varchar(100),
	change Favourite_SA1_6_name_2016_2017 Favourite_SA1_6_name_2016_2017 varchar(100);*/



	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2016_2017 = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2016_2017 =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

		 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2016_2017 =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

		 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2016_2017 =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					); 
					
	alter table SVOC
		add column ADGBT_2016_2017_year int(5),
		add column Inactivity_ratio_2016_2017_year double,
		add column STD_2016_2017_year date,
		add column Bounce_2016_2017_year int(11),
		add column Total_Standard_price_2016_2017_year decimal(18,6);
		
	update SVOC
		set ADGBT_2016_2017_year=datediff(LTD_2016_2017_years,FTD_2016_2017_years)/(frequency_2016_2017_year-1)
		 where (Sept_2017='Y' ) and frequency_2016_2017_year is not null;

	update SVOC
		set Inactivity_ratio_2016_2017_year = Recency_2016_2017_year/ADGBT_2016_2017_year;

	 
		
	set sql_safe_updates=0;
		 UPDATE IGNORE
				SVOC A
			SET 
				STD_2016_2017_year = (
						SELECT 
							transact_date
						FROM Cust_txns AS B
						WHERE
							A.eos_user_id = B.eos_user_id
						and transact_date between '2016-08-29' and '2017-08-28'
						ORDER BY transact_date ASC
						LIMIT 1,1
					)
			WHERE 
				frequency_2016_2017_year > 1 ;
				
	update SVOC
		set Bounce_2016_2017_year = datediff(STD_2016_2017_year,FTD_2016_2017_years)
		where frequency_2016_2017_year>1 and STD_2016_2017_year is not null;
		

	update SVOC A,(select eos_user_id,
	sum(case when transact_date between '2016-08-29' and '2017-08-28' then Standardised_Price end) as Total_Standard_price_2016_2017_year 
	from Cust_txns  group by eos_user_id) B
		set A.Total_Standard_price_2016_2017_year=B.Total_Standard_price_2016_2017_year
		where A.eos_user_id=B.eos_user_id;
		

		
	##############################       Extra variables created ####################
		
	alter table SVOC 
	add column is_preferred_transalator_2016_2017 varchar(2);

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2016-08-29' and '2017-08-28') B
	set A.is_preferred_transalator_2016_2017='Y'
	where A.eos_user_id=B.eos_user_id;


	alter table SVOC add column enquiry_job_ratio_2016_2017 double; 
	update SVOC A,(select B.eos_user_id,count(case when type='normal' and left(A.created_date,10) between '2016-08-29' and '2017-08-28' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio_2016_2017=A.frequency_2016_2017_year/B.enquiries
	where A.eos_user_id=B.eos_user_id;


	alter table SVOC add column distinct_translators_2016_2017 int;
	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators_2016_2017 from Cust_txns where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id) B
	set A.distinct_translators_2016_2017=B.distinct_translators_2016_2017
	where A.eos_user_id=B.eos_user_id;	
		

	-- HAs ever rated in period 2016_2017

	ALTER TABLE SVOC
	add column Ever_rated_2016_2017 varchar(2) default 'N';

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate is not null AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_2016_2017 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	/*outstanding
	acceptable
	not-acceptable*/

	-- Has ever rated outstanding/not-acceptable in period 2016_2017
	ALTER TABLE SVOC
	add column Ever_rated_outstanding_2016_2017 varchar(2) default 'N',
	add column Ever_rated_acceptable_2016_2017 varchar(2) default 'N',
	add column Ever_rated_not_acceptable_2016_2017 varchar(2) default 'N';


	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'outstanding' AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_outstanding_2016_2017 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'acceptable' AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_acceptable_2016_2017 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'not-acceptable' AND transact_date between '2016-08-29' and '2017-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_not_acceptable_2016_2017 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	/*
	########################### Is subject_area_id in top Subject Areas. #################
	########################### Updating Cust_txns before updating SVOC ################

	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1 varchar(2) default 'N';

	UPDATE Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	UPDATE Cust_txns
	SET Is_in_top_sub_Area_1 = 'Y'
	WHERE subject_area_id IN 
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282,	84,	1279,	310,	85,	1348,	1566,	378,	1532,	339,	533,	199,	1475,	204,	1171,	1355,	159,	297,	478,	563,	795,	1228,	1238,	1210,	1290,	111,	460,	532,	1481,	419,	357,	658,	170,	251,	518,	537,	720,	875,	1143,	1266,	1568,	1560,	667,	1112,	1540,	1437,	637,	772,	1047,	1189,	102,	1116,	1544,	129,	329,	1359,	752,	262,	588,	91,	761,	1124,	98,	217,	629,	1138,	1569,	130,	530,	541,	669,	758,	1037,	1058,	1174,	1179,	1245,	184,	1356,	1402,	328,	1358,	435,	1497,	1505,	1105,	302,	1403,	670,	806,	2070,	387,	58,	439,	249,	4,	65,	295,	458,	663,	1102,	352,	781,	366,	92,	471,	1526,	807,	1517,	1098,	135,	14,	1048,	1012,	1193,	108,	466,	890,	969,	255,	1398,	1559,	35,	1154,	190,	133,	1382,	574,	1534,	416,	1381,	1523,	311,	117,	31,	1323,	1527,	422,	40,	462,	1404,	162,	769,	373,	565,	314,	425,	576,	332,	1313,	143,	367,	428,	292,	16,	105,	153,	745,	1278,	1324,	48,	1487,	43,	124,	126,	70,	305,	327,	544,	551,	570,	594,	741,	940,	1468,	152,	298,	564,	639,	704,	1473,	1528,	389,	493,	542,	620,	650,	676,	679,	684,	701,	708,	728,	750,	778,	810,	862,	876,	880,	897,	901,	945,	961,	966,	990,	1011,	1022,	1057,	1104,	1239,	1390,	1451,	1457,	1495,	1507,	2073,	2077,	738,	1107,	88,	557,	578,	1181,	324,	140,	753,	151,	464,	1365,	1201,	1430,	1194,	21,	1482,	1097,	1114,	1492,	202,	403,	1454,	323,	1552,	1545,	763,	294,	755,	923,	1525,	1529,	1197,	188,	1281,	1334,	286,	1184,	110,	1561,	412,	1263,	1408,	1417,	322,	115,	107,	1087,	104,	429,	671,	8,	380,	121,	242,	1300,	662,	1297,	1399,	257,	163,	413,	1090,	721,	802,	1214,	469,	1187,	193,	749,	1352,	1081,	1434,	1548,	800,	1208,	178,	183,	2078,	349,	227,	1518,	371,	142,	259,	472,	96,	1117,	1431,	67,	567,	924,	1059,	1196,	71,	1510,	1294,	34,	39,	348,	1,	291,	33,	1302,	1145,	1200,	1384,	446,	1480,	572,	274,	410,	106,	38,	239,	734,	321,	167,	277,	1409,	1385,	1109,	224,	1555,	441,	1306,	390,	1280,	1508,	1537,	264,	463,	938,	1346,	99,	245,	317,	447,	968,	992,	993,	995,	1042,	1226,	1310,	1450,	1485,	1113,	571,	331,	394,	395,	1303,	377,	225,	50,	1415,	631,	1494,	150,	269,	341,	1299,	1531,	95,	94,	128,	1488,	1068,	271,	198,	37,	1307,	125,	796,	1186,	5,	100,	330,	1530,	1277,	144,	602,	626,	997,	206,	459,	485,	989,	1261,	1341,	1574,	360,	1301,	1198,	46,	63,	579,	293,	586,	432,	375,	381,	430,	1026,	248,	97,	1285,	231,	437,	455,	633,	664,	1028,	1106,	103,	398,	1372,	253,	1360,	756,	768,	1270,	1367,	1501,	112,	468,	771,	344,	568,	1576,	1484,	287,	53,	18,	189,	118,	1202,	1206,	1550,	177,	1249,	407,	408,	114,	345,	941,	1096,	1188,	243,	270,	241,	234,	51,	361,	1308,	12,	374,	62,	307,	219);*/


	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2016_2017 varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_2016_2017 varchar(2) default 'N';

	UPDATE SVOC  
	SET Is_in_top_sub_Area_2016_2017 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area = 'Y' and transact_date between '2016-08-29' and '2017-08-28');

	UPDATE SVOC  
	SET Is_in_top_sub_Area_1_2016_2017 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_1 = 'Y' and transact_date between '2016-08-29' and '2017-08-28');

	-- Vintage(From 2016-08-28) and New or existing in (2015-16)

	ALTER TABLE SVOC
	add column Vintage_2016_2017 int,
	add column New_or_existing_in_2016_2017 varchar(10) ;

	UPDATE SVOC
	set Vintage_2016_2017 = TIMESTAMPdiff(MONTH, FTD, '2017-08-28'),
	New_or_existing_in_2016_2017 = CASE WHEN FTD BETWEEN '2016-08-29' AND '2017-08-28' THEN 'new' ELSE 'existing' END;


	-- Number of paid-mre, valid-mre, qualityre-edit in 2015-2016
		
		drop table mre;
		create temporary table mre as
		select eos_user_id,enquiry_id,left(B.created_date,10) as transact_date,type from enquiry A,component B
		where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client' and price_after_tax is not null and price_after_tax > 0 
		group by eos_user_id,enquiry_id;

	ALTER TABLE SVOC
	ADD Column No_of_paid_mre_in_2016_2017 int default 0,
	ADD Column No_of_valid_mre_in_2016_2017 int default 0,
	ADD Column No_of_quality_reedit_mre_in_2016_2017 int default 0;

	update SVOC 
	set No_of_paid_mre_in_2016_2017 =0,No_of_valid_mre_in_2016_2017=0,No_of_quality_reedit_mre_in_2016_2017=0;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='paid-mre' and transact_date between '2016-08-29' and '2017-08-28'  GROUP BY eos_user_id) B
	set A.No_of_paid_mre_in_2016_2017 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='valid-mre' and transact_date between '2016-08-29' and '2017-08-28' GROUP BY eos_user_id) B
	set A.No_of_valid_mre_in_2016_2017 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='quality-re_edit' and transact_date between '2016-08-29' and '2017-08-28' GROUP BY eos_user_id) B
	set A.No_of_quality_reedit_mre_in_2016_2017 = B.count
	where A.eos_user_id = B.eos_user_id;

	

	ALTER TABLE SVOC
	ADD Column Ratio_paid_mre_to_total_orders_2016_2017 double,
	ADD Column Ratio_valid_mre_to_total_orders_2016_2017 double,
	ADD Column Ratio_quality_re_edit_mre_to_total_orders_2016_2017 double;

	update SVOC 
	set Ratio_paid_mre_to_total_orders_2016_2017 =null,
	Ratio_valid_mre_to_total_orders_2016_2017 =null,Ratio_quality_re_edit_mre_to_total_orders_2016_2017=null;

	UPDATE SVOC
	SET Ratio_paid_mre_to_total_orders_2016_2017 = No_of_paid_mre_in_2016_2017 / frequency_2016_2017_year,
	Ratio_valid_mre_to_total_orders_2016_2017 = No_of_valid_mre_in_2016_2017 / frequency_2016_2017_year,
	Ratio_quality_re_edit_mre_to_total_orders_2016_2017 = No_of_quality_reedit_mre_in_2016_2017 / frequency_2016_2017_year;

	########################  mre variables for 2016_2017

	/* calculating cases with percentage of paid mre,valid mre and quality-re_edit for the time period 2016-08-29 and 2017-08-28 */
	
	alter table SVOC 
	add column percent_paid_mre_2016_2017  double,
	add column percent_valid_mre_2016_2017  double,
	add column percent_quality_reedit_2016_2017  double;

	
	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client'
	group by eos_user_id,enquiry_id;/* We are computing cases with with completed mre orders, for this purpose we have computed all the cases from component */
    
        
 	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(case when type='normal' then type end ) as percent_paid_mre from mre  where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id ) B
	set A.percent_paid_mre_2016_2017=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id; /* percent of paid_mre*/
    
    update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(case when type='normal' then type end ) as percent_valid_mre from mre  where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id ) B
	set A.percent_valid_mre_2016_2017=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id; /* percent of valid_mre*/

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(case when type='normal' then type end ) as percent_quality_reedit from mre  where transact_date between '2016-08-29' and '2017-08-28' group by eos_user_id ) B
	set A.percent_quality_reedit_2016_2017=B.percent_quality_reedit 
	where A.eos_user_id=B.eos_user_id;	/* percent of quality-re_edit */
	
	
	########################  year_on_year MVC base
	
	/* selecting year on year MVC for the valid MVC base */
	
	alter table SVOC add column 2013_14_base varchar(2) default 'N';
	
	update SVOC
	set 2013_14_base='Y'
	where eos_user_id in (select distinct eos_user_id  from Cust_txns where transact_date between '2013-04-01' and '2014-03-31');
	
	alter table SVOC add column 2013_14_MVC_base varchar(2);
	alter table SVOC add column 2014_15_MVC_base varchar(2);
	alter table SVOC add column 2015_16_MVC_base varchar(2);
	alter table SVOC add column 2016_17_MVC_base varchar(2);
	alter table SVOC add column 2017_18_MVC_base varchar(2);
	alter table SVOC add column 2018_19_MVC_base varchar(2);

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2013-04-01' and '2014-03-31' group by eos_user_id) B
	set A.2013_14_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2014-04-01' and '2015-03-31' group by eos_user_id) B
	set A.2014_15_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2015-04-01' and '2016-03-31' group by eos_user_id) B
	set A.2015_16_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2016-04-01' and '2017-03-31' group by eos_user_id) B
	set A.2016_17_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2017-04-01' and '2018-03-31' group by eos_user_id) B
	set A.2017_18_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';

	update SVOC A,(select eos_user_id,count(*) as freq from Cust_txns 
	where transact_date between '2018-04-01' and '2019-03-31' group by eos_user_id) B
	set A.2018_19_MVC_base='Y'
	where freq>=3 and A.eos_user_id=B.eos_user_id and 2013_14_base='Y';
	
	###########################  2017_2018 ##########################
	
	/* computing variables for the time period 2017-2018*/
	
	alter table SVOC add column percent_not_acceptable_cases_2017_2018 float(2);
	alter table SVOC add column percent_acceptable_cases_2017_2018 double;
	alter table SVOC add column percent_not_rated_cases_2017_2018 double;
	alter table SVOC add column percent_outstanding_cases_2017_2018 double;
	alter table SVOC add column percent_discount_cases_2017_2018 double;
	alter table SVOC add column percent_delay_cases_2017_2018 double;
	alter table SVOC add column Range_of_services_2017_2018 int(5);
	alter table SVOC add column Range_of_subjects_2017_2018 int(5);
	alter table SVOC add column Average_word_count_2017_2018 int(5);
	alter table SVOC add column Average_Delay_2017_2018 int(5);
	alter table SVOC add column Favourite_Week_number_2017_2018 varchar(2);
	alter table SVOC add column Favourite_Month_2017_2018 varchar(2);
	alter table SVOC add column Favourite_Time_2017_2018 varchar(4);
	alter table SVOC add column Favourite_Day_Week_2017_2018 varchar(2);
	alter table SVOC add column maximum_rating_2017_2018 varchar(20);



	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2017_2018=B.rate
	where A.eos_user_id=B.eos_user_id;


	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_acceptable_cases_2017_2018 =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_not_rated_cases_2017_2018=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_outstanding_cases_2017_2018=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_discount_cases_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.percent_delay_cases_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.Range_of_services_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.Range_of_subjects_2017_2018= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B 
	set A.Average_word_count_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.Average_Delay_2017_2018= B.rate
	where A.eos_user_id=B.eos_user_id;


	UPDATE IGNORE
				SVOC A
			SET Favourite_Week_number_2017_2018=(
	SELECT 
							Week_number
						FROM (select eos_user_id,Week_number,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Week_number order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id 
						ORDER BY ratings desc,sum desc
						LIMIT 1) 
						where Sept_2018='Y';
	UPDATE IGNORE
				SVOC A
			SET Favourite_Month_2017_2018=(
	SELECT 
							Favourite_Month
						FROM (select eos_user_id,Favourite_Month,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Favourite_Month order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
	UPDATE IGNORE
				SVOC A
			SET Favourite_Day_Week_2017_2018=(
	SELECT 
							Favourite_Day_Week
						FROM (select eos_user_id,Favourite_Day_Week,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Favourite_Day_Week order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);
						
	 UPDATE IGNORE
				SVOC A
			SET Favourite_Time_2017_2018=(
	SELECT 
							Favourite_Time
						FROM (select eos_user_id,Favourite_Time,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,Favourite_Time order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1);


		UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2017_2018 = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

				
	
	alter table SVOC
	add column percent_offer_cases_2017_2018 int(8);

	update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set A.percent_offer_cases_2017_2018=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;
	
	
	alter table SVOC 
	add column percent_paid_mre_2017_2018  double,
	add column percent_valid_mre_2017_2018  double,
	add column percent_quality_reedit_2017_2018  double;

	
	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client'
	group by eos_user_id,enquiry_id;
    
        
 	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(*) as percent_paid_mre from mre  where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id ) B
	set A.percent_paid_mre_2017_2018=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id;
    
    update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(*) as percent_valid_mre from mre  where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id ) B
	set A.percent_valid_mre_2017_2018=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(*) as percent_quality_reedit from mre  where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id ) B
	set A.percent_quality_reedit_2017_2018=B.percent_quality_reedit 
	where A.eos_user_id=B.eos_user_id;	
	
	/* Number of times customer has rated in the time period 2017-2018 (Aug-Aug time period) */
	
	alter table SVOC add column 
	Number_of_times_rated_2017_2018 int(5);
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id) B
	set Number_of_times_rated_2017_2018=rate_count
	where A.eos_user_id=B.eos_user_id;
	
	/* is_delay is the indicator variable for marking whether the customer has experienced any delay in the time period 2017-2018 (Aug-Aug time period) */
	
	alter table SVOC add column is_delay_2017_2018 varchar(2);
	
	update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2017-08-29' and '2018-08-28') B
	set is_delay_2017_2018='Y'
	where Average_Delay_2017_2018 >0  and Average_Delay_2017_2018 is not null and A.eos_user_id=B.eos_user_id;
	
	
	/*
	ALTER TABLE SVOC
	add column Avg_perc_chrgd_mre double;
	
	UPDATE SVOC X,
	(SELECT A.eos_user_id, A.tot_mre_cost / B.tot_price as Avg_perc_chrgd_mre
	FROM
	(SELECT eos_user_id, sum(price_after_tax*paid_mre_percent_to_total) as tot_mre_cost FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null
	GROUP BY eos_user_id) A , 
	(SELECT eos_user_id, sum(price_after_tax) as tot_price FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null
	GROUP BY eos_user_id) B
	WHERE A.eos_user_id = B.eos_user_id) C
	set X.Avg_perc_chrgd_mre = C.Avg_perc_chrgd_mre
	WHERE X.eos_user_id = C.eos_user_id;
		#########################
	
	ALTER TABLE SVOC
	add column Avg_perc_chrgd_mre_2017_2018 double,

	UPDATE SVOC X,
	(SELECT A.eos_user_id, A.tot_mre_cost / B.tot_price as Avg_perc_chrgd_mre
	FROM
	(SELECT eos_user_id, sum(price_after_tax*paid_mre_percent_to_total) as tot_mre_cost FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null and transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) A , 
	(SELECT eos_user_id, sum(price_after_tax) as tot_price FROM Cust_txns
	WHERE paid_mre_percent_to_total is not null and transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	WHERE A.eos_user_id = B.eos_user_id) C
	set X.Avg_perc_chrgd_mre_2017_2018 = C.Avg_perc_chrgd_mre
	WHERE X.eos_user_id = C.eos_user_id;
		*/

	#################    Favourite Service   ####################
	/* Favourite serivce is used for Marking most frequent service_id for the customer from the time period 2017-2018 (Aug-Aug cycle) */
	

	alter table SVOC add column Favourite_service_2017_2018 varchar(20);
	 UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service_2017_2018=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		
	/* Favourite serivce segment is used for Marking most frequent service segment for the customer from the time period 2017-2018 (Aug-Aug cycle) */
	
	alter table SVOC
	add column Favourite_service_segment_2017_2018 int(5);

	alter table service
	add index(id);
				
	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment_2017_2018=B.service_segment
	where A.Favourite_service_2017_2018=B.id;	
    

	##### 
	
	/* Number of revisions in our selected parameters in the time period 2017-2018 (Aug-Aug cycle) */

	ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area_2017_2018 int,
	add column No_of_Revision_in_price_after_tax_2017_2018 int,
	add column No_of_Revision_in_service_id_2017_2018 int,
	add column No_of_Revision_in_delivery_date_2017_2018 int,
	add column No_of_Revision_in_words_2017_2018 int;


	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area_2017_2018 = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax_2017_2018 = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id_2017_2018 = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	where transact_date between '2017-08-29' and '2018-08-28'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date_2017_2018 = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	where c
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words_2017_2018 = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;

	
	/* 
	
	Favourite_subject_2017_2018 - Identifying the most frequent subject_area_id in the time period 2017_2018 \
	Favourite_SA1_6_name_2017_2018 - Identifying the most frequent SA 1.6 subject area in the time period 2017_2018
	Favourite_SA1_5_name_2017_2018 - Identifying the most frequent SA 1.5 subject area in the time period 2017_2018
	Favourite_SA1_name_2017_2018 - Identifying the most frequent SA 1 subject area in the time period 2017_2018
	
	*/
	
	alter table SVOC
	add column Favourite_subject_2017_2018 int(11),
	add column Favourite_SA1_name_2017_2018 varchar(100) ,
	add column Favourite_SA1_5_name_2017_2018 varchar(100),
	add column Favourite_SA1_6_name_2017_2018 varchar(100);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2017_2018 = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2017_2018 =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2017_2018 =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2017_2018 =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2017-08-29' and '2018-08-28' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);
					
			
	
	
	###########################   2015_2016 #########################
	
	/* computing variables for the time period 2015-2016 for modelling purposes */
	
	alter table SVOC add column percent_not_acceptable_cases_2015_2016_year float(2);
	alter table SVOC add column percent_acceptable_cases_2015_2016_year double;
	alter table SVOC add column percent_not_rated_cases_2015_2016_year double;
	alter table SVOC add column percent_outstanding_cases_2015_2016_year double;
	alter table SVOC add column percent_discount_cases_2015_2016_year double;
	alter table SVOC add column percent_delay_cases_2015_2016_year double;
	alter table SVOC add column Range_of_services_2015_2016_year int(5);
	alter table SVOC add column Range_of_subjects_2015_2016_year int(5);
	alter table SVOC add column Average_word_count_2015_2016_year int(5);
	alter table SVOC add column Average_Delay_2015_2016_year int(5);
	alter table SVOC add column Favourite_Month_2015_2016_year varchar(2);
	alter table SVOC add column Favourite_Time_2015_2016_year varchar(4);
	alter table SVOC add column Favourite_Day_Week_2015_2016_year varchar(2);
	alter table SVOC add column Week_number_2015_2016_year varchar(2);
	alter table SVOC add column maximum_rating_2015_2016_year varchar(10);
	alter TABLE SVOC add column Ever_rated_2015_2016 varchar(2) default 'N';

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
		where rate is not null AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
		GROUP BY eos_user_id) B
		set Ever_rated_2015_2016 = 'Y' 
		WHERE A.eos_user_id = B.eos_user_id;

	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2015_2016_year=B.rate
	where A.eos_user_id=B.eos_user_id;



	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_acceptable_cases_2015_2016_year =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_not_rated_cases_2015_2016_year=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_outstanding_cases_2015_2016_year=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_discount_cases_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.percent_delay_cases_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Range_of_services_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Range_of_subjects_2015_2016_year= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Average_word_count_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.Average_Delay_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(MONTH FROM created_date)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Favourite_Month_2015_2016_year=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(HOUR FROM created_date)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Favourite_Time_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(DAYOFWEEK(created_date)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Favourite_Day_Week_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX((FLOOR((DAYOFMONTH(created_date) - 1) / 7) + 1)) as rate from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B 
	set A.Week_number_2015_2016_year= B.rate
	where A.eos_user_id=B.eos_user_id;



	UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2015_2016_year = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
				);

		
	/* percentage of cases where coupon_code was applied in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	alter table SVOC
	add column percent_offer_cases_2015_2016_year int(8);

	update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set A.percent_offer_cases_2015_2016_year=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;
	
	/* indicator variable for tagging whether has rated in outstanding, not acceptable or acceptable in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	ALTER TABLE SVOC
	add column Ever_rated_outstanding_2015_2016 varchar(2) default 'N',
	add column Ever_rated_acceptable_2015_2016 varchar(2) default 'N',
	add column Ever_rated_not_acceptable_2015_2016 varchar(2) default 'N';


	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'outstanding' AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_outstanding_2015_2016 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'acceptable' AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_acceptable_2015_2016 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'not-acceptable' AND transact_date BETWEEN '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id) B
	set Ever_rated_not_acceptable_2015_2016 = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;


	describe SVOC;

	# Is subject_area_id in top Subject Areas.
	
	/*
	Is_in_top_sub_Area is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1 is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	*/
	
	
	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1 varchar(2) default 'N';

	UPDATE Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	UPDATE Cust_txns
	SET Is_in_top_sub_Area_1 = 'Y'
	WHERE subject_area_id IN 
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282,	84,	1279,	310,	85,	1348,	1566,	378,	1532,	339,	533,	199,	1475,	204,	1171,	1355,	159,	297,	478,	563,	795,	1228,	1238,	1210,	1290,	111,	460,	532,	1481,	419,	357,	658,	170,	251,	518,	537,	720,	875,	1143,	1266,	1568,	1560,	667,	1112,	1540,	1437,	637,	772,	1047,	1189,	102,	1116,	1544,	129,	329,	1359,	752,	262,	588,	91,	761,	1124,	98,	217,	629,	1138,	1569,	130,	530,	541,	669,	758,	1037,	1058,	1174,	1179,	1245,	184,	1356,	1402,	328,	1358,	435,	1497,	1505,	1105,	302,	1403,	670,	806,	2070,	387,	58,	439,	249,	4,	65,	295,	458,	663,	1102,	352,	781,	366,	92,	471,	1526,	807,	1517,	1098,	135,	14,	1048,	1012,	1193,	108,	466,	890,	969,	255,	1398,	1559,	35,	1154,	190,	133,	1382,	574,	1534,	416,	1381,	1523,	311,	117,	31,	1323,	1527,	422,	40,	462,	1404,	162,	769,	373,	565,	314,	425,	576,	332,	1313,	143,	367,	428,	292,	16,	105,	153,	745,	1278,	1324,	48,	1487,	43,	124,	126,	70,	305,	327,	544,	551,	570,	594,	741,	940,	1468,	152,	298,	564,	639,	704,	1473,	1528,	389,	493,	542,	620,	650,	676,	679,	684,	701,	708,	728,	750,	778,	810,	862,	876,	880,	897,	901,	945,	961,	966,	990,	1011,	1022,	1057,	1104,	1239,	1390,	1451,	1457,	1495,	1507,	2073,	2077,	738,	1107,	88,	557,	578,	1181,	324,	140,	753,	151,	464,	1365,	1201,	1430,	1194,	21,	1482,	1097,	1114,	1492,	202,	403,	1454,	323,	1552,	1545,	763,	294,	755,	923,	1525,	1529,	1197,	188,	1281,	1334,	286,	1184,	110,	1561,	412,	1263,	1408,	1417,	322,	115,	107,	1087,	104,	429,	671,	8,	380,	121,	242,	1300,	662,	1297,	1399,	257,	163,	413,	1090,	721,	802,	1214,	469,	1187,	193,	749,	1352,	1081,	1434,	1548,	800,	1208,	178,	183,	2078,	349,	227,	1518,	371,	142,	259,	472,	96,	1117,	1431,	67,	567,	924,	1059,	1196,	71,	1510,	1294,	34,	39,	348,	1,	291,	33,	1302,	1145,	1200,	1384,	446,	1480,	572,	274,	410,	106,	38,	239,	734,	321,	167,	277,	1409,	1385,	1109,	224,	1555,	441,	1306,	390,	1280,	1508,	1537,	264,	463,	938,	1346,	99,	245,	317,	447,	968,	992,	993,	995,	1042,	1226,	1310,	1450,	1485,	1113,	571,	331,	394,	395,	1303,	377,	225,	50,	1415,	631,	1494,	150,	269,	341,	1299,	1531,	95,	94,	128,	1488,	1068,	271,	198,	37,	1307,	125,	796,	1186,	5,	100,	330,	1530,	1277,	144,	602,	626,	997,	206,	459,	485,	989,	1261,	1341,	1574,	360,	1301,	1198,	46,	63,	579,	293,	586,	432,	375,	381,	430,	1026,	248,	97,	1285,	231,	437,	455,	633,	664,	1028,	1106,	103,	398,	1372,	253,	1360,	756,	768,	1270,	1367,	1501,	112,	468,	771,	344,	568,	1576,	1484,	287,	53,	18,	189,	118,	1202,	1206,	1550,	177,	1249,	407,	408,	114,	345,	941,	1096,	1188,	243,	270,	241,	234,	51,	361,	1308,	12,	374,	62,	307,	219);

	/*
				computing top subject area for the time period 2015-2016 (Aug-Aug Cycle)
		
	Is_in_top_sub_Area_2015_2016 is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1_2015_2016 is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	
	
	*/
	
	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2015_2016 varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_2015_2016 varchar(2) default 'N';


	UPDATE SVOC  
	SET Is_in_top_sub_Area_2015_2016 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area = 'Y' and transact_date BETWEEN '2015-08-29' AND '2016-08-28');

	UPDATE SVOC  
	SET Is_in_top_sub_Area_1_2015_2016 = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_1 = 'Y' and transact_date BETWEEN '2015-08-29' AND '2016-08-28');
	
	/* Vintage is the number of days from the FTD of the customer till the last date of the observational time period, it is used to measure the number of days customer was active in the system

	New_or_existing_in_2015_2016 is an indicator variable for measuring whether customer transacted in time period 2015-08-29 AND 2016-08-28
	
	*/
	
	# Vintage(From 2016-08-28) and New or existing in (2015-16)

	ALTER TABLE SVOC
	add column Vintage_2015_2016 int,
	add column New_or_existing_in_2015_2016 varchar(10) ;

	UPDATE SVOC
	set Vintage_2015_2016 = TIMESTAMPdiff(MONTH, FTD, '2016-08-28'),
	New_or_existing_in_2015_2016 = CASE WHEN FTD BETWEEN '2015-08-29' AND '2016-08-28' THEN 'new' ELSE 'existing' END;

	describe SVOC;

	/* Obtaining number of paid-mre, valid mre and quality re-edit for the period 2015-2016 */
	
	# Number of paid-mre, valid-mre, qualityre-edit in 2015-2016
		
	drop table mre;
	create temporary table mre as
	select eos_user_id,enquiry_id,left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client' and price_after_tax is not null and price_after_tax > 0 
	group by eos_user_id,enquiry_id;

	ALTER TABLE SVOC
	ADD Column No_of_paid_mre_in_2015_2016 int default 0,
	ADD Column No_of_valid_mre_in_2015_2016 int default 0,
	ADD Column No_of_quality_reedit_mre_in_2015_2016 int default 0;


	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='paid-mre' and transact_date BETWEEN '2015-08-29' AND '2016-08-28'  GROUP BY eos_user_id) B
	set A.No_of_paid_mre_in_2015_2016 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='valid-mre' and transact_date BETWEEN '2015-08-29' AND '2016-08-28' GROUP BY eos_user_id) B
	set A.No_of_valid_mre_in_2015_2016 = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='quality-re_edit' and transact_date BETWEEN '2015-08-29' AND '2016-08-28' GROUP BY eos_user_id) B
	set A.No_of_quality_reedit_mre_in_2015_2016 = B.count
	where A.eos_user_id = B.eos_user_id;

	/* Obtaining ratio of paid-mre, valid-mre and quality re-edit for the period 2015-2016 */
	
	ALTER TABLE SVOC
	ADD Column Ratio_paid_mre_to_total_orders_2015_2016 double,
	ADD Column Ratio_valid_mre_to_total_orders_2015_2016 double,
	ADD Column Ratio_quality_re_edit_mre_to_total_orders_2015_2016 double;

	update SVOC 
	set Ratio_paid_mre_to_total_orders_2015_2016 =null,
	Ratio_valid_mre_to_total_orders_2015_2016 =null,Ratio_quality_re_edit_mre_to_total_orders_2015_2016=null;

	UPDATE SVOC
	SET Ratio_paid_mre_to_total_orders_2015_2016 = No_of_paid_mre_in_2015_2016 / frequency_2015_2016_year,
	Ratio_valid_mre_to_total_orders_2015_2016 = No_of_valid_mre_in_2015_2016 / frequency_2015_2016_year,
	Ratio_quality_re_edit_mre_to_total_orders_2015_2016 = No_of_quality_reedit_mre_in_2015_2016 / frequency_2015_2016_year;
	
	###########################
	
	/* 
	Favourite subject area id in time period 2015-2016 
	Favourite SA 1 in time period 2015-2016 
	Favourite SA 1.6 in time period 2015-2016 
	*/
	
	ALTER TABLE SVOC
	ADD COLUMN Favourite_subject_2015_2016 int(11) ,
	ADD COLUMN Favourite_SA1_name_2015_2016 varchar(100),
	ADD COLUMN Favourite_SA1_5_name_2015_2016 varchar(100),
	ADD COLUMN Favourite_SA1_6_name_2015_2016 varchar(100);

	select Favourite_SA1_name_2015_2016 FROM SVOC;


	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2015_2016 = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2015_2016 =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

    UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2015_2016 =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		
	 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2015_2016 =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);
	
	


	############################  For calculating MVC from sent_to_client_date ########
	/*  First send to client date  */
	
	ALTER TABLE SVOC
	add column STC_date date,
	add column one_yr_from_STC_date date,
	add column one_yr_Frq_from_STC_date int;

	UPDATE SVOC A, Cust_txns B
	set A.STC_date = left(B.sent_to_client_date, 10)
	where A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;

	update SVOC
	set one_yr_from_STC_date = DATE_ADD(STC_date, INTERVAL 1 Year); 
	
	/* Two years since FTD calculated for each customer */
		
	ALTER TABLE SVOC
	ADD COLUMN two_yrs_from_FTD date;

	update SVOC
	set two_yrs_from_FTD = DATE_ADD(FTD, INTERVAL 2 Year); 

	alter table SVOC 
	add column two_yrs_Frq_from_FTD int;

	update SVOC A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq from Cust_txns A,SVOC B
	where transact_date between FTD and two_yrs_from_FTD and A.eos_user_id=B.eos_user_id 
	group by A.eos_user_id) C
	set A.two_yrs_Frq_from_FTD=C.freq
	where A.eos_user_id=C.eos_user_id;


	alter table SVOC 
	add column two_yrs_MVC varchar(2);

	update SVOC
	set two_yrs_MVC=
	case when two_yrs_Frq_from_FTD >= 3 then '1' else '0' end;

	/* Computing frequency for all the customers from first send to client date */
	
	update SVOC A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq from Cust_txns A, SVOC B
	where transact_date between STC_date and one_yr_from_STC_date and A.eos_user_id=B.eos_user_id 
	group by A.eos_user_id) C
	set A.one_yr_Frq_from_STC_date=C.freq
	where A.eos_user_id=C.eos_user_id;

	alter table SVOC 
	add column one_yr_MVC_from_STC_date varchar(2);

	update SVOC
	set one_yr_MVC_from_STC_date=
	case when one_yr_Frq_from_STC_date >= 3 then '1' else '0' end;
	
	/* Computing frequency for all the customers from first transact date*/
	
	alter table SVOC add column 1_yr_from_FTD date;

	update SVOC
	set 1_yr_from_FTD=DATE_ADD(FTD, INTERVAL 1 Year); 

	alter table SVOC add column 1_yr_Frq_from_FTD int;
	/*
	update SVOC A,(select eos_user_id,transact_date,enquiry_id from Cust_txns) B
	set */

	update SVOC A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq from Cust_txns A,SVOC B
	where transact_date between FTD and 1_yr_from_FTD and A.eos_user_id=B.eos_user_id 
	group by A.eos_user_id) C
	set A.1_yr_Frq_from_FTD=C.freq
	where A.eos_user_id=C.eos_user_id;


	alter table SVOC add column 1_yr_MVC varchar(2);

	update SVOC
	set 1_yr_MVC=
	case when 1_yr_Frq_from_FTD>=3 then '1' else '0' end ;

	############### Actual Time for Job Completion #############

	/* Actual time for job completion is the difference between send-to-client-date and confirmed_date */
	
	ALTER TABLE SVOC
	ADD Column First_Act_Time_for_job_Completion int;

	UPDATE SVOC A, Cust_txns B
	set A.First_Act_Time_for_job_Completion = B.Act_Time_for_job_Completion
	WHERE A.eos_user_id = B.eos_user_id AND A.STC_date = left(B.sent_to_client_date,10);

	/* Is_Univ_in_top_Univ is a indicator variable to define whether customer belongs to the university which is most frequent among the MVCs */
	
	ALTER TABLE SVOC
	ADD column Is_Univ_in_top_Univ varchar(2) default 'N';

	SET SQL_SAFE_UPDATES = 0;
	UPDATE SVOC
	set Is_Univ_in_top_Univ = 'Y'
	WHERE University_name in ('The University of Tokyo',
	'Seoul National University',
	'Waseda University',
	'Kyoto University',
	'Yonsei University',
	'Osaka University',
	'University of Tsukuba',
	'Tohoku University',
	'Korea University',
	'Kyushu University',
	'Nagoya University',
	'Keio University',
	'Hanyang University',
	'Hiroshima University',
	'Tokyo Medical and Dental University',
	'Hokkaido University',
	'Seoul National University Hospital');

	/* 
	
	First_translator_in_top_translator is an indicator variable for each customer whether the customer was assigned a top translator for the first transaction 
	top translators are identified by taking cumulative distribution for MVC customers, and then selecting the top decile as a top translator
	
	*/
	
	ALTER TABLE SVOC
	add Column First_translator_in_top_translator varchar(2);

	UPDATE SVOC
	set First_translator_in_top_translator = 'N'
	WHERE First_trnx_Translator IS NOT NULL;

	UPDATE SVOC
	set First_translator_in_top_translator = 'Y'
	WHERE First_trnx_Translator IN (1007,1009,1019,102,1026,1036,1052,1053,1056,1060,1065,1078,1079,1084,1086,109,1092,1093,1110,1111,1112,1127,1133,1134,1138,1148,1149,1162,	117,	1176,	1183,	1188,	1189,	1191,	1215,	1220,	1227,	1243,	1247,	1248,	1255,	1256,	1257,	1261,	1270,	1286,	1299,	1310,	1336,	135,	1350,	1352,	136,	1360,	1365,	1367,	1368,	1369,	1384,	1389,	14,	1401,	1407,	1418,	1422,	1438,	1446,	1453,	1454,	1470,	1475,	1500,	1504,	1509,	1513,	1516,	1519,	1542,	1553,	1557,	1563,	1566,	1568,	1570,	1581,	1611,	162,	1652,	1658,	1660,	1661,	1667,	1674,	1681,	1682,	1684,	1685,	1688,	1703,	1712,	1713,	1729,	1747,	1757,	1765,	1766,	1775,	1776,	1783,	1785,	1806,	1808,	1811,	1813,	1816,	1818,	182,	1822,	1824,	1827,	1829,	1830,	1835,	1837,	1840,	185,	1853,	1854,	186,	1862,	187,	1878,	1879,	188,	1885,	1886,	1889,	1898,	190,	1916,	1922,	1926,	1945,	1953,	197,	1977,	1978,	1981,	1989,	1991,	1992,	1996,	2001,	2005,	2008,	2015,	2030,	2066,	2067,	2076,	2099,	2108,	2129,	2137,	214,	2143,	2160,	2170,	2177,	2181,	2184,	2186,	219,	2197,	2204,	2207,	2209,	2213,	2220,	224,	2246,	2250,	2272,	2288,	2302,	2313,	2317,	2321,	2325,	2328,	2329,	2354,	2355,	2360,	2391,	2392,	2395,	2396,	2400,	2410,	2411,	2413,	2426,	2449,	2450,	2457,	2463,	2469,	2481,	2490,	2492,	2495,	2500,	2512,	2517,	2524,	2525,	2527,	2531,	2536,	2546,	2557,	256,	2562,	2568,	257,	2570,	2576,	2595,	2597,	260,	2600,	2605,	2614,	2617,	2619,	2621,	2631,	2635,	2642,	2658,	2660,	2663,	2677,	2682,	2688,	2690,	2695,	2699,	2700,	2702,	2711,	2716,	2725,	2735,	2737,	2741,	2742,	2749,	2750,	2751,	2756,	2760,	2762,	2771,	2773,	2780,	2782,	2783,	2785,	2793,	2797,	2803,	2805,	2809,	2811,	2813,	2819,	2821,	2828,	2833,	2836,	2840,	2842,	2843,	2844,	2847,	2848,	2857,	2858,	2872,	2874,	2876,	2881,	2885,	2887,	2893,	2897,	2901,	2906,	2910,	2913,	2915,	2922,	2929,	2931,	2935,	2938,	2943,	2944,	2949,	2950,	2951,	2952,	2955,	2956,	2958,	2964,	2966,	2973,	2975,	2979,	2980,	2987,	2992,	3000,	3001,	3004,	3005,	3006,	301,	3012,	3019,	3023,	3025,	3029,	3030,	3031,	3037,	3038,	3039,	3043,	3046,	3050,	3054,	3055,	3059,	3060,	3061,	3066,	3067,	3072,	3075,	3077,	308,	3080,	3086,	3087,	309,	3090,	3091,	3093,	3096,	3097,	3098,	3099,	310,	3101,	3102,	3103,	3104,	3106,	3107,	3108,	311,	3110,	3111,	3112,	3113,	3115,	3123,	3132,	3133,	3139,	3141,	3142,	3144,	3145,	3146,	315,	3153,	3155,	3157,	3159,	316,	3161,	3164,	3166,	3167,	3168,	3170,	3172,	3173,	3176,	3177,	3180,	3182,	3185,	3189,	319,	3190,	3191,	3194,	3198,	3199,	320,	3201,	3202,	3208,	321,	3211,	3212,	3218,	3219,	3220,	3222,	3227,	3230,	3231,	3235,	3239,	3246,	3248,	3249,	3251,	3254,	3258,	3259,	3261,	3264,	3265,	3267,	3278,	3279,	328,	3282,	3286,	3289,	3290,	3291,	3292,	3296,	3297,	3302,	3307,	3309,	3312,	3316,	3321,	3322,	3325,	3327,	3328,	3329,	3336,	3337,	3339,	334,	3340,	3343,	3348,	3354,	3355,	3371,	3375,	3379,	338,	3384,	339,	3390,	3391,	3393,	3396,	3406,	3408,	3409,	3410,	3413,	3414,	3415,	3416,	3420,	3428,	3432,	3436,	3439,	3441,	3446,	3448,	3453,	3454,	3457,	3458,	3460,	3463,	3464,	3466,	3467,	3471,	3474,	3476,	3478,	3480,	3482,	3483,	3491,	3492,	3499,	3500,	3501,	3508,	3510,	3512,	3514,	3516,	3518,	3522,	3526,	3531,	3532,	3533,	3535,	3545,	3546,	3549,	3553,	3554,	3555,	3556,	3559,	3560,	3561,	3574,	3578,	3579,	3585,	3586,	3588,	3589,	3592,	3595,	3603,	3605,	3606,	3607,	3608,	3610,	3611,	3612,	3613,	3616,	3617,	3619,	362,	3622,	3631,	3634,	3636,	3637,	3638,	3640,	3641,	3643,	3645,	3648,	3651,	3652,	3653,	3654,	3655,	3656,	3657,	3659,	366,	3662,	3664,	3665,	3669,	3676,	3678,	3679,	3685,	3687,	3690,	3692,	3694,	3696,	3697,	3700,	3703,	3706,	3707,	3709,	3716,	3717,	3719,	3720,	3723,	3727,	3728,	373,	3730,	3732,	3745,	3748,	3749,	3751,	3760,	3761,	3762,	3764,	3767,	3768,	3770,	3779,	3780,	3781,	3784,	3785,	3786,	3789,	3790,	3791,	3793,	3796,	3797,	3806,	381,	3811,	3812,	3817,	3819,	3830,	3831,	3834,	3835,	3836,	3837,	3839,	3840,	3844,	3845,	3846,	3852,	3854,	3859,	3863,	3865,	3867,	3869,	3870,	3871,	3872,	3875,	3878,	3883,	3889,	3894,	3896,	3900,	3902,	3903,	3905,	3907,	3916,	3920,	3924,	3928,	3930,	3931,	3933,	3934,	3935,	3936,	3939,	3944,	3950,	3951,	3954,	3955,	3959,	3960,	3963,	3964,	3970,	3972,	3974,	3976,	3979,	3984,	3986,	3990,	3995,	3996,	4001,	4002,	4003,	4006,	4008,	4013,	4015,	4017,	4019,	4023,	4024,	4026,	4028,	403,	4030,	4034,	4035,	4036,	4037,	4039,	404,	4046,	4050,	4052,	4053,	4054,	4056,	4059,	406,	4061,	4062,	4065,	4066,	4069,	4070,	4074,	4078,	4079,	4080,	4081,	4088,	4095,	4099,	4100,	4104,	4107,	4111,	4115,	4118,	4119,	4123,	4129,	4131,	4133,	4136,	4139,	4142,	4146,	4148,	4151,	4152,	4154,	4155,	4158,	4161,	4164,	4166,	417,	4176,	4179,	4185,	4189,	419,	4198,	420,	4201,	4202,	421,	4211,	4213,	4215,	4221,	4226,	4229,	4231,	4232,	4234,	4237,	4241,	4245,	4246,	4248,	425,	4251,	4254,	4257,	4259,	4260,	4263,	4268,	4271,	4272,	4278,	4288,	4290,	4303,	4305,	4316,	4318,	4319,	4320,	4321,	4323,	4324,	4326,	4328,	433,	4332,	4334,	4336,	4338,	4340,	4341,	4344,	4345,	4346,	4358,	4364,	4366,	4369,	437,	4371,	4375,	4380,	4385,	4392,	4393,	4396,	44,	440,	4400,	4401,	4404,	4405,	4409,	4422,	4425,	4427,	443,	4434,	4437,	4441,	4443,	4445,	4460,	4464,	4470,	4477,	4490,	4492,	4493,	4494,	4496,	4499,	4500,	4503,	4504,	4511,	4514,	4519,	452,	4523,	4530,	4541,	4549,	4550,	4552,	4554,	4556,	4559,	4569,	4572,	4574,	4576,	4577,	4579,	4584,	4601,	4614,	4616,	4621,	4624,	4626,	4629,	4641,	4643,	4649,	465,	4658,	4659,	4662,	4665,	4675,	4678,	4682,	4686,	4688,	4689,	4693,	4694,	4697,	4700,	4701,	4703,	4704,	4716,	4717,	4723,	4724,	4732,	4733,	4735,	4741,	4748,	475,	4754,	4755,	4760,	4770,	4771,	4773,	4774,	4779,	4793,	4795,	4806,	4817,	4818,	4821,	4825,	4828,	4833,	4835,	4839,	4844,	4845,	4850,	4853,	486,	4863,	4870,	4873,	4874,	4876,	4877,	4886,	4889,	4894,	4895,	4896,	4897,	4898,	4899,	490,	4900,	4901,	4903,	4906,	491,	4911,	4916,	492,	4924,	4925,	4928,	493,	4930,	4934,	4937,	494,	4941,	4957,	4968,	4974,	4984,	4988,	4989,	4992,	4997,	5000,	5004,	5008,	5009,	5011,	5012,	5015,	5016,	5019,	5024,	5040,	5043,	5045,	5046,	5048,	5051,	5053,	5055,	5056,	5059,	506,	5062,	5066,	5069,	5080,	5081,	509,	5099,	5104,	5108,	511,	5114,	5116,	5122,	5128,	5136,	5147,	5151,	5152,	516,	5165,	5166,	5167,	5169,	5197,	520,	5204,	5206,	5208,	521,	5210,	5216,	5225,	523,	5230,	5240,	5246,	5250,	5255,	5256,	5259,	526,	527,	5271,	5275,	5289,	5295,	5296,	5297,	5303,	5309,	5315,	5322,	5325,	533,	5337,	5341,	5348,	5383,	5386,	5389,	5393,	5394,	5398,	5407,	541,	5416,	5420,	5422,	5437,	5445,	5446,	5451,	5460,	5469,	5479,	5495,	5513,	5516,	5538,	554,	5540,	5543,	5544,	5548,	5551,	5558,	556,	5563,	5566,	5582,	5586,	5593,	5599,	5602,	561,	5632,	5645,	5647,	5655,	566,	5665,	5673,	5678,	5681,	569,	5692,	5693,	5694,	5695,	570,	5716,	5723,	5725,	5728,	5760,	579,	5797,	584,	589,	590,	591,	592,	597,	604,	605,	606,	607,	609,	610,	615,	621,	633,	636,	640,	641,	651,	656,	657,	659,	660,	661,	665,	667,	678,	76,	81,	84,	8569,	8596,	927,	93,	930,	932,	943,	957,	9573,	972,	9720,	9752,	980,	989,	990,	997);
	
	
	

	
	####################      adding MRE variables   ##########################
	
	
	/* Percentage of the paid-mre, valid-mre and quality-re-edit cases in the time period 2015-2016 (Aug-Aug cycle)*/
	
	alter table SVOC 
	add column percent_paid_mre_2015_2016_year double,
	add column percent_valid_mre_2015_2016_year double,
	add column percent_quality_reedit_2015_2016_year double;

	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id 
	group by eos_user_id,enquiry_id;

	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(*) as percent_paid_mre from mre  where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id ) B
	set A.percent_paid_mre_2015_2016_year=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(*) as percent_valid_mre from mre  where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id ) B
	set A.percent_valid_mre_2015_2016_year=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(*) as percent_quality_reedit from mre  where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id ) B
	set A.percent_quality_reedit_2015_2016_year=B.percent_quality_reedit
	where A.eos_user_id=B.eos_user_id;	
	
	/* Number of times customer has given rating in the time period 2015-2016 (Aug-Aug cycle) */
	
	alter table SVOC 
	add column Number_of_times_rated_2015_2016_year int(5);
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id) B
	set Number_of_times_rated_2015_2016_year=rate_count
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC add column is_delay_2015_2016_year varchar(2);
	
	update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2015-08-29' and '2016-08-28') B
	set is_delay_2015_2016_year='Y'
	where Average_Delay_2015_2016_year >0  and Average_Delay_2015_2016_year is not null and A.eos_user_id=B.eos_user_id;

	
	
	#################    Favourite Service

	alter table SVOC
	add column Favourite_service_segment_2015_2016_year int(5);

	alter table SVOC
	add index(Favourite_service);

	alter table service
	add index(id);

	alter table SVOC add column Favourite_service_2015_2016_year varchar(20);
	 UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service_2015_2016_year=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2015-08-29' and '2016-08-28' group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment_2015_2016_year=B.service_segment
	where A.Favourite_service_2015_2016_year=B.id;	
	
	
	##############################################   creating set of variables for 2016-2017     #########################################
	
	
	
	##########################  
	
	/* marking MVCs from 2016_2017 */
	ALTER TABLE SVOC
	add column MVC_in_2016_2017 varchar(2);

	UPDATE SVOC
	set MVC_in_2016_2017 = 'Y'
	WHERE L2_Segment_new_2016_2017 = 1 or L2_Segment_new_2016_2017 = 2 
	or L2_Segment_new_2016_2017 = 4 or L2_Segment_new_2016_2017 = 5
	or L2_Segment_new_2016_2017 = 7;
	
	
	############## Calculating Ever MVCs #################
	ALTER TABLE SVOC
	ADD Column MVC_2003_2004 varchar(2) default 'N',
	ADD Column MVC_2004_2005 varchar(2) default 'N',
	ADD Column MVC_2005_2006 varchar(2) default 'N',
	ADD Column MVC_2006_2007 varchar(2) default 'N',
	ADD Column MVC_2007_2008 varchar(2) default 'N',
	ADD Column MVC_2008_2009 varchar(2) default 'N',
	ADD Column MVC_2009_2010 varchar(2) default 'N',
	ADD Column MVC_2010_2011 varchar(2) default 'N',
	ADD Column MVC_2011_2012 varchar(2) default 'N',
	ADD Column MVC_2012_2013 varchar(2) default 'N',
	ADD Column MVC_2013_2014 varchar(2) default 'N',
	ADD Column MVC_2014_2015 varchar(2) default 'N',
	ADD Column MVC_2015_2016 varchar(2) default 'N',
	ADD Column MVC_2016_2017 varchar(2) default 'N',
	ADD Column MVC_2017_2018 varchar(2) default 'N';

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2003-08-29' AND '2004-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2003_2004 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;


	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2004-08-29' AND '2005-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2004_2005 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2005-08-29' AND '2006-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2005_2006 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2006-08-29' AND '2007-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2006_2007 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2007-08-29' AND '2008-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2007_2008 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2008-08-29' AND '2009-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2008_2009 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2009-08-29' AND '2010-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2009_2010 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2010-08-29' AND '2011-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2010_2011 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2011-08-29' AND '2012-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2011_2012 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2012-08-29' AND '2013-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2012_2013 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2013-08-29' AND '2014-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2013_2014 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2014-08-29' AND '2015-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2014_2015 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2015-08-29' AND '2016-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2015_2016 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2016-08-29' AND '2017-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2016_2017 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(enquiry_id) freq FROM Cust_txns
	WHERE transact_date between '2017-08-29' AND '2018-08-28'
	GROUP BY eos_user_id
	HAVING freq >= 3) B
	SET A.MVC_2017_2018 = 'Y' 
	WHERE A.eos_user_id = B.eos_user_id;


	ALTER TABLE SVOC
	ADD Column EVER_MVC varchar(2) default 'N';

	UPDATE SVOC
	SET EVER_MVC = 'Y'
	WHERE MVC_2003_2004 = 'Y' OR MVC_2004_2005 = 'Y' OR MVC_2005_2006 = 'Y' OR MVC_2006_2007 = 'Y' OR MVC_2007_2008 = 'Y' OR MVC_2008_2009 = 'Y' OR MVC_2009_2010 = 'Y' OR MVC_2010_2011 = 'Y' OR MVC_2011_2012 = 'Y' OR MVC_2012_2013 = 'Y' OR MVC_2013_2014 = 'Y' OR MVC_2014_2015 = 'Y' OR MVC_2015_2016 = 'Y' OR MVC_2016_2017 = 'Y' OR MVC_2017_2018 = 'Y';
	
	/* adding the customer invoice type */
	
	alter table Cust_txns
	 add column invoice_type int(11);
	 
	 set sql_safe_updates=0;
	 update Cust_txns A,enquiry B
	 set A.invoice_type=B.invoice_type
	 where A.enquiry_id=B.id;
	
	ALTER TABLE Cust_txns
	add column invoice_name varchar(255);
	
	update Cust_txns A, masters B
	set A.invoice_name=B.name
	where A.invoice_type=B.id;
	
	alter table Cust_txns add column funding_category varchar(10);
	
	update Cust_txns 
	set funding_category=
	case when invoice_name= 'KOR >> Tax invoice - Individuals' then 'public' else
	case when invoice_name= 'KOR >> Tax invoice - Corporations' then 'public' else
	case when invoice_name= 'KOR >> Default format (Monthly)' then 'public' else
	case when invoice_name= 'KOR >> Default format' then 'private' else
	case when invoice_name= 'KOR >> Credit card receipt invoice' then 'private' else
	case when invoice_name= 'KOR >> Cash receipt' then 'private' else
	case when invoice_name= 'JPN >> MNS (MNS format required)' then 'public' else
	case when invoice_name= 'JPN >> Default format (MNS not required)' then 'private' else
	case when invoice_name= 'JPN >> Default format (Monthly)' then 'public' else 'others'
	end end end end end end end end end;
	
					
	/* creating a new base variables for the model with time period 01 Apr - 31 Mar */
	
		###########################   2015_2016_N #########################
	
	/* computing variables for the time period 2015-2016 for modelling purposes */
	
	alter table SVOC add column percent_not_acceptable_cases_2015_2016_N float(2);
	alter table SVOC add column percent_acceptable_cases_2015_2016_N double;
	alter table SVOC add column percent_not_rated_cases_2015_2016_N double;
	alter table SVOC add column percent_outstanding_cases_2015_2016_N double;
	alter table SVOC add column percent_discount_cases_2015_2016_N double;
	alter table SVOC add column percent_delay_cases_2015_2016_N double;
	alter table SVOC add column Range_of_services_2015_2016_N int(5);
	alter table SVOC add column Range_of_subjects_2015_2016_N int(5);
	alter table SVOC add column Average_word_count_2015_2016_N int(5);
	alter table SVOC add column Average_Delay_2015_2016_N int(5);
	alter table SVOC add column Favourite_Month_2015_2016_N varchar(2);
	alter table SVOC add column Favourite_Time_2015_2016_N varchar(4);
	alter table SVOC add column Favourite_Day_Week_2015_2016_N varchar(2);
	alter table SVOC add column Week_number_2015_2016_N varchar(2);
	alter table SVOC add column maximum_rating_2015_2016_N varchar(10);
	alter TABLE SVOC add column Ever_rated_2015_2016_N varchar(2) default 'N';
	alter table SVOC
	add column  ATV_2015_2016_N int(10),
	add column frequency_2015_2016_N int(4),
	add column Recency_2015_2016_N int(5),
	add column FTD_2015_2016_N date,
	add column LTD_2015_2016_N date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2015-04-01' AND '2016-03-31') B group by eos_user_id) B
	set A.FTD_2015_2016_N=B.FTD_1_years,A.LTD_2015_2016_N=B.LTD_1_years,A.frequency_2015_2016_N=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id ;

	
	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
		where rate is not null AND transact_date BETWEEN '2015-04-01' AND '2016-03-31'
		GROUP BY eos_user_id) B
		set Ever_rated_2015_2016_N = 'Y' 
		WHERE A.eos_user_id = B.eos_user_id;

	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2015_2016_N=B.rate
	where A.eos_user_id=B.eos_user_id;



	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.percent_acceptable_cases_2015_2016_N =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.percent_not_rated_cases_2015_2016_N=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.percent_outstanding_cases_2015_2016_N=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.percent_discount_cases_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.percent_delay_cases_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Range_of_services_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Range_of_subjects_2015_2016_N= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Average_word_count_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B
	set A.Average_Delay_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(MONTH FROM created_date)) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Favourite_Month_2015_2016_N=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(HOUR FROM created_date)) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Favourite_Time_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(DAYOFWEEK(created_date)) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Favourite_Day_Week_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX((FLOOR((DAYOFMONTH(created_date) - 1) / 7) + 1)) as rate from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B 
	set A.Week_number_2015_2016_N= B.rate
	where A.eos_user_id=B.eos_user_id;



	UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2015_2016_N = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
				);

		
	/* percentage of cases where coupon_code was applied in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	alter table SVOC
	add column percent_offer_cases_2015_2016_N int(8);

	update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B
	set A.percent_offer_cases_2015_2016_N=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;
	
	/* indicator variable for tagging whether has rated in outstanding, not acceptable or acceptable in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	ALTER TABLE SVOC
	add column Ever_rated_outstanding_2015_2016_N varchar(2) default 'N',
	add column Ever_rated_acceptable_2015_2016_N varchar(2) default 'N',
	add column Ever_rated_not_acceptable_2015_2016_N varchar(2) default 'N';


	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'outstanding' AND transact_date BETWEEN '2015-04-01' AND '2016-03-31'
	GROUP BY eos_user_id) B
	set Ever_rated_outstanding_2015_2016_N = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'acceptable' AND transact_date BETWEEN '2015-04-01' AND '2016-03-31'
	GROUP BY eos_user_id) B
	set Ever_rated_acceptable_2015_2016_N = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'not-acceptable' AND transact_date BETWEEN '2015-04-01' AND '2016-03-31'
	GROUP BY eos_user_id) B
	set Ever_rated_not_acceptable_2015_2016_N = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;


	describe SVOC;

	# Is subject_area_id in top Subject Areas.
	
	
	Is_in_top_sub_Area is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1 is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	
	
	
	ALTER TABLE Cust_txns
	ADD Column Is_in_top_sub_Area_N varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_N varchar(2) default 'N';

	UPDATE Cust_txns
	SET Is_in_top_sub_Area_N = 'Y'
	WHERE subject_area_id IN
	(130,153,159,170,382,499,503,512,518,545,555,597,610,612,619,643,646,653,656,677,685,687,713,718,735,754,788,822,823,833,846,863,868,884,898,906,927,930,935,944,977,990,1023,1122,1127,1166,1175,1205,1220,1252,1253,1273,1321,1340,1378,1420,1424,1451,1456,1460,1462,1463,2068,2121,433,445,854,1448,1481,1577,129,268,1139,1479,802,43,98,559,616,674,705,720,787,812,828,902,1045,1050,1057,1193,1203,1480,2082,2113,1575,1028,32,1113,1517,1185,31,226,373,471,684,739,1162,1406,2120,1312,1146,13,275,600,1453,598,244,410,2090,537,1261,1361,117,240,1054,1352,573,48,439,1059,366,1572,2118,390,94,381,607,88,106,214,245,309,317,329,418,448,451,461,463,508,525,535,543,546,558,562,564,567,590,594,596,604,609,630,635,639,668,673,679,681,686,689,692,697,702,707,709,722,755,770,792,795,808,826,847,857,879,889,929,931,934,949,967,1005,1036,1058,1067,1068,1077,1106,1144,1178,1214,1219,1226,1234,1320,1335,1349,1377,1379,1389,1418,1421,1449,1457,1461,1491,2069,2073,2084,2117);

	UPDATE Cust_txns
	SET Is_in_top_sub_Area_1_N = 'Y'
	WHERE subject_area_id IN 
	(1331,2089,141,1488,1383,1356,444,50,1372,777,1314,362,1416,1402,221,1360,1327,189,360,1277,27,119,1519,585,63,125,1558,1348,1092,628,133,86,1530,1540,269,220,380,452,127,1525,2111,1194,658,334,1559,1553,403,68,1357,1026,1547,304,1554,1515,225,581,368,338,331,441,2079,416,235,1542,1534,58,1541,1041,408,1,429,1490,569,1513,236,212,2122,2083,1573,1496,1478,1446,1441,1391,1370,1367,1364,1355,1324,1290,1254,1243,1237,1188,1179,1115,1103,1096,1085,1072,1066,1034,1032,1006,992,988,923,901,865,824,820,815,798,747,741,734,711,695,669,667,633,615,606,599,586,505,449,412,348,344,325,321,277,267,256,238,219,206,195,120,115,109,82,2119,1529,53,2107,137,391,12,1552,1233,307,1195,260,1536,1562,1097,124,128,72,2110,462,566,1296,431,183,393,572,51,243,2106,1294,249,188,1403,70,97,1436,1049,185,2087,1396,1365,1040,294,38,1523,756,752,664,587,295,1571,1561,2095,816,428,252,149,62,372,8,1069,746,1514,1358,215,21,2078,1303,1560,1279,1062,789,745,169,2100,574,1319,638,4,450,242,1417,1286,769,544,434,140,254,1201,1047,34,24,15,332,1287,322,1483,111,1070,671,625,1325,1157,804,729,579,326,194,187,166,1556,306,291,80,102,2086,1512,1511,1126,422,387,314,1090,259,324,469,184,126,1544,39,1405,1385,2108,178,1532,1563,1181,1088,807,783,247,172,33,79,47,426,1063,706,44,290,1431,1522,1505,1497,107,805,1313,670,442,1485,162,1087,274,112,374,339,2123,1455,1435,1387,1346,1323,1315,1282,1278,1212,1190,1154,1152,1151,1148,1147,1055,890,839,784,773,663,629,626,541,529,510,474,472,464,435,357,255,158,151,40,1555,1551,37,57,241,311,323,1145,371,1526,272,224,2099,1065,1520,1539,378,384,258,1114,257,588,568,2093,1527,193,1404,413,721,1298,1285,1334,199,46,118,190,1499,1473,1433,1388,1231,1153,1052,940,938,862,797,738,631,613,595,563,548,530,421,415,375,299,217,213,65,1301,1567,1332,1299,969,91,78,303,154,35,239,1401,1170,1135,911,888,465,460,454,17,328,377,1105,1410,1447,751,1493,121,2115,2076,1171,941,860,425,66,575,576,570,392,30,1550,248,1098,2114,591,417,310,250,1407,395,108,104,1297,1263,1518,1568,135,1109,71,69,1475,2117,2084,2073,2069,1491,1461,1457,1449,1421,1418,1389,1379,1377,1349,1335,1320,1234,1226,1219,1214,1178,1144,1106,1077,1068,1067,1058,1036,1005,967,949,934,931,929,889,879,857,847,826,808,795,792,770,755,722,709,707,702,697,692,689,686,681,679,673,668,639,635,630,609,604,596,594,590,567,564,562,558,546,543,535,525,508,463,461,451,448,418,329,317,309,245,214,106,88,607,381,94,390,2118,1572,366,1059,439,48,573,1352,1054,240,117,1361,1261,537,2090,410,244,598,1453,600,275,13,1146,1312,2120,1406,1162,739,684,471,373,226,31,1185,1517,1113,32,1028,1575,2113,2082,1480,1203,1193,1057,1050,1045,902,828,812,787,720,705,674,616,559,98,43,802,1479,1139,268,129,1577,1481,1448,854,445,433,2121,2068,1463,1462,1460,1456,1451,1424,1420,1378,1340,1321,1273,1253,1252,1220,1205,1175,1166,1127,1122,1023,990,977,944,935,930,927,906,898,884,868,863,846,833,823,822,788,754,735,718,713,687,685,677,656,653,646,643,619,612,610,597,555,545,518,512,503,499,382,170,159,153,130);

	/*
				computing top subject area for the time period 2015-2016 (Aug-Aug Cycle)
		
	Is_in_top_sub_Area_2015_2016_N is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1_2015_2016_N is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	
	
	*/
	
	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2015_2016_N varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_2015_2016_N varchar(2) default 'N';


	UPDATE SVOC  
	SET Is_in_top_sub_Area_2015_2016_N = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_N = 'Y' and transact_date BETWEEN '2015-04-01' AND '2016-03-31');

	UPDATE SVOC  
	SET Is_in_top_sub_Area_1_2015_2016_N = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_1_N = 'Y' and transact_date BETWEEN '2015-04-01' AND '2016-03-31');
	
	/* Vintage is the number of days from the FTD of the customer till the last date of the observational time period, it is used to measure the number of days customer was active in the system

	New_or_existing_in_2015_2016_N is an indicator variable for measuring whether customer transacted in time period 2015-08-29 AND 2016-08-28
	
	*/
	
	# Vintage(From 2016-08-28) and New or existing in (2015-16)

	ALTER TABLE SVOC
	add column Vintage_2015_2016_N int,
	add column New_or_existing_in_2015_2016_N varchar(10) ;

	UPDATE SVOC
	set Vintage_2015_2016_N = TIMESTAMPdiff(MONTH, FTD, '2016-03-31'),
	New_or_existing_in_2015_2016_N = CASE WHEN FTD BETWEEN '2015-04-01' AND '2016-03-31' THEN 'new' ELSE 'existing' END;

	describe SVOC;

	/* Obtaining number of paid-mre, valid mre and quality re-edit for the period 2015-2016 */
	
	# Number of paid-mre, valid-mre, qualityre-edit in 2015-2016
		
	drop table mre;
	create temporary table mre as
	select eos_user_id,enquiry_id,left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client' and price_after_tax is not null and price_after_tax > 0 
	group by eos_user_id,enquiry_id;

	ALTER TABLE SVOC
	ADD Column No_of_paid_mre_in_2015_2016_N int default 0,
	ADD Column No_of_valid_mre_in_2015_2016_N int default 0,
	ADD Column No_of_quality_reedit_mre_in_2015_2016_N int default 0;


	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='paid-mre' and transact_date BETWEEN '2015-04-01' AND '2016-03-31'  GROUP BY eos_user_id) B
	set A.No_of_paid_mre_in_2015_2016_N = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='valid-mre' and transact_date BETWEEN '2015-04-01' AND '2016-03-31' GROUP BY eos_user_id) B
	set A.No_of_valid_mre_in_2015_2016_N = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='quality-re_edit' and transact_date BETWEEN '2015-04-01' AND '2016-03-31' GROUP BY eos_user_id) B
	set A.No_of_quality_reedit_mre_in_2015_2016_N = B.count
	where A.eos_user_id = B.eos_user_id;

	/* Obtaining ratio of paid-mre, valid-mre and quality re-edit for the period 2015-2016 */
	
	ALTER TABLE SVOC
	ADD Column Ratio_paid_mre_to_total_orders_2015_2016_N double,
	ADD Column Ratio_valid_mre_to_total_orders_2015_2016_N double,
	ADD Column Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N double;

	UPDATE SVOC
	SET Ratio_paid_mre_to_total_orders_2015_2016_N = No_of_paid_mre_in_2015_2016_N / frequency_2015_2016_N,
	Ratio_valid_mre_to_total_orders_2015_2016_N = No_of_valid_mre_in_2015_2016_N / frequency_2015_2016_N,
	Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N = No_of_quality_reedit_mre_in_2015_2016_N / frequency_2015_2016_N;
	
	###########################
	
	/* 
	Favourite subject area id in time period 2015-2016 
	Favourite SA 1 in time period 2015-2016 
	Favourite SA 1.6 in time period 2015-2016 
	*/
	
	ALTER TABLE SVOC
	ADD COLUMN Favourite_subject_2015_2016_N int(11) ,
	ADD COLUMN Favourite_SA1_name_2015_2016_N varchar(100),
	ADD COLUMN Favourite_SA1_5_name_2015_2016_N varchar(100),
	ADD COLUMN Favourite_SA1_6_name_2015_2016_N varchar(100);

	select Favourite_SA1_name_2015_2016_N FROM SVOC;


	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2015_2016_N = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2015_2016_N =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

    UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2015_2016_N =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		
	 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2015_2016_N =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);
	
	

	
    	/* Percentage of the paid-mre, valid-mre and quality-re-edit cases in the time period 2015-2016 (Aug-Aug cycle)*/
	
	alter table SVOC 
	add column percent_paid_mre_2015_2016_N double,
	add column percent_valid_mre_2015_2016_N double,
	add column percent_quality_reedit_2015_2016_N double;

	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id 
	group by eos_user_id,enquiry_id;

	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(*) as percent_paid_mre from mre  where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id ) B
	set A.percent_paid_mre_2015_2016_N=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(*) as percent_valid_mre from mre  where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id ) B
	set A.percent_valid_mre_2015_2016_N=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(*) as percent_quality_reedit from mre  where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id ) B
	set A.percent_quality_reedit_2015_2016_N=B.percent_quality_reedit
	where A.eos_user_id=B.eos_user_id;	
	
	/* Number of times customer has given rating in the time period 2015-2016 (Aug-Aug cycle) */
	
	alter table SVOC 
	add column Number_of_times_rated_2015_2016_N int(5);
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id) B
	set Number_of_times_rated_2015_2016_N=rate_count
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC add column is_delay_2015_2016_N varchar(2);
	
	update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31') B
	set is_delay_2015_2016_N='Y'
	where Average_Delay_2015_2016_N >0  and Average_Delay_2015_2016_N is not null and A.eos_user_id=B.eos_user_id;

	
	#################    Favourite Service

	alter table SVOC
	add column Favourite_service_segment_2015_2016_N int(5);

	alter table SVOC
	add index(Favourite_service);

	alter table service
	add index(id);

	alter table SVOC add column Favourite_service_2015_2016_N varchar(20);
	 UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service_2015_2016_N=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date BETWEEN '2015-04-01' AND '2016-03-31' group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment_2015_2016_N=B.service_segment
	where A.Favourite_service_2015_2016_N=B.id;	
	
		ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area_2015_2016_N int,
	add column No_of_Revision_in_price_after_tax_2015_2016_N int,
	add column No_of_Revision_in_service_id_2015_2016_N int,
	add column No_of_Revision_in_delivery_date_2015_2016_N int,
	add column No_of_Revision_in_words_2015_2016_N int;


	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	where transact_date between '2015-04-01' and '2016-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area_2015_2016_N = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	where transact_date between '2015-04-01' and '2016-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax_2015_2016_N = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	where transact_date between '2015-04-01' and '2016-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id_2015_2016_N = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	where transact_date between '2015-04-01' and '2016-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date_2015_2016_N = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	where transact_date between '2015-04-01' and '2016-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words_2015_2016_N = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;
	
		update SVOC A,(select eos_user_id,avg(case when transact_date between '2015-04-01' and '2016-03-31' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_2015_2016_N=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_2015_2016_N=datediff('2016-03-31',LTD_2015_2016_N)
	where frequency_2015_2016_N is not null;
    
	alter table SVOC
    add column ADGBT_2015_2016_N int(5),
    add column Inactivity_ratio_2015_2016_N double,
    add column STD_2015_2016_N date,
    add column Bounce_2015_2016_N int(11),
    add column Total_Standard_price_2015_2016_N decimal(18,6);
    
	update SVOC
	set ADGBT_2015_2016_N=datediff(LTD_2015_2016_N,FTD_2015_2016_N)/(frequency_2015_2016_N-1)
	 where (fiscal_2015='Y' ) and frequency_2015_2016_N is not null;

	update SVOC
	set Inactivity_ratio_2015_2016_N = Recency_2015_2016_N/ADGBT_2015_2016_N;

	set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_2015_2016_N = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2015-04-01' and '2016-03-31'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_2015_2016_N > 1 ;
            
	update SVOC
	set Bounce_2015_2016_N = datediff(STD_2015_2016_N,FTD_2015_2016_N)
	where frequency_2015_2016_N>1 and STD_2015_2016_N is not null;
    
	update SVOC A,(select eos_user_id,
	sum(case when transact_date between '2015-04-01' and '2016-03-31' then Standardised_Price end) as Total_Standard_price_2015_2016_N 
	from Cust_txns  group by eos_user_id) B
		set A.Total_Standard_price_2015_2016_N=B.Total_Standard_price_2015_2016_N
	where A.eos_user_id=B.eos_user_id;
		
		
    alter table SVOC add column enquiry_job_ratio_2015_2016_N double; 
	update SVOC A,(select B.eos_user_id,count(case when  component_type='job' and price_after_tax is not null and price_after_tax>0 and type='normal' and left(A.created_date,10) between '2015-04-01' and '2016-03-31' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio_2015_2016_N=A.frequency_2015_2016_year/B.enquiries
	where A.eos_user_id=B.eos_user_id;	
	
	alter table SVOC add column distinct_translators_2015_2016_N int;
	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators_2015_2016 from Cust_txns where transact_date between '2015-04-01' and '2016-03-31' group by eos_user_id) B
	set A.distinct_translators_2015_2016_N=B.distinct_translators_2015_2016
	where A.eos_user_id=B.eos_user_id; /* Different types of translators for each customer in the time period 2015-04-01 and 2016-03-31*/

	alter table SVOC 
	add column is_preferred_transalator_2015_2016_N varchar(2);/* indicator variable whether the customer has preferred translator or not in the entire_lifetime Aug-Aug cycle 2015-2016 */

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2015-04-01' and '2016-03-31') B
	set A.is_preferred_transalator_2015_2016_N='Y'
	where A.eos_user_id=B.eos_user_id;
	
	#####################        MVC creation        ###############
	
	
	alter table SVOC
	add column Active_fiscal_years_2016_2017 int(5);
	
	update SVOC A,
	(select eos_user_id,count(distinct(fiscal_transact_year)) as Distinct_years from Cust_txns where transact_date between '2004-04-01' and '2017-03-31' group by eos_user_id) B
	set A.Active_fiscal_years_2016_2017=B.Distinct_years
	where A.eos_user_id=B.eos_user_id;
	
	/* Total spend fiscal wise */
	
	alter table SVOC add column fiscal_Standardised_Value_2017 double;
	
	update SVOC A,
	(select eos_user_id,sum(Standardised_Price) as fiscal_Standardised_Value_2017 from Cust_txns where transact_date between '2004-04-01' and '2017-03-31' group by eos_user_id) B
	set A.fiscal_Standardised_Value_2017=B.fiscal_Standardised_Value_2017
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC
	add column Annualized_fiscal_value_2017 double;
	
	update SVOC
	set Annualized_fiscal_value_2017=(fiscal_Standardised_Value_2017/Active_fiscal_years_2016_2017);
	
	alter table SVOC
	add column Updated_MVC_16_17 varchar(2) default 'N';

	update SVOC
	set Updated_MVC_16_17='Y'
	where Annualized_fiscal_value_2017>=420.74 and frequency_2016_2017_N>=3;
	
	
	####### updated time period for 2016-2017 ######
	
		###########################   2016_2017_N #########################
	
	/* computing variables for the time period 2015-2016 for modelling purposes */
	
	alter table SVOC add column percent_not_acceptable_cases_2016_2017_N float(2);
	alter table SVOC add column percent_acceptable_cases_2016_2017_N double;
	alter table SVOC add column percent_not_rated_cases_2016_2017_N double;
	alter table SVOC add column percent_outstanding_cases_2016_2017_N double;
	alter table SVOC add column percent_discount_cases_2016_2017_N double;
	alter table SVOC add column percent_delay_cases_2016_2017_N double;
	alter table SVOC add column Range_of_services_2016_2017_N int(5);
	alter table SVOC add column Range_of_subjects_2016_2017_N int(5);
	alter table SVOC add column Average_word_count_2016_2017_N int(5);
	alter table SVOC add column Average_Delay_2016_2017_N int(5);
	alter table SVOC add column Favourite_Month_2016_2017_N varchar(2);
	alter table SVOC add column Favourite_Time_2016_2017_N varchar(4);
	alter table SVOC add column Favourite_Day_Week_2016_2017_N varchar(2);
	alter table SVOC add column Week_number_2016_2017_N varchar(2);
	alter table SVOC add column maximum_rating_2016_2017_N varchar(10);
	alter TABLE SVOC add column Ever_rated_2016_2017_N varchar(2) default 'N';
	alter table SVOC
	add column  ATV_2016_2017_N int(10),
	add column frequency_2016_2017_N int(4),
	add column Recency_2016_2017_N int(5),
	add column FTD_2016_2017_N date,
	add column LTD_2016_2017_N date;
	
	
	update SVOC A,(select eos_user_id,min(transact_date) as FTD_1_years,max(transact_date) as LTD_1_years, count(distinct(enquiry_id)) as frequency_1_year from (select eos_user_id,transact_date,enquiry_id from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31') B group by eos_user_id) B
	set A.FTD_2016_2017_N=B.FTD_1_years,A.LTD_2016_2017_N=B.LTD_1_years,A.frequency_2016_2017_N=B.frequency_1_year
	where A.eos_user_id=B.eos_user_id ;

	
	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
		where rate is not null AND transact_date between '2016-04-01' AND '2017-03-31'
		GROUP BY eos_user_id) B
		set Ever_rated_2016_2017_N = 'Y' 
		WHERE A.eos_user_id = B.eos_user_id;

	update SVOC A, (select eos_user_id, round(count(distinct( case when rate ='not-acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.percent_not_acceptable_cases_2016_2017_N=B.rate
	where A.eos_user_id=B.eos_user_id;



	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='acceptable'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.percent_acceptable_cases_2016_2017_N =B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate is null then enquiry_id end))/count(*),2) as percent_not_rated_cases from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.percent_not_rated_cases_2016_2017_N=B.percent_not_rated_cases
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when rate ='outstanding'then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.percent_outstanding_cases_2016_2017_N=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when discount>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.percent_discount_cases_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,round(count(distinct( case when delay>0 then enquiry_id end))/count(*),2) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.percent_delay_cases_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(service_id)) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Range_of_services_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,count(distinct(subject_area_id)) as Range_of_subjects from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Range_of_subjects_2016_2017_N= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC
	add column Range_of_subjects_1_6_2016_2017_N int;
	
	update SVOC A, (select eos_user_id,count(distinct(SA1_6_id)) as Range_of_subjects from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Range_of_subjects_1_6_2016_2017_N= B.Range_of_subjects
	where A.eos_user_id=B.eos_user_id;
	
	update SVOC A, (select eos_user_id,avg(unit_count) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Average_word_count_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,ROUND(avg(delay)) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B
	set A.Average_Delay_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(MONTH FROM created_date)) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Favourite_Month_2016_2017_N=B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(Extract(HOUR FROM created_date)) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Favourite_Time_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX(DAYOFWEEK(created_date)) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Favourite_Day_Week_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;

	update SVOC A, (select eos_user_id,MAX((FLOOR((DAYOFMONTH(created_date) - 1) / 7) + 1)) as rate from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B 
	set A.Week_number_2016_2017_N= B.rate
	where A.eos_user_id=B.eos_user_id;



	UPDATE IGNORE
				SVOC A
			SET 
				maximum_rating_2016_2017_N = (
						SELECT 
							rate
						FROM (select eos_user_id,rate,count(*) as ratings,sum(price_after_tax) as sum from (select * from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31') A group by eos_user_id,rate order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
				);

		
	/* percentage of cases where coupon_code was applied in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	alter table SVOC
	add column percent_offer_cases_2016_2017_N int(8);

	update SVOC A,(select eos_user_id,round(count(distinct( case when offer_code is not null then enquiry_id end)) *100/count(*),2) as percent_offer_cases from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B
	set A.percent_offer_cases_2016_2017_N=B.percent_offer_cases 
	where A.eos_user_id=B.eos_user_id;
	
	/* indicator variable for tagging whether has rated in outstanding, not acceptable or acceptable in the time period 29th Aug 2015 to 28th Aug 2016 */
	
	ALTER TABLE SVOC
	add column Ever_rated_outstanding_2016_2017_N varchar(2) default 'N',
	add column Ever_rated_acceptable_2016_2017_N varchar(2) default 'N',
	add column Ever_rated_not_acceptable_2016_2017_N varchar(2) default 'N';


	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'outstanding' AND transact_date between '2016-04-01' AND '2017-03-31'
	GROUP BY eos_user_id) B
	set Ever_rated_outstanding_2016_2017_N = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'acceptable' AND transact_date between '2016-04-01' AND '2017-03-31'
	GROUP BY eos_user_id) B
	set Ever_rated_acceptable_2016_2017_N = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (select eos_user_id FROM Cust_txns
	where rate = 'not-acceptable' AND transact_date between '2016-04-01' AND '2017-03-31'
	GROUP BY eos_user_id) B
	set Ever_rated_not_acceptable_2016_2017_N = 'Y'
	WHERE A.eos_user_id = B.eos_user_id;


	describe SVOC;

	# Is subject_area_id in top Subject Areas.
	
	
	
	/*
				computing top subject area for the time period 2015-2016 (Aug-Aug Cycle)
		
	Is_in_top_sub_Area_2016_2017_N is an indicator variable whether the customer has selected subject_area which fell in the top decile among the MVCs 
	Is_in_top_sub_Area_1_2016_2017_N is similarly computed where the number of top deciles varied from the Is_in_top_sub_Area
	
	
	*/
	
	ALTER TABLE SVOC
	ADD Column  Is_in_top_sub_Area_2016_2017_N varchar(2) default 'N',
	ADD Column Is_in_top_sub_Area_1_2016_2017_N varchar(2) default 'N';


	UPDATE SVOC  
	SET Is_in_top_sub_Area_2016_2017_N = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_N = 'Y' and transact_date between '2016-04-01' AND '2017-03-31');

	UPDATE SVOC  
	SET Is_in_top_sub_Area_1_2016_2017_N = 'Y'
	WHERE eos_user_id IN 
	(SELECT eos_user_id FROM Cust_txns
	WHERE Is_in_top_sub_Area_1_N = 'Y' and transact_date between '2016-04-01' AND '2017-03-31');
	
	/* Vintage is the number of days from the FTD of the customer till the last date of the observational time period, it is used to measure the number of days customer was active in the system

	New_or_existing_in_2016_2017_N is an indicator variable for measuring whether customer transacted in time period 2015-08-29 AND 2016-08-28
	
	*/
	
	# Vintage(From 2016-08-28) and New or existing in (2015-16)

	ALTER TABLE SVOC
	add column Vintage_2016_2017_N int,
	add column New_or_existing_in_2016_2017_N varchar(10) ;

	UPDATE SVOC
	set Vintage_2016_2017_N = TIMESTAMPdiff(MONTH, FTD, '2017-03-31'),
	New_or_existing_in_2016_2017_N = CASE WHEN FTD between '2016-04-01' AND '2017-03-31' THEN 'new' ELSE 'existing' END;

	describe SVOC;

	/* Obtaining number of paid-mre, valid mre and quality re-edit for the period 2015-2016 */
	
	# Number of paid-mre, valid-mre, qualityre-edit in 2015-2016
		
	drop table mre;
	create temporary table mre as
	select eos_user_id,enquiry_id,left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id and component_type='job' and B.status='send-to-client' and price_after_tax is not null and price_after_tax > 0 
	group by eos_user_id,enquiry_id;

	ALTER TABLE SVOC
	ADD Column No_of_paid_mre_in_2016_2017_N int default 0,
	ADD Column No_of_valid_mre_in_2016_2017_N int default 0,
	ADD Column No_of_quality_reedit_mre_in_2016_2017_N int default 0;


	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='paid-mre' and transact_date between '2016-04-01' AND '2017-03-31'  GROUP BY eos_user_id) B
	set A.No_of_paid_mre_in_2016_2017_N = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='valid-mre' and transact_date between '2016-04-01' AND '2017-03-31' GROUP BY eos_user_id) B
	set A.No_of_valid_mre_in_2016_2017_N = B.count
	where A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A, (SELECT eos_user_id, count(DISTINCT enquiry_id) as count FROM mre WHERE type='quality-re_edit' and transact_date between '2016-04-01' AND '2017-03-31' GROUP BY eos_user_id) B
	set A.No_of_quality_reedit_mre_in_2016_2017_N = B.count
	where A.eos_user_id = B.eos_user_id;

	/* Obtaining ratio of paid-mre, valid-mre and quality re-edit for the period 2015-2016 */
	
	ALTER TABLE SVOC
	ADD Column Ratio_paid_mre_to_total_orders_2016_2017_N double,
	ADD Column Ratio_valid_mre_to_total_orders_2016_2017_N double,
	ADD Column Ratio_quality_re_edit_mre_to_total_orders_2016_2017_N double;

	UPDATE SVOC
	SET Ratio_paid_mre_to_total_orders_2016_2017_N = No_of_paid_mre_in_2016_2017_N / frequency_2016_2017_N,
	Ratio_valid_mre_to_total_orders_2016_2017_N = No_of_valid_mre_in_2016_2017_N / frequency_2016_2017_N,
	Ratio_quality_re_edit_mre_to_total_orders_2016_2017_N = No_of_quality_reedit_mre_in_2016_2017_N / frequency_2016_2017_N;
	
	###########################
	
	/* 
	Favourite subject area id in time period 2015-2016 
	Favourite SA 1 in time period 2015-2016 
	Favourite SA 1.6 in time period 2015-2016 
	*/
	
	ALTER TABLE SVOC
	ADD COLUMN Favourite_subject_2016_2017_N int(11) ,
	ADD COLUMN Favourite_SA1_name_2016_2017_N varchar(100),
	ADD COLUMN Favourite_SA1_5_name_2016_2017_N varchar(100),
	ADD COLUMN Favourite_SA1_6_name_2016_2017_N varchar(100);

	select Favourite_SA1_name_2016_2017_N FROM SVOC;


	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_subject_2016_2017_N = (
						SELECT 
							subject_area_id
						FROM (select eos_user_id,subject_area_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id,subject_area_id order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);

	UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_name_2016_2017_N =(
						SELECT 
							SA1
						FROM (select eos_user_id,SA1,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id,SA1 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		

    UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_5_name_2016_2017_N =(
						SELECT 
							SA1_5
						FROM (select eos_user_id,SA1_5,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id,SA1_5 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);		
	 UPDATE IGNORE
				SVOC A
			SET 
				Favourite_SA1_6_name_2016_2017_N =(
						SELECT 
							SA1_6
						FROM (select eos_user_id,SA1_6,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id,SA1_6 order by ratings desc,sum desc) B
						WHERE
							A.eos_user_id = B.eos_user_id
						ORDER BY ratings desc,sum desc
						LIMIT 1
					);
	
	

	
    	/* Percentage of the paid-mre, valid-mre and quality-re-edit cases in the time period 2015-2016 (Aug-Aug cycle)*/
	
	alter table SVOC 
	add column percent_paid_mre_2016_2017_N double,
	add column percent_valid_mre_2016_2017_N double,
	add column percent_quality_reedit_2016_2017_N double;

	create temporary table mre as
	select eos_user_id,enquiry_id,Left(B.created_date,10) as transact_date,type from enquiry A,component B
	where A.id=B.enquiry_id 
	group by eos_user_id,enquiry_id;

	update SVOC A,(select eos_user_id,count(case when type='paid-mre'then type end)/count(*) as percent_paid_mre from mre  where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id ) B
	set A.percent_paid_mre_2016_2017_N=B.percent_paid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='valid-mre'then type end)/count(*) as percent_valid_mre from mre  where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id ) B
	set A.percent_valid_mre_2016_2017_N=B.percent_valid_mre
	where A.eos_user_id=B.eos_user_id;

	update SVOC A,(select eos_user_id,count(case when type='quality-re_edit'then type end)/count(*) as percent_quality_reedit from mre  where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id ) B
	set A.percent_quality_reedit_2016_2017_N=B.percent_quality_reedit
	where A.eos_user_id=B.eos_user_id;	
	
	/* Number of times customer has given rating in the time period 2015-2016 (Aug-Aug cycle) */
	
	alter table SVOC 
	add column Number_of_times_rated_2016_2017_N int(5);
	
	update SVOC A,(select eos_user_id,count(case when rate is not null then enquiry_id end) as rate_count from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id) B
	set Number_of_times_rated_2016_2017_N=rate_count
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC add column is_delay_2016_2017_N varchar(2);
	
	update SVOC A,(select distinct eos_user_id from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31') B
	set is_delay_2016_2017_N='Y'
	where Average_Delay_2016_2017_N >0  and Average_Delay_2016_2017_N is not null and A.eos_user_id=B.eos_user_id;

	
	#################    Favourite Service

	alter table SVOC
	add column Favourite_service_segment_2016_2017_N int(5);

	alter table SVOC
	add index(Favourite_service);

	alter table service
	add index(id);

	alter table SVOC add column Favourite_service_2016_2017_N varchar(20);
	 
	UPDATE IGNORE
			SVOC A
		SET 
			Favourite_service_2016_2017_N=(
					SELECT 
						service_id
					FROM (select eos_user_id,service_id,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns where transact_date between '2016-04-01' AND '2017-03-31' group by eos_user_id,service_id order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1
				);		

	set sql_safe_updates=0;
	update SVOC A,service B
	set A.Favourite_service_segment_2016_2017_N=B.service_segment
	where A.Favourite_service_2016_2017_N=B.id;	
	
		ALTER TABLE SVOC
	add column No_of_Revision_in_subject_area_2016_2017_N int,
	add column No_of_Revision_in_price_after_tax_2016_2017_N int,
	add column No_of_Revision_in_service_id_2016_2017_N int,
	add column No_of_Revision_in_delivery_date_2016_2017_N int,
	add column No_of_Revision_in_words_2016_2017_N int;


	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_subject_area = 'Y' then enquiry_id END) No_of_Revision_in_subject_area FROM Cust_txns
	where transact_date between '2016-04-01' and '2017-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_subject_area_2016_2017_N = B.No_of_Revision_in_subject_area
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_price_after_tax = 'Y' then enquiry_id END) No_of_Revision_in_price_after_tax FROM Cust_txns
	where transact_date between '2016-04-01' and '2017-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_price_after_tax_2016_2017_N = B.No_of_Revision_in_price_after_tax
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_service_id = 'Y' then enquiry_id END) No_of_Revision_in_service_id FROM Cust_txns
	where transact_date between '2016-04-01' and '2017-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_service_id_2016_2017_N = B.No_of_Revision_in_service_id
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_delivery_date = 'Y' then enquiry_id END) No_of_Revision_in_delivery_date FROM Cust_txns
	where transact_date between '2016-04-01' and '2017-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_delivery_date_2016_2017_N = B.No_of_Revision_in_delivery_date
	WHERE A.eos_user_id = B.eos_user_id;

	UPDATE SVOC A,
	(SELECT eos_user_id, count(CASE WHEN Revision_in_words = 'Y' then enquiry_id END) No_of_Revision_in_words FROM Cust_txns
	where transact_date between '2016-04-01' and '2017-03-31'
	GROUP BY eos_user_id) B
	set A.No_of_Revision_in_words_2016_2017_N = B.No_of_Revision_in_words
	WHERE A.eos_user_id = B.eos_user_id;
	
		ALTER TABLE SVOC
	add column ratio_of_Revision_in_subject_area_2016_2017_N double,
	add column ratio_of_Revision_in_price_after_tax_2016_2017_N double,
	add column ratio_of_Revision_in_service_id_2016_2017_N double,
	add column ratio_of_Revision_in_delivery_date_2016_2017_N double,
	add column ratio_of_Revision_in_words_2016_2017_N double;

	update SVOC
	set 
	ratio_of_Revision_in_subject_area_2016_2017_N =No_of_Revision_in_subject_area_2016_2017_N/frequency_2016_2017_N
	,ratio_of_Revision_in_price_after_tax_2016_2017_N =No_of_Revision_in_price_after_tax_2016_2017_N/frequency_2016_2017_N,
	ratio_of_Revision_in_service_id_2016_2017_N =No_of_Revision_in_service_id_2016_2017_N/frequency_2016_2017_N,
	ratio_of_Revision_in_delivery_date_2016_2017_N =No_of_Revision_in_delivery_date_2016_2017_N/frequency_2016_2017_N,
	ratio_of_Revision_in_words_2016_2017_N=No_of_Revision_in_words_2016_2017_N/frequency_2016_2017_N;
	
	
	update SVOC A,(select eos_user_id,avg(case when transact_date between '2016-04-01' and '2017-03-31' then Standardised_Price end) as ATV_1_year from Cust_txns group by eos_user_id) B
	set A.ATV_2016_2017_N=
	case when 
	B.ATV_1_year is null then 0 else B.ATV_1_year end
	where A.eos_user_id=B.eos_user_id ;

	update SVOC
	set Recency_2016_2017_N=datediff('2017-03-31',LTD_2016_2017_N)
	where frequency_2016_2017_N is not null;
    
	alter table SVOC
    add column ADGBT_2016_2017_N int(5),
    add column Inactivity_ratio_2016_2017_N double,
    add column STD_2016_2017_N date,
    add column Bounce_2016_2017_N int(11),
    add column Total_Standard_price_2016_2017_N decimal(18,6);
    
	update SVOC
	set ADGBT_2016_2017_N=datediff(LTD_2016_2017_N,FTD_2016_2017_N)/(frequency_2016_2017_N-1)
	 where (fiscal_2016='Y' ) and frequency_2016_2017_N is not null;

	update SVOC
	set Inactivity_ratio_2016_2017_N = Recency_2016_2017_N/ADGBT_2016_2017_N;

	set sql_safe_updates=0;
	 UPDATE IGNORE
			SVOC A
		SET 
			STD_2016_2017_N = (
					SELECT 
						transact_date
					FROM Cust_txns AS B
					WHERE
						A.eos_user_id = B.eos_user_id
					and transact_date between '2016-04-01' and '2017-03-31'
					ORDER BY transact_date ASC
					LIMIT 1,1
				)
		WHERE 
			frequency_2016_2017_N > 1 ;
            
	update SVOC
	set Bounce_2016_2017_N = datediff(STD_2016_2017_N,FTD_2016_2017_N)
	where frequency_2016_2017_N>1 and STD_2016_2017_N is not null;
    
	update SVOC A,(select eos_user_id,
	sum(case when transact_date between '2016-04-01' and '2017-03-31' then Standardised_Price end) as Total_Standard_price_2016_2017_N 
	from Cust_txns  group by eos_user_id) B
		set A.Total_Standard_price_2016_2017_N=B.Total_Standard_price_2016_2017_N
	where A.eos_user_id=B.eos_user_id;
		
		
    alter table SVOC add column enquiry_job_ratio_2016_2017_N double; 
	update SVOC A,(select B.eos_user_id,count(case when  component_type='job' and price_after_tax is not null and price_after_tax>0 and type='normal' and left(A.created_date,10) between '2016-04-01' and '2017-03-31' then A.enquiry_id end) as enquiries from component A,enquiry B where A.enquiry_id=B.id group by eos_user_id) B
	set A.enquiry_job_ratio_2016_2017_N=A.frequency_2016_2017_year/B.enquiries
	where A.eos_user_id=B.eos_user_id;	
	
	alter table SVOC add column distinct_translators_2016_2017_N int;
	update SVOC A,(select eos_user_id,count(distinct wb_user_id) as distinct_translators_2016_2017 from Cust_txns where transact_date between '2016-04-01' and '2017-03-31' group by eos_user_id) B
	set A.distinct_translators_2016_2017_N=B.distinct_translators_2016_2017
	where A.eos_user_id=B.eos_user_id; /* Different types of translators for each customer in the time period 2015-04-01 and 2016-03-31*/

	alter table SVOC 
	add column is_preferred_transalator_2016_2017_N varchar(2);/* indicator variable whether the customer has preferred translator or not in the entire_lifetime Aug-Aug cycle 2015-2016 */

	update SVOC A,(select * from favourite_editor where status='favourite' and created_date between '2016-04-01' and '2017-03-31') B
	set A.is_preferred_transalator_2016_2017_N='Y'
	where A.eos_user_id=B.eos_user_id;
			
	alter table SVOC add column Favourite_funding_category_2016_2017_N varchar(255);
	
	UPDATE IGNORE
			SVOC A
		SET Favourite_funding_category_2016_2017_N=(
                    SELECT 
						funding_category
					FROM (select eos_user_id,funding_category,count(*) as ratings,sum(price_after_tax) as sum from Cust_txns 
					where transact_date between '2016-04-01' and '2017-03-31'
					group by eos_user_id,funding_category order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);	

		/*  adding wb_user */

	update FTD_Cust_txns A,component_auction B
	set A.wb_user_id=B.wb_user_allocated_id
	where A.enquiry_id=B.enquiry_id;
		
	   alter table SVOC_First_enquiry 
    add column Source int,
    add column Source_name varchar(100);
	
	    update SVOC_First_enquiry A,eos_USER B
    set A.Source =B.Source
    where A.eos_user_id=B.id;
	
	 update SVOC_First_enquiry A,masters B
    set A.Source_name =B.name
    where A.Source=B.id;

	
	alter table SVOC
	add column First_confirmed_date varchar(10);

	update SVOC A,(select eos_user_id,min(confirmed_date) as confirmed_date
	from Cust_txns
	group by eos_user_id) B
	set A.First_confirmed_date=B.confirmed_date
	where A.eos_user_id=B.eos_user_id;

	alter table SVOC
	add column First_actual_time_for_job_confirmation int;

	update SVOC
	set First_actual_time_for_job_confirmation =DATEDIFF(First_confirmed_date,First_created_date)
	;
	
	alter table SVOC
	add column recent_2015_2016_N_month varchar(15);

	set sql_safe_updates=0;
	update SVOC
	set recent_2015_2016_N_month=
	case when recency_2015_2016_N between 0 and 30 then '0-30' else
	case when recency_2015_2016_N between 31 and 60 then '31-60' else
	case when recency_2015_2016_N between 61 and 90 then '61-90' else
	case when recency_2015_2016_N between 91 and 120 then '91-120' else
	case when recency_2015_2016_N between 121 and 150 then '121-150' else
	case when recency_2015_2016_N between 151 and 180 then '151-180' else
	case when recency_2015_2016_N between 181 and 210 then '181-210' else
	case when recency_2015_2016_N between 211 and 240 then '211-240' else
	case when recency_2015_2016_N between 241 and 270 then '241-270' else
	case when recency_2015_2016_N between 271 and 300 then '271-300' else
	case when recency_2015_2016_N between 301 and 330 then '301-330' else
	case when recency_2015_2016_N between 331 and 366 then '331-366' else 'NA'
	end end end end end end end end end end end end ;
	
	#####################        MVC creation        ###############
	
	
	alter table SVOC
	add column Active_fiscal_years_2016_2017 int(5);
	
	update SVOC A,
	(select eos_user_id,count(distinct(fiscal_transact_year)) as Distinct_years from Cust_txns where transact_date between '2004-04-01' and '2017-03-31' group by eos_user_id) B
	set A.Active_fiscal_years_2016_2017=B.Distinct_years
	where A.eos_user_id=B.eos_user_id;
	
	/* Total spend fiscal wise */
	
	alter table SVOC add column fiscal_Standardised_Value_2017 double;
	
	update SVOC A,
	(select eos_user_id,sum(Standardised_Price) as fiscal_Standardised_Value_2017 from Cust_txns where transact_date between '2004-04-01' and '2017-03-31' group by eos_user_id) B
	set A.fiscal_Standardised_Value_2017=B.fiscal_Standardised_Value_2017
	where A.eos_user_id=B.eos_user_id;
	
	alter table SVOC
	add column Annualized_fiscal_value_2017 double;
	
	update SVOC
	set Annualized_fiscal_value_2017=(fiscal_Standardised_Value_2017/Active_fiscal_years_2016_2017);
	
	alter table SVOC
	add column Updated_MVC_16_17 varchar(2) default 'N';

	update SVOC
	set Updated_MVC_16_17='Y'
	where Annualized_fiscal_value_2017>=420.74 and frequency_2016_2017_N>=3;
	
	
		#####################   Fiscal_tenure     ##############################
	
	alter table SVOC
	add column Tenure_fiscal int(10);

	set sql_safe_updates=0;
	update SVOC 
	set Tenure_fiscal = datediff('2018-03-31',FTD);
	
	alter table SVOC
	add column Updated_MVC_17_18 varchar(2) default 'N';

	update SVOC
	set Updated_MVC_17_18='Y'
	where Annualized_fiscal_value>=420.74 and Frequency_fy_17_18>=3;
	
	##########################  First Transaction variables   #########################
	
	/* computing derived variables for each customer */
	
	alter table SVOC add column First_unit_count int(10);
	alter table SVOC add column First_rate int(10);
	alter table SVOC add column First_subject_area_id int(10);
	alter table SVOC add column First_service_id int(10);
	alter table SVOC add column First_client_instruction_present varchar(2);
	alter table SVOC add column First_delivery_instruction_present varchar(2);
	alter table SVOC add column First_title_present varchar(2);
	alter table SVOC add column First_journal_name_present varchar(2);
	alter table SVOC add column First_use_ediatge_card varchar(2);
	alter table SVOC add column First_editage_card_id int(10);
	alter table SVOC add column First_author_name_present varchar(2);
	
	alter table SVOC 
	add column First_unit_count int(5),
	add column First_rate varchar(15),
	add column First_subject_area_id int(10),
	add column First_service_id int(10);

	alter table SVOC 
	add index(FTD),
	add index(eos_user_id);
	alter table Cust_txns add index(transact_date),add index(eos_user_id);

	Alter Table SVOC
	ADD Column First_txn_Rev_in_subject_area varchar(2),
	ADD Column First_txn_Rev_in_price_after_tax varchar(2),
	ADD Column First_txn_Rev_in_service_id varchar(2),
	ADD Column First_txn_Rev_in_delivery_date varchar(2),
	ADD Column First_txn_Rev_in_words varchar(2);

	UPDATE SVOC A, (SELECT eos_user_id, Revision_in_subject_area, Revision_in_price_after_tax, Revision_in_service_id, Revision_in_delivery_date, Revision_in_words FROM Cust_txns) B
	set A.First_txn_Rev_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A. eos_user_id = B.eos_user_id;

	
	set sql_safe_updates=0;
	Update SVOC A,(select eos_user_id,transact_date,unit_count,rate,subject_area_id,service_id from Cust_txns) B
	set 
	First_unit_count = unit_count,
	First_rate = rate,
	First_subject_area_id = subject_area_id,
	First_service_id = service_id
	where A.FTD=transact_date and A.eos_user_id=B.eos_user_id;
	
	update SVOC A,Cust_txns B
	set A.First_client_instruction_present='Y' 
	where A.FTD=B.transact_date and client_instruction is not null and client_instruction not like '%test%';


	update SVOC A,Cust_txns B
	set First_delivery_instruction_present='Y' 
	where A.FTD=B.transact_date and delivery_instruction is not null and delivery_instruction not like '%test%';

	update SVOC A,Cust_txns B
	set First_title_present='Y' 
	where A.FTD=B.transact_date and title is not null and title not like '%test%';


	update SVOC A,Cust_txns B
	set First_journal_name_present='Y' 
	where A.FTD=B.transact_date and journal_name is not null and journal_name not like '%test%';

	update SVOC A,Cust_txns B
	set First_use_ediatge_card=null'Y' 
	where A.FTD=B.transact_date and use_ediatge_card='Yes' and editage_card_id is not null and use_ediatge_card not like '%test%';

	update SVOC A,Cust_txns B
	set First_use_ediatge_card='Y' 
	where A.FTD=B.transact_date and use_ediatge_card='Yes' and use_ediatge_card not like '%test%';

	update SVOC A,Cust_txns B
	set First_author_name_present='Y' 
	where A.FTD=B.transact_date and author_name is not null and author_name not like '%test%';
	
	########################################################## First transaction variables #################################################################
	
	/* Customer received discount on first transaction or not ? */
	
    # Creating NEW Variables ##
	# 1. First Transaction Discount Recieved.
	ALTER TABLE SVOC add column First_txn_discount varchar(2);
	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,transact_date,discount from Cust_txns where discount >0 and discount is not null) B
	set A.First_txn_discount='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;


	/* Customer received Coupon_used on first transaction or not ? */
	
	# 2. First Transaction Coupon used.
	ALTER TABLE SVOC add column First_txn_Coupon_used varchar(2);
	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,transact_date, offer_code from Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;

	/* Customer received word_count on first transaction or not ? */
	
	# 3. First job wordcount
	ALTER TABLE SVOC drop column First_job_word_count;
	ALTER TABLE SVOC add column First_job_word_count int(10);
	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,transact_date, unit_count from Cust_txns) B
	set A.First_job_word_count =B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD = B.transact_date;
	
	/* Customer received NO_OFQUES on first transaction or not ? */
	
	# 4. First_NoOfQues
	
	ALTER TABLE SVOC add column First_NoOfQues Int;
	update SVOC A, (SELECT eos_user_id, transact_date, NoOfQuestions FROM Cust_txns) B
	set A.First_NoOfQues = B.NoOfQuestions
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;
	
	/* First translator of the customer */
	
	# 5. First Translator/editor
	ALTER TABLE SVOC 
	ADD Column First_trnx_Translator varchar(10);

	SET SQL_SAFE_UPDATES = 0;
	UPDATE SVOC A, (select eos_user_id, transact_date, wb_user_id FROM Cust_txns) B
	SET A.First_trnx_Translator = B.wb_user_id
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;

	# 6. First_trnx_Feedback
	ALTER TABLE SVOC 
	ADD Column First_trnx_Feedback varchar(15);

	SET SQL_SAFE_UPDATES = 0;
	UPDATE SVOC A, (select eos_user_id, transact_date, rate FROM Cust_txns) B
	SET A.First_trnx_Feedback = B.rate
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;
	
	/* indicator variable whether first transaction lead to paid_mre,valid_mre and quality-re_edit */
	
	/*
	First transaction detail variables 
	
	First_Txn_to_paid_mre - whether first transaction led to paid mre
	First_Txn_to_valid_mre - whether first transaction led to valid mre
	First_Txn_to_quality_reedit - whether first transaction led to quality re-edit
	First_Delay - Whether customer faced delay in the first transaction
	*/]
	
	alter table SVOC 
	add column First_Txn_to_paid_mre varchar(2),
	add column First_Txn_to_valid_mre varchar(2),
	add column First_Txn_to_quality_reedit varchar(2),
	add column First_Delay int(6);

	update SVOC A,(Select Delay,eos_user_id,min(Left(created_date,10)) as transact_date from Cust_txns group by Delay,eos_user_id) B
	set A.First_Delay=B.Delay 
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;


	update SVOC A, Cust_txns B
	set A.First_Txn_to_paid_mre = 'Y'
	where A.eos_user_id=B.eos_user_id AND A.FTD=B.transact_date AND B.Txn_to_paid_mre='Y';

	update SVOC A, Cust_txns B
	set A.First_Txn_to_valid_mre = 'Y'
	where A.eos_user_id=B.eos_user_id AND A.FTD=B.transact_date AND B.Txn_to_valid_mre='Y';

	update SVOC A, Cust_txns B
	set A.First_Txn_to_quality_reedit = 'Y'
	where A.eos_user_id=B.eos_user_id AND A.FTD=B.transact_date AND B.Txn_to_quality_re_edit='Y' ;
	
	/* campaign email sent is an indicator variable for identifying customers which have received campaign communication */
	
	alter table SVOC add column campaign_email_sent varchar(2);
	
	update SVOC 
	set campaign_email_sent='Y'
	where First_email_send_date is not null and First_email_send_date >'0000-00-00';

	/* Mode of payment in the first order */
	
	alter table SVOC add column First_payment_type varchar(20);

	update SVOC A,(select eos_user_id,payment_type,min(transact_date) as transact_date from Cust_txns group by eos_user_id) B
	set A.First_payment_type=B.payment_type
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date and payment_type is not null;
	
	/* First order price_after_tax */
	
	alter table SVOC add column First_price_after_tax varchar(10);

	set sql_safe_updates=0;
	update SVOC A,(select eos_user_id,Standardised_Price,min(transact_date) as transact_date from Cust_txns group by eos_user_id) B
	set A.First_price_after_tax=B.Standardised_Price
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date and Standardised_Price is not null;


	
	###########   first job number of components
	
	/* Computing: Number of components in the job */
	
	alter table Cust_txns add column No_service_components int(5);

	alter table Cust_txns add index(service_id);
	alter table process_service_mapping add index(service_id);

	update Cust_txns A,(select service_id,count(distinct id) as component from process_service_mapping group by service_id) B
	set A.No_service_components=B.component
	where A.service_id=B.service_id;
	
	/* First_service_components - Is the number of service components in the first order */
	
	alter table SVOC add column First_service_components int(5);

	update SVOC A,Cust_txns B
	set A.First_service_components=B.No_service_components
	where A.eos_user_id=B.eos_user_id and A.FTD=B.transact_date;

	#################### First Transaction New Variables #################3
	#First_subject_is_in_top_subject_area
	#First_txn_job_completion_time
	#First_feedback_outstanding
	#First_feedback_acceptable
	#First_feedback_non_acceptable

	ALTER TABLE SVOC
	ADD Column First_subject_in_top_subject_areas varchar(2) default 'N',
	ADD Column First_txn_feedback_given varchar (2) default 'N',
	ADD Column First_feedback_outstanding varchar(2) default 'N',
	ADD Column First_feedback_acceptable varchar(2) default 'N',
	ADD Column First_feedback_not_acceptable varchar(2) default 'N',
	ADD Column First_txn_job_completion_time_in_days int(11);

	UPDATE SVOC A, Cust_txns B
	set A.First_subject_in_top_subject_areas = 'Y'
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.Is_in_top_sub_Area = 'Y';

	SELECT eos_user_id, First_subject_in_top_subject_areas FROM SVOC
	WHERE A.First_subject_in_top_subject_areas IS NOT NULL;

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_given = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate is not null;

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_outstanding = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate = 'outstanding';

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_acceptable = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate = 'acceptable';

	UPDATE SVOC A, Cust_txns B
	set A.First_feedback_not_acceptable = 'Y'
	WHERE  A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date AND B.rate = 'not-acceptable';

	UPDATE SVOC A, Cust_txns B
	set A.First_txn_job_completion_time_in_days = B.TimeForJobCompletion/(3600*24)
	WHERE A.eos_user_id = B.eos_user_id AND A.FTD = B.transact_date;

	### Tag Y if country is one of TOP 3 countries.
	ALTER TABLE SVOC
	ADD Column Country_in_top_countries varchar(2) default 'N';

	UPDATE SVOC A
	set Country_in_top_countries = 'Y'
	WHERE Country IN ('Japan','South Korea','China');

	#####################   Fiscal_tenure     ##############################
	
	alter table SVOC
	add column Tenure_fiscal int(10);

	set sql_safe_updates=0;
	update SVOC 
	set Tenure_fiscal = datediff('2018-03-31',FTD);
	

	alter table SVOC
	add column Updated_MVC_17_18 varchar(2) default 'N';

	update SVOC
	set Updated_MVC_17_18='Y'
	where Annualized_fiscal_value>=420.74 and Frequency_fy_17_18>=3;
	
	
	
	#######################################################################################################################
	
	
	ENQUIRY LEVEL MODEL      ##############################################################
				
	
	#######################################################################################################################
	/* creating enquiry base */
	
	
	create table FTD_Cust_txns as
	select * from component
	where type='normal' and component_type='job' and price_after_tax is not null and price_after_tax>0
	and enquiry_id in (select A.id from enquiry A,EOS_USER B where A.eos_user_id=B.id and B.client_type='individual' and B.type='live');


	alter table FTD_Cust_txns
	add column currency_code varchar(10),
	add column wb_user_id varchar(10),
	add index(id),
	add index(enquiry_id);

	alter table component_auction
	add index(enquiry_id);

	set sql_safe_updates=0;
	update FTD_Cust_txns A,Orders B
	set A.currency_code=B.currency_code
	where A.enquiry_id=B.enquiry_id;

	alter table FTD_Cust_txns
	add column eos_user_id int(11);

	update FTD_Cust_txns A,enquiry B
	set A.eos_user_id=B.eos_user_id
	where A.enquiry_id=B.id;

	create table SVOC_First_enquiry as 
	select eos_user_id,min(left(created_date,10)) as FTD
	from FTD_Cust_txns
	group by eos_user_id;
	
	alter table SVOC_First_enquiry add column FTD_created_date date;
	
	update SVOC_First_enquiry A,(select eos_user_id,min(created_date) as FTD_created_date from FTD_Cust_txns group by eos_user_id) B 
	set A.FTD_created_date=B.FTD_created_date where A.eos_user_id=B.eos_user_id;
	
	alter table FTD_Cust_txns
	add column transact_date_1 date,
	add column  transact_date varchar(10);
		
		set sql_safe_updates=0;
		update FTD_Cust_txns
		set transact_date=Left(created_date,10);
		

	alter table SVOC_First_enquiry
	add column First_unit_count int(10),
	add column First_subject_area_id int(10),
	add column First_service_id int(10),
	add column First_client_instruction_present varchar(2),
	add column First_delivery_instruction_present varchar(2),
	add column First_title_present varchar(2),
	add column First_journal_name_present varchar(2),
	add column First_use_ediatge_card varchar(2),
	add column First_editage_card_id int(10),
	add column First_author_name_present varchar(2),
	add column First_payment_type varchar(20),
	add column First_subject_area int(10),
	add column First_price_after_tax int(10),
	add column First_txn_discount varchar(2),
	add column First_txn_Coupon_used varchar(2),
	add column First_job_word_count int(10),
	add column First_NoOfQues int(10),
	add column First_service_components varchar(2);
	
	ALTER TABLE SVOC_First_enquiry 
	add column First_txn_Coupon_used varchar(2);
	ALTER TABLE SVOC_First_enquiry
	add column transacted_or_not varchar(2) default 'N';

	UPDATE SVOC_First_enquiry A, FTD_Cust_txns B
	set A.transacted_or_not = 'Y'
	where A.eos_user_id = B.eos_user_id AND A.FTD_created_date=B.created_date AND status = 'send-to-client';
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date, offer_code from FTD_Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	alter table SVOC_First_enquiry add index(FTD);	
	alter table FTD_Cust_txns add index(created_date);
	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_unit_count=B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_subject_area_id=B.subject_area_id
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_service_id=B.service_id
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;


	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_client_instruction_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.client_instruction not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_delivery_instruction_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.delivery_instruction not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_title_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.title not like ('%test%');


	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_journal_name_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.journal_name not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_journal_name_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.journal_name not like ('%test%');

	alter table FTD_Cust_txns add column invoice_id int(9);

	update FTD_Cust_txns A,Orders B
	set A.invoice_id=B.invoice_id
	where A.enquiry_id=B.enquiry_id and B.invoice_id is not null;

	alter table FTD_Cust_txns add column payment_type varchar(9);


	create temporary table as migration
	select * from master;

	set sql_safe_updates=0;
	update migration
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode'));

	create temporary table mig as 
	select * from masters;

	alter table mig add column payment_mode varchar(20);

	set sql_safe_updates=0;
	update mig
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode'))
	where config_id=48;
	
	###################################################################
	
	alter table FTD_Cust_txns add column payment_type varchar(20);

	alter table FTD_Cust_txns
	add column payment_mode_id varchar(6);

	update FTD_Cust_txns A,(select payment_mode_id,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_mode_id=B.payment_mode_id
	where A.invoice_id=B.invoice_debit_note_id;

	alter table FTD_Cust_txns add index(payment_mode_id);
	alter table mig add index(id);

	alter table FTD_Cust_txns drop column payment_type;
	alter table FTD_Cust_txns add column payment_type varchar(20);
	update FTD_Cust_txns A, mig B
	set A.payment_type=B.payment_mode	
	where A.payment_mode_id=B.id and B.config_id=48;


	set sql_safe_updates=0;
	update FTD_Cust_txns A,(select payment_mode_name,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_type=B.payment_mode_name
	where A.invoice_id=B.invoice_debit_note_id;

	 alter table SVOC_First_enquiry
	add column Favourite_payment_type varchar(20);

	 
	 UPDATE IGNORE
			SVOC_First_enquiry A
		SET Favourite_payment_type=(
			SELECT 
						payment_type 
					FROM (select eos_user_id,payment_type ,count(*) as ratings,sum(price_after_tax) as sum from FTD_Cust_txns group by eos_user_id,payment_type  order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
	
	update SVOC_First_enquiry A,(select eos_user_id,payment_type,min(created_date) as transact_date from FTD_Cust_txns group by eos_user_id) B
	set A.First_payment_type=B.payment_type
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.transact_date and payment_type is not null;
	
		alter table FTD_Cust_txns
		add index(transact_date_1,currency_code);
		
		update FTD_Cust_txns
		set transact_date_1=case when transact_date ='2017-12-22' then '2017-12-21' else 
		case when transact_date in ('2018-01-26','2018-01-27','2018-01-28','2018-01-29') then '2018-01-25' else
		case when transact_date ='2018-02-02' then '2018-02-01' else transact_date end end end;

	   alter table FTD_Cust_txns
	add column Standardised_Price double;

		alter table FTD_Cust_txns
		add index(transact_date_1);
		
		alter table FTD_Cust_txns
		add column rate_to_USD double;
		
		update FTD_Cust_txns
		set rate_to_USD=1
		where currency_code='USD';

		update FTD_Cust_txns A,(select currency_from,currency_to,avg(exchange_rate) as forex
		from exchange_rate
		where currency_to='USD' 
		and exchange_rate>0 and exchange_rate is not null
		group by currency_from,currency_to) B
		set rate_to_USD= forex
		where A.currency_code=B.currency_from and currency_code is not null;


		update FTD_Cust_txns
		set Standardised_Price=rate_to_USD*price_after_tax;

		set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,Standardised_Price,min(created_date) as transact_date from FTD_Cust_txns group by eos_user_id) B
	set A.First_price_after_tax=B.Standardised_Price
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.transact_date and Standardised_Price is not null;

	ALTER TABLE SVOC_First_enquiry add column First_txn_discount varchar(2);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date,discount from FTD_Cust_txns where discount >0 and discount is not null) B
	set A.First_txn_discount='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;	

	ALTER TABLE SVOC_First_enquiry add column First_txn_Coupon_used varchar(2);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date, offer_code from FTD_Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;


	ALTER TABLE SVOC_First_enquiry add column First_job_word_count varchar(20);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date, unit_count from FTD_Cust_txns) B
	set A.First_job_word_count =B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_client_instruction_present='Y' 
	where A.FTD_created_date=B.created_date and client_instruction is not null and client_instruction not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_delivery_instruction_present='Y' 
	where A.FTD_created_date=B.created_date and delivery_instruction is not null and delivery_instruction not like '%test%';



	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_title_present='Y' 
	where A.FTD_created_date=B.created_date and title is not null and title not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_journal_name_present='Y' 
	where A.FTD_created_date=B.created_date and journal_name is not null and journal_name not like '%test%';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_use_ediatge_card=null'Y' 
	where A.FTD_created_date=B.created_date and use_ediatge_card='Yes' and editage_card_id is not null and use_ediatge_card not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_author_name_present='Y' 
	where A.FTD_created_date=B.created_date and author_name is not null and author_name not like '%test%';

	alter table FTD_Cust_txns add column No_service_components int(5);

	alter table FTD_Cust_txns add index(service_id);
	alter table process_service_mapping add index(service_id);

	update FTD_Cust_txns A,(select service_id,count(distinct id) as component from process_service_mapping group by service_id) B
	set A.No_service_components=B.component
	where A.service_id=B.service_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_service_components=B.No_service_components
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	/* Computing One year from the FTD (first enquiry date) for each customer */
	
	ALTER TABLE SVOC_First_enquiry
	add column one_yr_from_FTD_date date,
	add column one_yr_Frq_from_FTD_date int,add column one_yr_Sales_from_FTD_date int; /* Computing One year frequency from the FTD  */

	update SVOC_First_enquiry
	set one_yr_from_FTD_date = DATE_ADD(FTD, INTERVAL 1 Year); 
	
	update SVOC_First_enquiry A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq,sum(Standardised_Price) as sum1 from FTD_Cust_txns A, SVOC_First_enquiry B
	where left(confirmed_date,10) between FTD and one_yr_from_FTD_date and A.eos_user_id=B.eos_user_id 
	and status='send-to-client'
	group by A.eos_user_id) C
	set A.one_yr_Frq_from_FTD_date=C.freq,A.one_yr_Sales_from_FTD_date=C.sum1
	where A.eos_user_id=C.eos_user_id;

	/* 
	
	It is important to determine whether the first transaction of the customer is valid order (converted to job or not)
	
	*/

	alter table SVOC_First_enquiry
	add column is_order varchar(2) default 'N';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.is_order='Y'
	where A.FTD_created_date=B.created_date and B.status='send-to-client';

	alter table SVOC_First_enquiry
	add column one_yr_MVC_from_FTD_date varchar(2);

	update SVOC_First_enquiry
	set one_yr_MVC_from_FTD_date=
	case when one_yr_Frq_from_FTD_date >= 2 and is_order='Y'   then '1' 
	when one_yr_Frq_from_FTD_date >= 3 and is_order='N' then '1' else '0' end; 

	alter table SVOC_First_enquiry
	add column one_yr_MVC_from_FTD_date_N varchar(2);

	update SVOC_First_enquiry
	set one_yr_MVC_from_FTD_date_N=
	case when one_yr_Frq_from_FTD_date >= 2 and is_order='Y' and  one_yr_Sales_from_FTD_date>=420.74 then '1' 
	when one_yr_Frq_from_FTD_date >= 3 and is_order='N' and one_yr_Sales_from_FTD_date>=420.74  then '1' else '0' end; 
	
	alter table FTD_Cust_txns
	add  column Is_in_top_sub_Area  varchar(2);

	/* Subject area among the top MVC decile or not */
	UPDATE FTD_Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	
	alter table FTD_Cust_txns
	add  column Is_in_top_sub_Area_N  varchar(2);

	/* Subject area among the top MVC decile or not */
	UPDATE FTD_Cust_txns
	SET Is_in_top_sub_Area_N = 'Y'
	WHERE subject_area_id IN
	(130,153,159,170,382,499,503,512,518,545,555,597,610,612,619,643,646,653,656,677,685,687,713,718,735,754,788,822,823,833,846,863,868,884,898,906,927,930,935,944,977,990,1023,1122,1127,1166,1175,1205,1220,1252,1253,1273,1321,1340,1378,1420,1424,1451,1456,1460,1462,1463,2068,2121,433,445,854,1448,1481,1577,129,268,1139,1479,802,43,98,559,616,674,705,720,787,812,828,902,1045,1050,1057,1193,1203,1480,2082,2113,1575,1028,32,1113,1517,1185,31,226,373,471,684,739,1162,1406,2120,1312,1146,13,275,600,1453,598,244,410,2090,537,1261,1361,117,240,1054,1352,573,48,439,1059,366,1572,2118,390,94,381,607,88,106,214,245,309,317,329,418,448,451,461,463,508,525,535,543,546,558,562,564,567,590,594,596,604,609,630,635,639,668,673,679,681,686,689,692,697,702,707,709,722,755,770,792,795,808,826,847,857,879,889,929,931,934,949,967,1005,1036,1058,1067,1068,1077,1106,1144,1178,1214,1219,1226,1234,1320,1335,1349,1377,1379,1389,1418,1421,1449,1457,1461,1491,2069,2073,2084,2117);
	
	alter table SVOC_First_enquiry
	add column First_Is_in_top_sub_Area varchar(2),
	add column First_Is_in_top_sub_Area_N varchar(2);

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_Is_in_top_sub_Area='Y'
	where A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id and Is_in_top_sub_Area= 'Y';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_Is_in_top_sub_Area_N='Y'
	where A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id and Is_in_top_sub_Area_N= 'Y';

	alter table FTD_Cust_txns
	add column Premium varchar(5);

	update FTD_Cust_txns  A, service B
	set A.Premium =B.Premium 
	where A.service_id=B.id;


	#####################     REVISION

	select enquiry_id,created_date
	from component;

	select nid,max(FROM_UNIXTIME(created_date))
	from node group by nid;


	alter table enquiry
	add column FTD_rev_date date;

	update enquiry A,
	(select A.nid,enquiry_id,Left(FROM_UNIXTIME(created),10) as date
	from node A,content_type_enquiry B
	where A.nid=B.nid) B
	set A.FTD_rev_date=B.date
	where A.id=B.enquiry_id;



		alter table FTD_Cust_txns add column Revision_in_subject_area varchar(2);
		alter table FTD_Cust_txns add column Revision_in_price_after_tax varchar(2);
		alter table FTD_Cust_txns add column Revision_in_service_id varchar(2);
		alter table FTD_Cust_txns add column Revision_in_delivery_date varchar(2);
		alter table FTD_Cust_txns add column Revision_in_words varchar(2);

		alter table FTD_Cust_txns add index(enquiry_id);
		
		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		
	alter table FTD_Cust_txns 
	add column FTD_rev_date date;

	update FTD_Cust_txns A,enquiry B
	set A.FTD_rev_date=B.FTD_rev_date
	where
	A.enquiry_id=B.id;

	Alter Table SVOC
	ADD Column First_txn_Rev_in_subject_area_EN varchar(2),
	ADD Column First_txn_Rev_in_price_after_tax_EN varchar(2),
	ADD Column First_txn_Rev_in_service_id_EN varchar(2),
	ADD Column First_txn_Rev_in_delivery_date_EN varchar(2),
	ADD Column First_txn_Rev_in_words_EN varchar(2);


	UPDATE SVOC_First_enquiry A, (SELECT eos_user_id, transact_date,FTD_rev_date,Revision_in_subject_area, Revision_in_price_after_tax, Revision_in_service_id, Revision_in_delivery_date, Revision_in_words FROM FTD_Cust_txns) B
	set A.First_txn_Rev_in_subject_area_EN = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_price_after_tax_EN = CASE WHEN  B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_service_id_EN = CASE WHEN  B.Revision_in_service_id = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_delivery_date_EN = CASE WHEN   B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_words_EN = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A.eos_user_id = B.eos_user_id andA.FTD_created_date=B.created_date and A.FTD=B.FTD_rev_date;

	/*
	
	select eos_user_id,First_txn_Rev_in_subject_area_EN from SVOC_First_enquiry where First_txn_Rev_in_subject_area_EN='Y';
	select enquiry_id,eos_user_id,transact_date,FTD_rev_date,Revision_in_subject_area from FTD_Cust_txns where eos_user_id =309;
	select * from content_type_enquiry where enquiry_id=324353;
	select nid,vid,Left(FROM_UNIXTIME(created),10) as date from node where nid=4606153;
	
	*/
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_quotation_given = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD_created_date=B.created_date;
	
		/* Indicator variable whether quotation was sought by the customer */

	 alter table FTD_Cust_txns add column Quotation_given varchar(2);
	 
	 update FTD_Cust_txns A,
	 (
	 select * from enquiry where source_url like 'ecf.online.editage.%'
	 or source_url like 'php_form/newncf' or source_url like 'ecf.app.editage.%'
	 or source_url like	 'ncf.editage.%'
	 or source_url like 'api.editage.%/existing'
	 or source_url like 'api.editage.com/newecf-skipwc'
	 ) B
	 set A.Quotation_given='Y'
	 where A.enquiry_id=B.id;
	 
	ALTER table FTD_Cust_txns 
	add column Word_count_given varchar(2) default 'N';
	
	update FTD_Cust_txns
	set Word_count_sought ='Y'
	where (source_url like 'api%' and source_url not like '%skipwc%') 
	and
	service_id in (1,2,36,49,102);
	
	alter table SVOC_First_enquiry add column First_enquiry_word_sought varchar(2) default 'N';
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_enquiry_word_sought = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Word_count_sought='Y' and A.FTD_created_date=B.created_date;
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_quotation_given = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD_created_date=B.created_date;
	
	/*  adding wb_user */

	update FTD_Cust_txns A,component_auction B
	set A.wb_user_id=B.wb_user_allocated_id
	where A.enquiry_id=B.enquiry_id;
		
	#########################                      SALUTATION
	

	CREATE TEMPORARY TABLE eos_USER AS 
	SELECT * FROM CACTUS.EOS_USER;

	alter table eos_USER
	add column salutation_code varchar(5);
		
	set sql_safe_updates=0;
	update eos_USER
	set salutation_code = JSON_UNQUOTE(JSON_EXTRACT(user_profile, '$.field_client_profile_salutation'));
		
	CREATE TEMPORARY TABLE masters1 AS 
	SELECT * FROM CACTUS.masters;

	alter table masters1
	add column salutation varchar(5);
		
	set sql_safe_updates=0;
	update masters1
	set salutation = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_salutation_name'));
		
	alter table eos_USER
	add column salutation varchar(20);
		
	alter table eos_USER add index(salutation_code);
	alter table masters1 add index(id);
		
	update eos_USER A,masters1 B
	set A.salutation=B.salutation
	where A.salutation_code=B.id;
		
	alter table SVOC_First_enquiry
	add column salutation varchar(10);
		
	update SVOC_First_enquiry A,eos_USER B
	set A.salutation=B.salutation
	where A.eos_user_id=B.id;
			
	alter table SVOC_First_enquiry 
	add column First_service_segment int(5);

	update SVOC_First_enquiry A,service B
	set A.First_service_segment=B.service_segment
	where A.First_service_id=B.id;
		
	alter table SVOC_First_enquiry add column partner_id varchar(20);    

	update SVOC_First_enquiry A,EOS_USER B
	set A.partner_id=B.partner_id where A.eos_user_id=B.id;
		
	alter table SVOC_First_enquiry add column partner_name varchar(20);    

	update SVOC_First_enquiry A,partner B
	set partner_name=B.name where A.partner_id=B.id;
	
	###############   new vars 
	
	alter table FTD_Cust_txns
	add column Is_service_Standard_Editing varchar(2) default 'N',
	add column Is_service_Premium_Editing varchar(2) default 'N',
	add column Is_service_Premium_Editing_Plus varchar(2) default 'N',
	add column Is_service_Standard_Translation varchar(2) default 'N',
	add column Is_service_Korean_to_English_Translation varchar(2) default 'N',
	add column Is_service_Korean_to_English_Translation_Level_2 varchar(2) default 'N'
	;

	update FTD_Cust_txns
	set Is_service_Standard_Editing='Y'
	where service_id=36;


	update FTD_Cust_txns
	set Is_service_Premium_Editing='Y'
	where service_id=1;

	update FTD_Cust_txns
	set Is_service_Premium_Editing_Plus='Y'
	where service_id=49;

	update FTD_Cust_txns
	set Is_service_Standard_Translation='Y'
	where service_id=35;

	update FTD_Cust_txns
	set Is_service_Korean_to_English_Translation='Y'
	where service_id=55;

	update FTD_Cust_txns
	set Is_service_Korean_to_English_Translation_Level_2='Y'
	where service_id=10;


	alter table SVOC_First_enquiry 
	add column Is_First_service_Standard_Editing varchar(2) default 'N',
	add column Is_First_service_Premium_Editing varchar(2) default 'N',
	add column Is_First_service_Premium_Editing_Plus varchar(2) default 'N',
	add column Is_First_service_Standard_Translation varchar(2) default 'N',
	add column Is_First_service_Korean_to_English_Translation varchar(2) default 'N',
	add column Is_First_service_Korean_to_English_Translation_Level_2 varchar(2) default 'N'
	;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Standard_Editing='Y'
	where B.Is_service_Standard_Editing='Y' and A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Premium_Editing='Y'
	where B.Is_service_Premium_Editing='Y' and A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Premium_Editing_Plus='Y'
	where B.Is_service_Premium_Editing_Plus='Y' and A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Standard_Translation='Y'
	where B.Is_service_Standard_Translation='Y' and A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Korean_to_English_Translation='Y'
	where B.Is_service_Korean_to_English_Translation='Y' and A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.Is_First_service_Korean_to_English_Translation_Level_2='Y'
	where B.Is_service_Korean_to_English_Translation_Level_2='Y' and A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id;

	alter table FTD_Cust_txns
	add column Is_service_quotation_sought varchar(2);
	
	update FTD_Cust_txns
	set Is_service_quotation_sought= 'Y'
	where service_id in (1,2,36,49,102);
	
	/* Is_quotation_sought service  */
	
	alter table SVOC_First_enquiry
	add column First_service_is_quotation_sought varchar(2);
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_service_is_quotation_sought='Y'
	where B.Is_service_quotation_sought= 'Y' and A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;
	
	alter table FTD_Cust_txns
	add column service_segment int;

	update FTD_Cust_txns A,service B
	set A.service_segment=B.service_segment
	where A.service_id=B.id;

	select service_id,service_segment from FTD_Cust_txns limit 10;

	alter table FTD_Cust_txns
	add column Txn_type varchar(20);

	update FTD_Cust_txns
	set Txn_type = 
	case when service_segment=3 then 'Editing' else
	case when service_segment=6 then 'Translation' else 
	'others' end end;

	alter table SVOC_First_enquiry
	add column First_Txn_type varchar(20);

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_Txn_type=B.Txn_type
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;
	
	####   Quotation loop variable used   ######
	
	alter table FTD_Cust_txns
	add column English_input_loop varchar(30),
	add column source_url longtext;
	
	update FTD_Cust_txns A,enquiry B
	set A.source_url=B.source_url
	where A.enquiry_id=B.id;
	
	update FTD_Cust_txns
	set English_input_loop=
	case 
	when 
	service_id in (1,2,36,49,102) and 
	(source_url like 'ecf.online.editage.%'
	 or source_url like 'php_form/newncf' or source_url like 'ecf.app.editage.%'
	 or source_url like 'ncf.editage.%'
	 or source_url like 'api.editage.%/existing'
	 or source_url like 'api.editage.com/newecf-skipwc'
	 or source_url like 'http://whiteboard.cactusglobal.com/node/add/enquiry#new-crm'
	 or source_url like '%Whiteboard: cloned inquiry INQ%'
	 )
	 then 'English_input_Q' else
	 case when 
	 service_id in (1,2,36,49,102) and 
	 (source_url like 'api.editage.com/newecf'
	 or source_url like 'api.editage.com/newncf' or source_url like 'ecf.app.editage.%'
	 or source_url like 'php_form/newncf-wc') then 'English_input_WC'
	 else
	 'Non_English_input' end end;
	
	/* Creating word count segregation for english language translation */
	
	alter table SVOC_First_enquiry add column First_English_input_loop varchar(30);
	
	update SVOC_First_enquiry A,FTD_Cust_txns B set A.First_English_input_loop=B.English_input_loop where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;
	
	alter table SVOC_First_enquiry 
	add column First_source_url_skip_wc varchar(2) default 'N';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_source_url_skip_wc = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD_created_date=B.created_date;

	
	alter table SVOC
	add column First_created_date varchar(10);

	update SVOC A,(select eos_user_id,min(created_date) as created_date
	from enquiry
	group by eos_user_id) B
	set A.First_created_date=left(B.created_date,10)
	where A.eos_user_id=B.eos_user_id;

	
	
	create table SVOC_First_enquiry as 
	select eos_user_id,min(left(created_date,10)) as FTD
	from FTD_Cust_txns
	group by eos_user_id;
	
	alter table SVOC_First_enquiry add column FTD_created_date datetime;
	
	update SVOC_First_enquiry A,(select eos_user_id,min(created_date) as FTD_created_date from FTD_Cust_txns group by eos_user_id) B 
	set A.FTD_created_date=B.FTD_created_date where A.eos_user_id=B.eos_user_id;
	
	alter table FTD_Cust_txns
	add column transact_date_1 date,
	add column  transact_date varchar(10);
		
		set sql_safe_updates=0;
		update FTD_Cust_txns
		set transact_date=Left(created_date,10);
		

	alter table SVOC_First_enquiry
	add column First_unit_count int(10),
	add column First_subject_area_id int(10),
	add column First_service_id int(10),
	add column First_client_instruction_present varchar(2),
	add column First_delivery_instruction_present varchar(2),
	add column First_title_present varchar(2),
	add column First_journal_name_present varchar(2),
	add column First_use_ediatge_card varchar(2),
	add column First_editage_card_id int(10),
	add column First_author_name_present varchar(2),
	add column First_payment_type varchar(20),
	add column First_subject_area int(10),
	add column First_price_after_tax int(10),
	add column First_txn_discount varchar(2),
	add column First_txn_Coupon_used varchar(2),
	add column First_job_word_count int(10),
	add column First_NoOfQues int(10),
	add column First_service_components varchar(2);
	
	ALTER TABLE SVOC_First_enquiry 
	add column First_txn_Coupon_used varchar(2);
	
	ALTER TABLE SVOC_First_enquiry
	add column transacted_or_not varchar(2) default 'N';

	UPDATE SVOC_First_enquiry A, FTD_Cust_txns B
	set A.transacted_or_not = 'Y'
	where A.eos_user_id = B.eos_user_id AND A.FTD_created_date=B.created_date AND status = 'send-to-client';
	
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date, offer_code from FTD_Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	alter table SVOC_First_enquiry add index(FTD);	
	alter table FTD_Cust_txns add index(created_date);
	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_unit_count=B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_subject_area_id=B.subject_area_id
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_service_id=B.service_id
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;


	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_client_instruction_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.client_instruction not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_delivery_instruction_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.delivery_instruction not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_title_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.title not like ('%test%');


	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_journal_name_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.journal_name not like ('%test%');

	update SVOC_First_enquiry A,FTD_Cust_txns  B
	set A.First_journal_name_present='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date and B.journal_name not like ('%test%');

	alter table FTD_Cust_txns add column invoice_id int(9);

	update FTD_Cust_txns A,Orders B
	set A.invoice_id=B.invoice_id
	where A.enquiry_id=B.enquiry_id and B.invoice_id is not null;

	create temporary table as migration
	select * from master;

	set sql_safe_updates=0;
	update migration
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode'));

	create temporary table mig as 
	select * from masters;

	alter table mig add column payment_mode varchar(20);

	set sql_safe_updates=0;
	update mig
	set payment_mode = JSON_UNQUOTE(JSON_EXTRACT(data, '$.field_paymentmode'))
	where config_id=48;
	
	###################################################################
	
	alter table FTD_Cust_txns 
	add column payment_type varchar(20);

	alter table FTD_Cust_txns
	add column payment_mode_id varchar(6);

	update FTD_Cust_txns A,(select payment_mode_id,invoice_debit_note_id from payment A,payment_invoice_association B where A.id=B.payment_credit_note_id) B
	set A.payment_mode_id=B.payment_mode_id
	where A.invoice_id=B.invoice_debit_note_id;

	alter table FTD_Cust_txns add index(payment_mode_id);
	alter table mig add index(id);

	update FTD_Cust_txns A, mig B
	set A.payment_type=B.payment_mode	
	where A.payment_mode_id=B.id and B.config_id=48;

	 alter table SVOC_First_enquiry
	add column Favourite_payment_type varchar(20);
	 
	 UPDATE IGNORE
			SVOC_First_enquiry A
		SET Favourite_payment_type=(
			SELECT 
						payment_type 
					FROM (select eos_user_id,payment_type ,count(*) as ratings,sum(price_after_tax) as sum from FTD_Cust_txns group by eos_user_id,payment_type  order by ratings desc,sum desc) B
					WHERE
						A.eos_user_id = B.eos_user_id
					ORDER BY ratings desc,sum desc
					LIMIT 1);
	
	update SVOC_First_enquiry A,(select eos_user_id,payment_type,min(created_date) as transact_date from FTD_Cust_txns group by eos_user_id) B
	set A.First_payment_type=B.payment_type
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.transact_date and payment_type is not null;
	
		alter table FTD_Cust_txns
		add index(transact_date_1,currency_code);
		
		update FTD_Cust_txns
		set transact_date_1=case when transact_date ='2017-12-22' then '2017-12-21' else 
		case when transact_date in ('2018-01-26','2018-01-27','2018-01-28','2018-01-29') then '2018-01-25' else
		case when transact_date ='2018-02-02' then '2018-02-01' else transact_date end end end;

	   alter table FTD_Cust_txns
	add column Standardised_Price double;

		alter table FTD_Cust_txns
		add index(transact_date_1);
		
		alter table FTD_Cust_txns
		add column rate_to_USD double;
		
		update FTD_Cust_txns
		set rate_to_USD=1
		where currency_code='USD';

		update FTD_Cust_txns A,(select currency_from,currency_to,avg(exchange_rate) as forex
		from exchange_rate
		where currency_to='USD' 
		and exchange_rate>0 and exchange_rate is not null
		group by currency_from,currency_to) B
		set rate_to_USD= forex
		where A.currency_code=B.currency_from and currency_code is not null;


		update FTD_Cust_txns
		set Standardised_Price=rate_to_USD*price_after_tax;

		set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,Standardised_Price,min(created_date) as transact_date from FTD_Cust_txns group by eos_user_id) B
	set A.First_price_after_tax=B.Standardised_Price
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.transact_date and Standardised_Price is not null;

	ALTER TABLE SVOC_First_enquiry add column First_txn_discount varchar(2);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date,discount from FTD_Cust_txns where discount >0 and discount is not null) B
	set A.First_txn_discount='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;	

	ALTER TABLE SVOC_First_enquiry add column First_txn_Coupon_used varchar(2);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date, offer_code from FTD_Cust_txns where offer_code is not null) B
	set A.First_txn_Coupon_used ='Y'
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;


	ALTER TABLE SVOC_First_enquiry add column First_job_word_count varchar(20);
	set sql_safe_updates=0;
	update SVOC_First_enquiry A,(select eos_user_id,created_date, unit_count from FTD_Cust_txns) B
	set A.First_job_word_count =B.unit_count
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_client_instruction_present='Y' 
	where A.FTD_created_date=B.created_date and client_instruction is not null and client_instruction not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_delivery_instruction_present='Y' 
	where A.FTD_created_date=B.created_date and delivery_instruction is not null and delivery_instruction not like '%test%';



	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_title_present='Y' 
	where A.FTD_created_date=B.created_date and title is not null and title not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_journal_name_present='Y' 
	where A.FTD_created_date=B.created_date and journal_name is not null and journal_name not like '%test%';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_use_ediatge_card='Y' 
	where A.FTD_created_date=B.created_date and use_ediatge_card='Yes' and editage_card_id is not null and use_ediatge_card not like '%test%';


	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_author_name_present='Y' 
	where A.FTD_created_date=B.created_date and author_name is not null and author_name not like '%test%';

	alter table FTD_Cust_txns add column No_service_components int(5);

	alter table FTD_Cust_txns add index(service_id);
	alter table process_service_mapping add index(service_id);

	update FTD_Cust_txns A,(select service_id,count(distinct id) as component from process_service_mapping group by service_id) B
	set A.No_service_components=B.component
	where A.service_id=B.service_id;

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_service_components=B.No_service_components
	where A.eos_user_id=B.eos_user_id and A.FTD_created_date=B.created_date;

	/* Computing One year from the FTD (first enquiry date) for each customer */
	
	ALTER TABLE SVOC_First_enquiry
	add column one_yr_from_FTD_date date,
	add column one_yr_Frq_from_FTD_date int,add column one_yr_Sales_from_FTD_date int; /* Computing One year frequency from the FTD  */

	update SVOC_First_enquiry
	set one_yr_from_FTD_date = DATE_ADD(FTD, INTERVAL 1 Year); 
	
	update SVOC_First_enquiry A,
	(select A.eos_user_id,count(distinct enquiry_id) as freq,sum(Standardised_Price) as sum1 from FTD_Cust_txns A, SVOC_First_enquiry B
	where left(confirmed_date,10) between FTD and one_yr_from_FTD_date and A.eos_user_id=B.eos_user_id 
	and status='send-to-client'
	group by A.eos_user_id) C
	set A.one_yr_Frq_from_FTD_date=C.freq,A.one_yr_Sales_from_FTD_date=C.sum1
	where A.eos_user_id=C.eos_user_id;

	/* 
	
	It is important to determine whether the first transaction of the customer is valid order (converted to job or not)
	
	*/
	
	alter table FTD_Cust_txns
	add column is_order varchar(2) default 'N';

	alter table FTD_Cust_txns
	drop column is_order;

	alter table SVOC_First_enquiry
	add column is_order varchar(2) default 'N';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.is_order='Y'
	where A.FTD_created_date=B.created_date and B.status='send-to-client';

	alter table SVOC_First_enquiry
	add column one_yr_MVC_from_FTD_date varchar(2);

	update SVOC_First_enquiry
	set one_yr_MVC_from_FTD_date=
	case when one_yr_Frq_from_FTD_date >= 2 and is_order='Y'   then '1' 
	when one_yr_Frq_from_FTD_date >= 3 and is_order='N' then '1' else '0' end; 

	alter table SVOC_First_enquiry
	add column one_yr_MVC_from_FTD_date_N varchar(2);

	update SVOC_First_enquiry
	set one_yr_MVC_from_FTD_date_N=
	case when one_yr_Frq_from_FTD_date >= 2 and is_order='Y' and  one_yr_Sales_from_FTD_date>=420.74 then '1' 
	when one_yr_Frq_from_FTD_date >= 3 and is_order='N' and one_yr_Sales_from_FTD_date>=420.74  then '1' else '0' end; 
	
	alter table FTD_Cust_txns
	add  column Is_in_top_sub_Area  varchar(2);

	/* Subject area among the top MVC decile or not */
	UPDATE FTD_Cust_txns
	SET Is_in_top_sub_Area = 'Y'
	WHERE subject_area_id IN
	(591,	1088,	524,	742,	921,	1072,	1075,	1388,	168,	207,	500,	528,	554,	560,	597,	616,	710,	812,	827,	840,	861,	863,	898,	914,	935,	936,	979,	1016,	1018,	1053,	1078,	1127,	1155,	1173,	1183,	1219,	1223,	1240,	1274,	1326,	1391,	1394,	1422,	1456,	1496,	2062,	858,	962,	1265,	161,	1190,	196,	689,	705,	799,	922,	934,	1021,	1259,	1387,	1414,	1446,	1460,	604,	804,	1095,	1296,	630,	247,	214,	942,	1564,	888,	1325,	290,	1405,	1157,	1312,	797,	1567,	598,	1070,	628,	824,	205,	573,	41,	600,	932,	1220,	474,	481,	502,	523,	590,	612,	624,	632,	682,	709,	819,	826,	866,	868,	881,	893,	967,	1017,	1038,	1152,	1199,	1225,	1241,	1243,	1340,	1351,	1354,	1364,	1462,	1467,	1573,	303,	1092,	1282);

	
	alter table FTD_Cust_txns
	add  column Is_in_top_sub_Area_N  varchar(2);

	/* Subject area among the top MVC decile or not */
	UPDATE FTD_Cust_txns
	SET Is_in_top_sub_Area_N = 'Y'
	WHERE subject_area_id IN
	(130,153,159,170,382,499,503,512,518,545,555,597,610,612,619,643,646,653,656,677,685,687,713,718,735,754,788,822,823,833,846,863,868,884,898,906,927,930,935,944,977,990,1023,1122,1127,1166,1175,1205,1220,1252,1253,1273,1321,1340,1378,1420,1424,1451,1456,1460,1462,1463,2068,2121,433,445,854,1448,1481,1577,129,268,1139,1479,802,43,98,559,616,674,705,720,787,812,828,902,1045,1050,1057,1193,1203,1480,2082,2113,1575,1028,32,1113,1517,1185,31,226,373,471,684,739,1162,1406,2120,1312,1146,13,275,600,1453,598,244,410,2090,537,1261,1361,117,240,1054,1352,573,48,439,1059,366,1572,2118,390,94,381,607,88,106,214,245,309,317,329,418,448,451,461,463,508,525,535,543,546,558,562,564,567,590,594,596,604,609,630,635,639,668,673,679,681,686,689,692,697,702,707,709,722,755,770,792,795,808,826,847,857,879,889,929,931,934,949,967,1005,1036,1058,1067,1068,1077,1106,1144,1178,1214,1219,1226,1234,1320,1335,1349,1377,1379,1389,1418,1421,1449,1457,1461,1491,2069,2073,2084,2117);
	
	alter table SVOC_First_enquiry
	add column First_Is_in_top_sub_Area varchar(2),
	add column First_Is_in_top_sub_Area_N varchar(2);

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_Is_in_top_sub_Area='Y'
	where A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id and Is_in_top_sub_Area= 'Y';

	update SVOC_First_enquiry A,FTD_Cust_txns B
	set First_Is_in_top_sub_Area_N='Y'
	where A.FTD_created_date=B.created_date and A.eos_user_id=B.eos_user_id and Is_in_top_sub_Area_N= 'Y';

	alter table FTD_Cust_txns
	add column Premium varchar(5);

	update FTD_Cust_txns  A, service B
	set A.Premium =B.Premium 
	where A.service_id=B.id;


	#####################     REVISION

	select enquiry_id,created_date
	from component;

	select nid,max(FROM_UNIXTIME(created_date))
	from node group by nid;


	alter table enquiry
	add column FTD_rev_date date;

	update enquiry A,
	(select A.nid,enquiry_id,Left(FROM_UNIXTIME(created),10) as date
	from node A,content_type_enquiry B
	where A.nid=B.nid) B
	set A.FTD_rev_date=B.date
	where A.id=B.enquiry_id;



		alter table FTD_Cust_txns add column Revision_in_subject_area varchar(2);
		alter table FTD_Cust_txns add column Revision_in_price_after_tax varchar(2);
		alter table FTD_Cust_txns add column Revision_in_service_id varchar(2);
		alter table FTD_Cust_txns add column Revision_in_delivery_date varchar(2);
		alter table FTD_Cust_txns add column Revision_in_words varchar(2);

		alter table FTD_Cust_txns add index(enquiry_id);
		
		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_subject_area = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_price_after_tax = CASE WHEN B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_service_id = CASE WHEN B.Revision_in_service_id = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_delivery_date = CASE WHEN B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		UPDATE FTD_Cust_txns A, enquiry B
		set A.Revision_in_words = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
		WHERE A.enquiry_id = B.id;

		
	alter table FTD_Cust_txns 
	add column FTD_rev_date date;

	update FTD_Cust_txns A,enquiry B
	set A.FTD_rev_date=B.FTD_rev_date
	where
	A.enquiry_id=B.id;

	Alter Table SVOC_First_enquiry
	ADD Column First_txn_Rev_in_subject_area_EN varchar(2),
	ADD Column First_txn_Rev_in_price_after_tax_EN varchar(2),
	ADD Column First_txn_Rev_in_service_id_EN varchar(2),
	ADD Column First_txn_Rev_in_delivery_date_EN varchar(2),
	ADD Column First_txn_Rev_in_words_EN varchar(2);


	UPDATE SVOC_First_enquiry A, (SELECT eos_user_id, created_date,transact_date,FTD_rev_date,Revision_in_subject_area, Revision_in_price_after_tax, Revision_in_service_id, Revision_in_delivery_date, Revision_in_words FROM FTD_Cust_txns) B
	set A.First_txn_Rev_in_subject_area_EN = CASE WHEN B.Revision_in_subject_area = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_price_after_tax_EN = CASE WHEN  B.Revision_in_price_after_tax = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_service_id_EN = CASE WHEN  B.Revision_in_service_id = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_delivery_date_EN = CASE WHEN   B.Revision_in_delivery_date = 'Y' then 'Y' else 'N' END,
	A.First_txn_Rev_in_words_EN = CASE WHEN B.Revision_in_words = 'Y' then 'Y' else 'N' END
	WHERE A.eos_user_id = B.eos_user_id and A.FTD_created_date=B.created_date and A.FTD=B.FTD_rev_date;

		ALTER table FTD_Cust_txns 
	add column First_quotation_given varchar(2) default 'N';
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_quotation_given = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD_created_date=B.created_date;
	
		/* Indicator variable whether quotation was sought by the customer */

	 alter table FTD_Cust_txns add column Quotation_given varchar(2);
	 
	 update FTD_Cust_txns A,
	 (
	 select * from enquiry where source_url like 'ecf.online.editage.%'
	 or source_url like 'php_form/newncf' or source_url like 'ecf.app.editage.%'
	 or source_url like	 'ncf.editage.%'
	 or source_url like 'api.editage.%/existing'
	 or source_url like 'api.editage.com/newecf-skipwc'
	 ) B
	 set A.Quotation_given='Y'
	 where A.enquiry_id=B.id;
	 
	ALTER table FTD_Cust_txns 
	add column Word_count_given varchar(2) default 'N';
	
	update FTD_Cust_txns
	set Word_count_sought ='Y'
	where (source_url like 'api%' and source_url not like '%skipwc%') 
	and
	service_id in (1,2,36,49,102);
	
	alter table SVOC_First_enquiry add column First_enquiry_word_sought varchar(2) default 'N';
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_enquiry_word_sought = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Word_count_sought='Y' and A.FTD_created_date=B.created_date;
	
	update SVOC_First_enquiry A,FTD_Cust_txns B
	set A.First_quotation_given = 'Y'
	where A.eos_user_id=B.eos_user_id and B.Quotation_given='Y' and A.FTD_created_date=B.created_date;
	
