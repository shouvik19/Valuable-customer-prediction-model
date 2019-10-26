

###############         importing data from the text file in R      ###################

Data<- read.csv("train_test.txt", sep = "|", header = TRUE, na.strings ="\\N",quote = "")

#########    viewing columns and rows for our given dataset    #########

dim(Data)
# 39760

table(is.na(Data$Updated_MVC_16_17))
summary(is.na(OutData$Updated_MVC_17_18))

#########################      Installing randomForest in R               #########################

#install.packages("randomForest")
library(randomForest)

########     setting seed for reproducible results         ##################


set.seed(102)

#######   setting our target variable (it belongs to Apr 16- Mar 17 cycle, whereas our independent variables belong to the Apr 15 - Mar 16 cycle)

Data$Updated_MVC_16_17<-as.character(Data$Updated_MVC_16_17)

######  cleaning up data for the target variable  ######

Data$Updated_MVC_16_17[is.na(Data$Updated_MVC_16_17)]<-"N"
Data$Updated_MVC_16_17<-as.factor(Data$Updated_MVC_16_17)
Data$target<-ifelse(Data$Updated_MVC_16_17=='Y',1,0)
Data$target <- as.factor(Data$target)
table(Data$target)

###########       CORRELATION        ###############
corr_data<-dplyr::select_if(Data, is.numeric | stringr::str_detect(names(Data), "2015_2016"))

names(Data)
correlation<-cor(corr_data)
write.csv(correlation,"corr.csv")


#####  Varaibles Cleaning ####

Data$ATV_2015_2016_N[is.na(Data$ATV_2015_2016_N)] <- 0
Data$frequency_2015_2016_N[is.na(Data$frequency_2015_2016_N)] <- 0
Data$Recency_2015_2016_N[is.na(Data$Recency_2015_2016_N)] <- 0
Data$ADGBT_2015_2016_N[is.na(Data$ADGBT_2015_2016_N)] <- 0
Data$Total_Standard_price_2015_2016_N[is.na(Data$Total_Standard_price_2015_2016_N)] <- 0
Data$Number_of_times_rated_2015_2016_N[is.na(Data$Number_of_times_rated_2015_2016_N)] <- 0
Data$Range_of_services_2015_2016_N[is.na(Data$Range_of_services_2015_2016_N)] <- 0
Data$Average_word_count_2015_2016_N[is.na(Data$Average_word_count_2015_2016_N)] <- 0
Data$Average_Delay_2015_2016_N[is.na(Data$Average_Delay_2015_2016_N)] <- 0
Data$Number_of_group[is.na(Data$Number_of_group)] <- 0
Data$enquiry_job_ratio_2015_2016_N[is.na(Data$enquiry_job_ratio_2015_2016_N)] <- 0
Data$No_of_Revision_in_subject_area_2015_2016_N[is.na(Data$No_of_Revision_in_subject_area_2015_2016_N)] <- 0
Data$No_of_Revision_in_price_after_tax_2015_2016_N[is.na(Data$No_of_Revision_in_price_after_tax_2015_2016_N)] <- 0
Data$No_of_Revision_in_service_id_2015_2016_N[is.na(Data$No_of_Revision_in_service_id_2015_2016_N)] <- 0
Data$No_of_Revision_in_delivery_date_2015_2016_N[is.na(Data$No_of_Revision_in_delivery_date_2015_2016_N)] <- 0
Data$No_of_Revision_in_words_2015_2016_N[is.na(Data$No_of_Revision_in_words_2015_2016_N)] <- 0
Data$Vintage_2015_2016_N[is.na(Data$Vintage_2015_2016_N)] <- 0
Data$percent_offer_cases_2015_2016_N[is.na(Data$percent_offer_cases_2015_2016_N)] <- 0
Data$percent_delay_cases_2015_2016_N[is.na(Data$percent_delay_cases_2015_2016_N)] <- 0
Data$Ratio_paid_mre_to_total_orders_2015_2016_N[is.na(Data$Ratio_paid_mre_to_total_orders_2015_2016_N)] <- 0

