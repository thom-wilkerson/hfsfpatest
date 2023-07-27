output: html_document


{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)


#Install Packages
install.packages("here")
install.packages("readxl")
install.packages("writexl")
install.packages("openxlsx")
install.packages("dplyr")
install.packages("stringr", repos='http://cran.us.r-project.org')
install.packages("stringi", repos='http://cran.us.r-project.org')
install.packages("tidyr")


library(here)
library(readxl)
library(writexl)
library(openxlsx)
library(dplyr)
library(stringr)
library(stringi)
library(tidyr)




spreadsheet="Find Journal Lines Custom - Worktag Breakout R1285.xlsx"






data<-read_xlsx("C:/Users/twilker/Documents/Find Journal Lines Custom - Worktag Breakout R1285.xlsx",sheet="Sheet1",skip=26)
data[1:5,1:15]





#load spreadsheet with all columns as text to prevent errors when loading Journal Number
data<-read_xlsx(spreadsheet,sheet="Sheet1",skip=29,col_types="text")
#convert ledger debit amount and ledger credit amount back to numeric
data$`Ledger Debit Amount`<-as.numeric(data$`Ledger Debit Amount`)
data$`Ledger Credit Amount`<-as.numeric(data$`Ledger Credit Amount`)
#convert accounting date back to date, specify origin as 12/30/1899 to convert excel dates properly
data$`Accounting Date`<-as.Date(as.numeric(data$`Accounting Date`), origin = "1899-12-30")

#NOTE: if Worktags column is not splitting properly, check that return characters are correct in the following line of code down below:
#newCols<-str_split(data$Worktags,"\r\n\r\n")
#This format is correct when specifying text when loading excel data, but if no column type is specified then the delimiter is \n\n

#categories to split by spaces
splitSpace<-c("Balancing Unit","Fund","Function","Activity","Project","Program","Gift ","Grant","Loan","Cost Center","Function","Resource")

#categories to split by parentheses
splitParens<-c("Spend Category","Expense Category","Revenue Category")

#split Worktags column by returns. This will generate a list of lists. 
#The first list corresponds to each row of the data, the second list corresponds to each entry in Worktag
newCols<-str_split(data$Worktags,"\r\n\r\n|\n\n")
#assign names to the first list corresponding to the order of the data
names(newCols)<-seq(1,length(newCols),by=1)
#make everything into a single list, transfer assigned names to each group
newCols<-setNames(unlist(newCols, use.names=F),rep(names(newCols), lengths(newCols)))
#convert to dataframe
newCols<-data.frame(order=names(newCols),entry=newCols,stringsAsFactors=FALSE)
#split entry and store category
newCols$category=str_split_fixed(newCols$entry,": ",2)[,1]
#split entry and store value
newCols$value=str_split_fixed(newCols$entry,": ",2)[,2]
#split value and store code
#value will be split differently based on what category it is, the lists for splitting are above
#The splitParens category need to reverse the string before splitting.
#This allows easier capture of the last split (first when reversed) because sometimes these columns have multiple parenthesis
newCols<-newCols %>% mutate(code=case_when(category %in% splitSpace ~ str_split_fixed(value," ",2)[,1],
                                           category %in% splitParens ~ stri_reverse(str_split_fixed(stri_reverse(value),"\\(",2)[,1]),
                                           TRUE ~ value))

# newCols<-newCols %>% mutate(code=case_when(category=="Spend Category" ~ stri_reverse(str_split_fixed(stri_reverse(value),"\\(",2)[,1]),
#                                            category=="Revenue Category" ~ stri_reverse(str_split_fixed(stri_reverse(value),"\\(",2)[,1]),
#                                            category %in% unchangedCategories ~ value,
#                                            TRUE ~ str_split_fixed(value," ",2)[,1]))


#remove leftover right parenthesis from codes
newCols$code<-sub("\\)","",newCols$code)

#pivot into wide table with original values
newCols_wide_fullEntry<-newCols %>% select(-value,-code) %>% pivot_wider(names_from=category,values_from=entry)
colnames(newCols_wide_fullEntry)<-paste(colnames(newCols_wide_fullEntry),"full",sep=" ")

#pivot into wide table with codes
newCols_wide<-newCols %>% select(-entry,-value) %>% pivot_wider(names_from=category,values_from=code)

#combine with original data
data_new<-cbind(data,newCols_wide_fullEntry,newCols_wide)

# #decided to skip reordering columns, this introduces issues when there are multiple columns with the same name
# #Want new data to replace Worktags column
# #Do this by removing Worktags, then moving Match ID to last column (Match ID was only column after Worktags)
# # data_new<-data_new %>% select(-Worktags) %>% select(-order) %>% select(-`Match ID`,`Match ID`)
# data_new<-data_new %>% select(-order) %>% select(-`Match ID`,`Match ID`)

#make output filename
outfile<-paste(sub(".xlsx","",spreadsheet),"formatted.xlsx",sep="_")

#write data to file
write_xlsx(data_new,outfile)

wb<-loadWorkbook(outfile)
addWorksheet(wb, sheetName="WD Export")
writeData(wb,"WD Export",data_new)
saveWorkbook(wb,outfile,overwrite=TRUE)


