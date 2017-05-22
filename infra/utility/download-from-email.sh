#!/bin/bash

#SUBMISSION_NO=$(xclip -selection clipboard -o | grep rowKey | egrep -o "([0-9a-z]+-)+[0-9a-z]+")
SUBMISSION_NO=$(xclip -selection clipboard -o | grep ^" "*\"rowKey | awk 'BEGIN{FS=":";}{print $2}' | sed 's/["\, ]//g')
echo $SUBMISSION_NO

INPUT_FILE_NAME=$(xclip -selection clipboard -o | grep ^" "*\"inputFileName | awk 'BEGIN{FS=":";}{print $2}' | sed 's/["\,]//g')
INPUT_FILE_NAME=${INPUT_FILE_NAME# }
echo $INPUT_FILE_NAME

CLIENT_EMAIL=$(xclip -selection clipboard -o | grep ^" "*\"email | awk 'BEGIN{FS=":";}{print $2}' | sed 's/["\, ]//g')
echo $CLIENT_EMAIL

TIMESTAMP=$(xclip -selection clipboard -o | grep ^" "*\"timestamp | awk "BEGIN{FS=\":\"}{print strftime(\"%F\",\$2/1000, 1)}")
echo $TIMESTAMP

RUN_PERIOD=$(xclip -selection clipboard -o | grep ^" "*\"paramsJSON)
RUN_PERIOD=$(echo ${RUN_PERIOD#*:} | sed 's/[\\]//g')
RUN_PERIOD=${RUN_PERIOD#*\"}
RUN_PERIOD=${RUN_PERIOD%\"*}
RUN_PERIOD=$(echo $RUN_PERIOD | jq ".period" | sed "s/[\"s]//g")
echo $RUN_PERIOD

echo -e \
"export FCUNIT=${RUN_PERIOD}
export CLIENTMAIL=${CLIENT_EMAIL}
export DATE_OF_THE_SUBMISSION=${TIMESTAMP}
export INPUT_DATA_FILE_NAME=${INPUT_FILE_NAME}
export UNIQUE_SUBMISSION_NO=${SUBMISSION_NO}

export APP_NAME=FREE_RETAIL
export TRIALRUN=0
export SHOW_UNMODELLED=0

# The values below have defaults in command/defaults.sh. Setting them here will override those defaults
# export FCPERIOD=8
# export HISTGRAPHDEPTH=60
# export NO_SUPPLY_DETERMINATION_PERIODS=30
# export MIN_PERIODS_FOR_MODELING=20
# export IN_COLUMNS=prodName,saleDate,sales
# export TRIM_PERIODS=true - (allowed values: true,false; default value: false when FCUNIT=day, true otherwise) in case of monthly or weekly forecasts - whether to delete the last partial period that supposedly has less sales and would skew forecasts.
# export MAIL_COMPLETION_RECEIVER - defaults to CLIENTMAIL. The receiver of the mail that will be sent upon successful completion, when SEND_COMPLETION_MAIL is provided

# The values below are empty by default and only have meaning in certain scenarios
# export AUX_DATA_TYPE1=weather - used in APP_NAME=FULL_RETAIL; List of type 1 auxiliary data
# export AUX_DATA_TYPE2=holiday,nedelya-ads,moonphases - used in APP_NAME=FULL_RETAIL; List of type 2 auxiliary data
# export BUSINESS_LOCATION=Sofia - Used for the weather service
# export IN_SPEC_CHARS=\"optionally enclosed by '\"' escaped by '\"'\" - extra setting for the load data infile query for the input file. This stands after FIELDS TERMINATED BY FIELD_SEP
# export FC_START_DATE=2016-07-01 - the date from which to start the forecast. Later data is truncated. If this date is after the latest current data, it is ignored.
# export UPLOAD_REPORT=true - regardless of the value, if this variable is not empty, the report will be uploaded to the website
# export GENERATE_PDF=true - regardless of the value, if UPLOAD_REPORT is not empty and this variable is not empty, the pdf service will be contacted and resulting pdfs will be uploaded to the website. WARNING: this delays the report completion by around 10 mins.
# export SEND_SUCCESS_MAIL=true - regardless of the value, if UPLOAD_REPORT is not empty and this variable is not empty, an email will be sent to MAIL_COMPLETION_RECEIVER

# The following will be attempted to be auto-detected, if not provided here
# export INPUT_ENCODING=WINDOWS-1251
# export INPUT_DATE_FORMAT=%m/%d/%y

# The following don't have direct impact over the report's business logic. They are instructions to the lab (may be moved to a separate file for separation of concerns)
# export KEEP_UPLOAD_FOLDER= - regardless of the value, if this variable is not empty, the subfolder in /uploads (where the submission data was uploaded) won't be removed
# export CUSTOM_UPLOADS_SUBFOLDER= - regardless of the value, if this variable is not empty, the lab will try to get the input data form /uploads/${CUSTOM_UPLOADS_SUBFOLDER} and fail if it is not there
# export EXPORT_PROD_NOM=true - regardless of the value, if this variable is not empty, the product id-to-name mapping is exported in a _final_productnom.csv, for debug purposes
# export NEDELYA_PROD_COMP=true - regardless of the value, if this variable is not empty, the csv that input into product strategies will be exported.
" > $1/request.sh

eval $(~/a4e/infra/tools/azure-admin.sh s a4estorage)
(cd $1 && azure storage file download uploads "${SUBMISSION_NO}/${INPUT_FILE_NAME}")