# Not Included in Model
#Data$Range_of_subjects_2015_2016_N[is.na(Data$Range_of_subjects_2015_2016_N)] <- 0
#Data$percent_discount_cases_2015_2016_N[is.na(Data$percent_discount_cases_2015_2016_N)] <- 0
#Data$distinct_translators_2015_2016_N[is.na(Data$distinct_translators_2015_2016_N)] <- 0
#Data$Ratio_valid_mre_to_total_orders_2015_2016_N[is.na(Data$Ratio_valid_mre_to_total_orders_2015_2016_N)] <- 0
#Data$Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N[is.na(Data$Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N)] <- 0

Data$Is_foreign_Univ <- as.character(Data$Is_foreign_Univ)   
Data$Is_foreign_Univ[is.na(Data$Is_foreign_Univ)] <-"N"  
Data$Is_foreign_Univ <- as.factor(Data$Is_foreign_Univ)

Data$Ever_rated_2015_2016_N <- as.character(Data$Ever_rated_2015_2016_N)   
Data$Ever_rated_2015_2016_N[is.na(Data$Ever_rated_2015_2016_N)] <-"N" 
Data$Ever_rated_2015_2016_N <- as.factor(Data$Ever_rated_2015_2016_N)

Data$Ever_rated_outstanding_2015_2016_N <- as.character(Data$Ever_rated_outstanding_2015_2016_N)  
Data$Ever_rated_outstanding_2015_2016_N[is.na(Data$Ever_rated_outstanding_2015_2016_N)] <-"N"  
Data$Ever_rated_outstanding_2015_2016_N <- as.factor(Data$Ever_rated_outstanding_2015_2016_N)

Data$Ever_rated_not_acceptable_2015_2016_N <- as.character(Data$Ever_rated_not_acceptable_2015_2016_N)   
Data$Ever_rated_not_acceptable_2015_2016_N[is.na(Data$Ever_rated_not_acceptable_2015_2016_N)] <-"N" 
Data$Ever_rated_not_acceptable_2015_2016_N <- as.factor(Data$Ever_rated_not_acceptable_2015_2016_N)

Data$Ever_rated_acceptable_2015_2016_N <- as.character(Data$Ever_rated_acceptable_2015_2016_N)   
Data$Ever_rated_acceptable_2015_2016_N[is.na(Data$Ever_rated_acceptable_2015_2016_N)] <-"N"  
Data$Ever_rated_acceptable_2015_2016_N <- as.factor(Data$Ever_rated_acceptable_2015_2016_N)

Data$is_preferred_transalator_2015_2016_N <- as.character(Data$is_preferred_transalator_2015_2016_N)   
Data$is_preferred_transalator_2015_2016_N[is.na(Data$is_preferred_transalator_2015_2016_N)] <-"N" 
Data$is_preferred_transalator_2015_2016_N <- as.factor(Data$is_preferred_transalator_2015_2016_N)

Data$Is_in_top_sub_Area_2015_2016_N <- as.character(Data$Is_in_top_sub_Area_2015_2016_N) 
Data$Is_in_top_sub_Area_2015_2016_N[is.na(Data$Is_in_top_sub_Area_2015_2016_N)] <-"N"  
Data$Is_in_top_sub_Area_2015_2016_N <- as.factor(Data$Is_in_top_sub_Area_2015_2016_N)

Data$Is_in_top_sub_Area_1_2015_2016_N <- as.character(Data$Is_in_top_sub_Area_1_2015_2016_N)   
Data$Is_in_top_sub_Area_1_2015_2016_N[is.na(Data$Is_in_top_sub_Area_1_2015_2016_N)] <-"N" 
Data$Is_in_top_sub_Area_1_2015_2016_N <- as.factor(Data$Is_in_top_sub_Area_1_2015_2016_N)

Data$maximum_rating_2015_2016_N <- as.character(Data$maximum_rating_2015_2016_N)   
Data$maximum_rating_2015_2016_N[is.na(Data$maximum_rating_2015_2016_N)] <-"N"  
Data$maximum_rating_2015_2016_N <- as.factor(Data$maximum_rating_2015_2016_N)

Data$is_referred <- as.character(Data$is_referred)  
Data$is_referred[is.na(Data$is_referred)] <-"N"  
Data$is_referred <- as.factor(Data$is_referred)

Data$editage_card_user <- as.character(Data$editage_card_user)  
Data$editage_card_user[is.na(Data$editage_card_user)] <-"N"  
Data$editage_card_user <- as.factor(Data$editage_card_user)

Data$is_part_of_group <- as.character(Data$is_part_of_group)   
Data$is_part_of_group[is.na(Data$is_part_of_group)] <-"N" 
Data$is_part_of_group <- as.factor(Data$is_part_of_group)

Data$Number_of_group <- as.character(Data$Number_of_group)  
Data$Number_of_group[is.na(Data$Number_of_group)] <-"N"  
Data$Number_of_group <- as.factor(Data$Number_of_group)

Data$salutation <- as.character(Data$salutation)   
Data$salutation[is.na(Data$salutation)] <-"N" 
Data$salutation <- as.factor(Data$salutation)

Data$New_or_existing_in_2015_2016_N <- as.character(Data$New_or_existing_in_2015_2016_N)  
Data$New_or_existing_in_2015_2016_N[is.na(Data$New_or_existing_in_2015_2016_N)] <-"N"  
Data$New_or_existing_in_2015_2016_N <- as.factor(Data$New_or_existing_in_2015_2016_N)

Data$maximum_rating_2015_2016_N <- as.character(Data$maximum_rating_2015_2016_N) 
Data$maximum_rating_2015_2016_N[is.na(Data$maximum_rating_2015_2016_N)] <-"N"  
Data$maximum_rating_2015_2016_N <- as.factor(Data$maximum_rating_2015_2016_N)

## Removing Some Customers ( outliers )
rm2 <- which(Data$eos_user_id == 187277|
               Data$eos_user_id == 49313|
               Data$eos_user_id == 123648|
               Data$eos_user_id == 197614|
               Data$eos_user_id == 194298|
               Data$eos_user_id == 190230|
               Data$eos_user_id == 43725|
               Data$eos_user_id == 47470|
               Data$eos_user_id == 59080|
               Data$eos_user_id == 122001|
               Data$eos_user_id == 129230)
length(rm2)
tot_rm <- c(rm2)
length(tot_rm)
unq_rm <- unique(tot_rm)
length(unq_rm)

# Final Dataframe to be used for Modeling
Data <- Data[-unq_rm, ]

############## OutofTime Data Import and variables treatment ############

#rm(OutData)  

nrow(OutData)
OutData <- read.csv("Out_of_time.txt", sep = "|", header = TRUE, na.strings ="\\N",quote = "")
OutData$Number_of_times_rated_2016_2017_N
OutData$target<-ifelse(OutData$Updated_MVC_17_18=='Y',1,0)
OutData$target <- as.factor(OutData$target)
table(OutData$target)

OutData$percent_not_acceptable_cases_2015_2016_N <- OutData$percent_not_acceptable_cases_2016_2017_N
OutData$percent_acceptable_cases_2015_2016_N <- OutData$percent_acceptable_cases_2016_2017_N
OutData$percent_not_rated_cases_2015_2016_N <- OutData$percent_not_rated_cases_2016_2017_N
OutData$percent_outstanding_cases_2015_2016_N <- OutData$percent_outstanding_cases_2016_2017_N
OutData$percent_discount_cases_2015_2016_N <- OutData$percent_discount_cases_2016_2017_N
OutData$percent_delay_cases_2015_2016_N <- OutData$percent_delay_cases_2016_2017_N
OutData$Range_of_services_2015_2016_N <- OutData$Range_of_services_2016_2017_N
OutData$Range_of_subjects_2015_2016_N <- OutData$Range_of_subjects_2016_2017_N
OutData$Average_word_count_2015_2016_N <- OutData$Average_word_count_2016_2017_N
OutData$Average_Delay_2015_2016_N <- OutData$Average_Delay_2016_2017_N
OutData$Favourite_Time_2015_2016_N <- OutData$Favourite_Time_2016_2017_N
OutData$Favourite_Day_Week_2015_2016_N <- OutData$Favourite_Day_Week_2016_2017_N
OutData$Favourite_Week_number_2015_2016_N <- OutData$Favourite_Week_number_2016_2017_N
OutData$Favourite_Month_2015_2016_N <- OutData$Favourite_Month_2016_2017_N
OutData$maximum_rating_2015_2016_N <- OutData$maximum_rating_2016_2017_N
OutData$is_delay_2015_2016_N <- OutData$is_delay_2016_2017_N
OutData$Favourite_service_segment_2015_2016_N <- OutData$Favourite_service_segment_2016_2017_N
OutData$Favourite_service_2015_2016_N <- OutData$Favourite_service_2016_2017_N
OutData$percent_offer_cases_2015_2016_N <- OutData$percent_offer_cases_2016_2017_N
OutData$percent_paid_mre_2015_2016_N <- OutData$percent_paid_mre_2016_2017_N
OutData$percent_valid_mre_2015_2016_N <- OutData$percent_valid_mre_2016_2017_N
OutData$percent_quality_reedit_2015_2016_N <- OutData$percent_quality_reedit_2016_2017_N
OutData$Number_of_times_rated_2015_2016_N <- OutData$Number_of_times_rated_2016_2017_N
OutData$No_of_Revision_in_subject_area_2015_2016_N <- OutData$No_of_Revision_in_subject_area_2016_2017_N
OutData$No_of_Revision_in_price_after_tax_2015_2016_N <- OutData$No_of_Revision_in_price_after_tax_2016_2017_N
OutData$No_of_Revision_in_service_id_2015_2016_N <- OutData$No_of_Revision_in_service_id_2016_2017_N
OutData$No_of_Revision_in_delivery_date_2015_2016_N <- OutData$No_of_Revision_in_delivery_date_2016_2017_N
OutData$No_of_Revision_in_words_2015_2016_N <- OutData$No_of_Revision_in_words_2016_2017_N
OutData$Favourite_subject_2015_2016_N <- OutData$Favourite_subject_2016_2017_N
OutData$Favourite_SA1_name_2015_2016_N <- OutData$Favourite_SA1_name_2016_2017_N
OutData$Favourite_SA1_5_name_2015_2016_N <- OutData$Favourite_SA1_5_name_2016_2017_N
OutData$Favourite_SA1_6_name_2015_2016_N <- OutData$Favourite_SA1_6_name_2016_2017_N
OutData$ATV_2015_2016_N <- OutData$ATV_2016_2017_N
OutData$frequency_2015_2016_N <- OutData$frequency_2016_2017_N
OutData$Recency_2015_2016_N <- OutData$Recency_2016_2017_N
OutData$FTD_2015_2016_Ns <- OutData$FTD_2016_2017_Ns
OutData$LTD_2015_2016_Ns <- OutData$LTD_2016_2017_Ns
OutData$ADGBT_2015_2016_N <- OutData$ADGBT_2016_2017_N
OutData$STD_2015_2016_N <- OutData$STD_2016_2017_N
OutData$Inactivity_ratio_2015_2016_N <- OutData$Inactivity_ratio_2016_2017_N
OutData$Bounce_2015_2016_N <- OutData$Bounce_2016_2017_N
OutData$Total_Standard_price_2015_2016_N <- OutData$Total_Standard_price_2016_2017_N
OutData$L2_SEGMENT_new_2015_2016_N <- OutData$L2_SEGMENT_new_2016_2017_N
OutData$Ever_rated_2015_2016_N <- OutData$Ever_rated_2016_2017_N
OutData$Ever_rated_outstanding_2015_2016_N <- OutData$Ever_rated_outstanding_2016_2017_N
OutData$Ever_rated_not_acceptable_2015_2016_N <- OutData$Ever_rated_not_acceptable_2016_2017_N
OutData$is_preferred_transalator_2015_2016_N <- OutData$is_preferred_transalator_2016_2017_N
OutData$Ever_rated_acceptable_2015_2016_N <- OutData$Ever_rated_acceptable_2016_2017_N
OutData$Is_in_top_sub_Area_2015_2016_N <- OutData$Is_in_top_sub_Area_2016_2017_N
OutData$Is_in_top_sub_Area_1_2015_2016_N <- OutData$Is_in_top_sub_Area_1_2016_2017_N
OutData$Vintage_2015_2016_N <- OutData$Vintage_2016_2017_N
OutData$New_or_existing_in_2015_2016_N <- OutData$New_or_existing_in_2016_2017_N
OutData$No_of_paid_mre_in_2015_2016_N <- OutData$No_of_paid_mre_in_2016_2017_N
OutData$No_of_valid_mre_in_2015_2016_N <- OutData$No_of_valid_mre_in_2016_2017_N
OutData$No_of_quality_reedit_mre_in_2015_2016_N <- OutData$No_of_quality_reedit_mre_in_2016_2017_N
OutData$enquiry_job_ratio_2015_2016_N <- OutData$enquiry_job_ratio_2016_2017_N
OutData$Ratio_paid_mre_to_total_orders_2015_2016_N <- OutData$Ratio_paid_mre_to_total_orders_2016_2017_N
OutData$Ratio_valid_mre_to_total_orders_2015_2016_N <- OutData$Ratio_valid_mre_to_total_orders_2016_2017_N
OutData$Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N <- OutData$Ratio_quality_re_edit_mre_to_total_orders_2016_2017_N
OutData$distinct_translators_2015_2016_N <- OutData$distinct_translators_2016_2017_N

######## Variable  cleaning #########

OutData$ATV_2015_2016_N[is.na(OutData$ATV_2015_2016_N)] <- 0
OutData$frequency_2015_2016_N[is.na(OutData$frequency_2015_2016_N)] <- 0
OutData$Recency_2015_2016_N[is.na(OutData$Recency_2015_2016_N)] <- 0
OutData$ADGBT_2015_2016_N[is.na(OutData$ADGBT_2015_2016_N)] <- 0
OutData$Total_Standard_price_2015_2016_N[is.na(OutData$Total_Standard_price_2015_2016_N)] <- 0
OutData$Number_of_times_rated_2015_2016_N[is.na(OutData$Number_of_times_rated_2015_2016_N)] <- 0
OutData$Range_of_services_2015_2016_N[is.na(OutData$Range_of_services_2015_2016_N)] <- 0
OutData$Average_word_count_2015_2016_N[is.na(OutData$Average_word_count_2015_2016_N)] <- 0
OutData$Average_Delay_2015_2016_N[is.na(OutData$Average_Delay_2015_2016_N)] <- 0
OutData$Number_of_group[is.na(OutData$Number_of_group)] <- 0
OutData$enquiry_job_ratio_2015_2016_N[is.na(OutData$enquiry_job_ratio_2015_2016_N)] <- 0
OutData$No_of_Revision_in_subject_area_2015_2016_N[is.na(OutData$No_of_Revision_in_subject_area_2015_2016_N)] <- 0
OutData$No_of_Revision_in_price_after_tax_2015_2016_N[is.na(OutData$No_of_Revision_in_price_after_tax_2015_2016_N)] <- 0
OutData$No_of_Revision_in_service_id_2015_2016_N[is.na(OutData$No_of_Revision_in_service_id_2015_2016_N)] <- 0
OutData$No_of_Revision_in_delivery_date_2015_2016_N[is.na(OutData$No_of_Revision_in_delivery_date_2015_2016_N)] <- 0
OutData$No_of_Revision_in_words_2015_2016_N[is.na(OutData$No_of_Revision_in_words_2015_2016_N)] <- 0
OutData$Vintage_2015_2016_N[is.na(OutData$Vintage_2015_2016_N)] <- 0
OutData$percent_offer_cases_2015_2016_N[is.na(OutData$percent_offer_cases_2015_2016_N)] <- 0
OutData$percent_delay_cases_2015_2016_N[is.na(OutData$percent_delay_cases_2015_2016_N)] <- 0
OutData$Ratio_paid_mre_to_total_orders_2015_2016_N[is.na(OutData$Ratio_paid_mre_to_total_orders_2015_2016_N)] <- 0

# Not included in Model
#OutData$Range_of_subjects_2015_2016_N[is.na(OutData$Range_of_subjects_2015_2016_N)] <- 0
#OutData$percent_discount_cases_2015_2016_N[is.na(OutData$percent_discount_cases_2015_2016_N)] <- 0
#OutData$distinct_translators_2015_2016_N[is.na(OutData$distinct_translators_2015_2016_N)] <- 0
#OutData$Ratio_valid_mre_to_total_orders_2015_2016_N[is.na(OutData$Ratio_valid_mre_to_total_orders_2015_2016_N)] <- 0
#OutData$Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N[is.na(OutData$Ratio_quality_re_edit_mre_to_total_orders_2015_2016_N)] <- 0

OutData$Is_foreign_Univ <- as.character(OutData$Is_foreign_Univ)   
OutData$Is_foreign_Univ[is.na(OutData$Is_foreign_Univ)] <-"N"  
OutData$Is_foreign_Univ <- as.factor(OutData$Is_foreign_Univ)

OutData$Ever_rated_2015_2016_N <- as.character(OutData$Ever_rated_2015_2016_N)   
OutData$Ever_rated_2015_2016_N[is.na(OutData$Ever_rated_2015_2016_N)] <-"N" 
OutData$Ever_rated_2015_2016_N <- as.factor(OutData$Ever_rated_2015_2016_N)

OutData$Ever_rated_outstanding_2015_2016_N <- as.character(OutData$Ever_rated_outstanding_2015_2016_N)  
OutData$Ever_rated_outstanding_2015_2016_N[is.na(OutData$Ever_rated_outstanding_2015_2016_N)] <-"N"  
OutData$Ever_rated_outstanding_2015_2016_N <- as.factor(OutData$Ever_rated_outstanding_2015_2016_N)

OutData$Ever_rated_not_acceptable_2015_2016_N <- as.character(OutData$Ever_rated_not_acceptable_2015_2016_N)   
OutData$Ever_rated_not_acceptable_2015_2016_N[is.na(OutData$Ever_rated_not_acceptable_2015_2016_N)] <-"N" 
OutData$Ever_rated_not_acceptable_2015_2016_N <- as.factor(OutData$Ever_rated_not_acceptable_2015_2016_N)

OutData$Ever_rated_acceptable_2015_2016_N <- as.character(OutData$Ever_rated_acceptable_2015_2016_N)   
OutData$Ever_rated_acceptable_2015_2016_N[is.na(OutData$Ever_rated_acceptable_2015_2016_N)] <-"N"  
OutData$Ever_rated_acceptable_2015_2016_N <- as.factor(OutData$Ever_rated_acceptable_2015_2016_N)

OutData$is_preferred_transalator_2015_2016_N <- as.character(OutData$is_preferred_transalator_2015_2016_N)   
OutData$is_preferred_transalator_2015_2016_N[is.na(OutData$is_preferred_transalator_2015_2016_N)] <-"N" 
OutData$is_preferred_transalator_2015_2016_N <- as.factor(OutData$is_preferred_transalator_2015_2016_N)

OutData$Is_in_top_sub_Area_2015_2016_N <- as.character(OutData$Is_in_top_sub_Area_2015_2016_N) 
OutData$Is_in_top_sub_Area_2015_2016_N[is.na(OutData$Is_in_top_sub_Area_2015_2016_N)] <-"N"  
OutData$Is_in_top_sub_Area_2015_2016_N <- as.factor(OutData$Is_in_top_sub_Area_2015_2016_N)

OutData$Is_in_top_sub_Area_1_2015_2016_N <- as.character(OutData$Is_in_top_sub_Area_1_2015_2016_N)   
OutData$Is_in_top_sub_Area_1_2015_2016_N[is.na(OutData$Is_in_top_sub_Area_1_2015_2016_N)] <-"N" 
OutData$Is_in_top_sub_Area_1_2015_2016_N <- as.factor(OutData$Is_in_top_sub_Area_1_2015_2016_N)

OutData$is_referred <- as.character(OutData$is_referred)  
OutData$is_referred[is.na(OutData$is_referred)] <-"N"  
OutData$is_referred <- as.factor(OutData$is_referred)

OutData$editage_card_user <- as.character(OutData$editage_card_user)  
OutData$editage_card_user[is.na(OutData$editage_card_user)] <-"N"  
OutData$editage_card_user <- as.factor(OutData$editage_card_user)

OutData$is_part_of_group <- as.character(OutData$is_part_of_group)   
OutData$is_part_of_group[is.na(OutData$is_part_of_group)] <-"N" 
OutData$is_part_of_group <- as.factor(OutData$is_part_of_group)

OutData$Number_of_group <- as.character(OutData$Number_of_group)  
OutData$Number_of_group[is.na(OutData$Number_of_group)] <-"N"  
OutData$Number_of_group <- as.factor(OutData$Number_of_group)

OutData$salutation <- as.character(OutData$salutation)   
OutData$salutation[is.na(OutData$salutation)] <-"N" 
OutData$salutation <- as.factor(OutData$salutation)

OutData$New_or_existing_in_2015_2016_N <- as.character(OutData$New_or_existing_in_2015_2016_N)  
OutData$New_or_existing_in_2015_2016_N[is.na(OutData$New_or_existing_in_2015_2016_N)] <-"N"  
OutData$New_or_existing_in_2015_2016_N <- as.factor(OutData$New_or_existing_in_2015_2016_N)

OutData$maximum_rating_2015_2016_N <- as.character(OutData$maximum_rating_2015_2016_N) 
#unique(Data$maximum_rating_2015_2016_N)
OutData$maximum_rating_2015_2016_N[OutData$maximum_rating_2015_2016_N == "not-acceptable"] <- "not-accept"
OutData$maximum_rating_2015_2016_N[OutData$maximum_rating_2015_2016_N == "outstanding"] <- "outstandin"
OutData$maximum_rating_2015_2016_N[is.na(OutData$maximum_rating_2015_2016_N)] <-"N"  
OutData$maximum_rating_2015_2016_N <- as.factor(OutData$maximum_rating_2015_2016_N)
table(OutData$maximum_rating_2015_2016_N)

######################################

## Removing Some Customers based on outlier treatment  

rm2 <- which(OutData$eos_user_id == 187277|
               OutData$eos_user_id == 49313|
               OutData$eos_user_id == 123648|
               OutData$eos_user_id == 197614|
               OutData$eos_user_id == 194298|
               OutData$eos_user_id == 190230|
               OutData$eos_user_id == 43725|
               OutData$eos_user_id == 47470|
               OutData$eos_user_id == 59080|
               OutData$eos_user_id == 122001|
               OutData$eos_user_id == 129230)
length(rm2)
tot_rm <- c(rm2)
length(tot_rm)
unq_rm <- unique(tot_rm)
length(unq_rm)

# Final OutDataframe to be used for Modeling

OutData <- OutData[-unq_rm, ]

####    Train and test split

dt = sort(sample(nrow(Data), nrow(Data)*.7))

train<-Data[dt,]
length(train$target)
test<-Data[-dt,]
length(test$target)


wn <- sum(train$target==0)/ length(train$target)
wy = 1

table(Data$target)
rf=randomForest(target~
                  #Continuous Variables
                  ATV_2015_2016_N+
                  frequency_2015_2016_N+
                  Recency_2015_2016_N+
                  ADGBT_2015_2016_N+
                  Total_Standard_price_2015_2016_N+
                  Number_of_times_rated_2015_2016_N+
                  Range_of_services_2015_2016_N+
                  Average_word_count_2015_2016_N+
                  Average_Delay_2015_2016_N+
                  enquiry_job_ratio_2015_2016_N+
                  No_of_Revision_in_subject_area_2015_2016_N+
                  No_of_Revision_in_price_after_tax_2015_2016_N+
                  No_of_Revision_in_service_id_2015_2016_N+
                  No_of_Revision_in_delivery_date_2015_2016_N+
                  No_of_Revision_in_words_2015_2016_N+
                  Vintage_2015_2016_N+
                  percent_offer_cases_2015_2016_N+
                  percent_delay_cases_2015_2016_N+
                  Ratio_paid_mre_to_total_orders_2015_2016_N
                  ,data = train,  sampsize = c("0" = 500, "1" = 50),classwt=c("0"=wn,"1"=wy),
                ntrees = 1500 ,mtry = 4, nodesize = 5)


##  model accuracy ##

library(pROC)
library(ROCR)

###   Calculating accuracy - area under the curve

auc(train$target, predict(rf, type="prob")[,2]) # train
auc(test$target, predict(rf, newdata = test, type="prob")[,2]) # test
auc(OutData$target, predict(rf, newdata = OutData, type="prob")[,2]) # Out of time

###  Confusion matrix 

table(train$target, ifelse(predict(rf, type = "prob")[,2] > 0.15, 1, 0)) # train
table(test$target, ifelse(predict(rf, newdata = test, type = "prob")[,2] > 0.15, 1, 0)) # test
table(OutData$target, ifelse(predict(rf, newdata = OutData, type = "prob")[,2] > 0.15, 1, 0)) # Out-of-time


