#!/usr/bin/env bash

set -e

# Function applies label to the workflow and all children objects.
# As well it applies move label command.

lpad_of_2() {
  increment_version=$1

  padded_version_number="00000${increment_version}"
  myresult="${padded_version_number: -2}"
  echo $myresult
}

function get_latest_label() {
  echo
  echo "==============get_latest_label========================================="

  latest_label=$(pmrep listobjects -o Label | grep -oP $LABEL_REGEX | sort | tail -1)

  echo Label found $latest_label

  #ls -1 | grep -oP "w\d\d" | tail -1

  label_prefix="lab_SE_EDW_P6_"

  #parse last used label
  last_lbl_week_number=$(echo $latest_label | grep -oP "W\d\d")
  last_lbl_version=$(echo $latest_label | grep -oP "\d+$")

  current_week_number="W"$(lpad_of_2 $(date +%V))
  current_year=$(date +"%Y")

  if [ $last_lbl_week_number = $current_week_number ]; then
    increment_version=$((10#$last_lbl_version + 1)) #force base10 interpretation
  else
    #else start a new sequence
    increment_version=1
  fi

  proposed_label="${label_prefix}${current_year}_${current_week_number}.${increment_version}"

  echo
  echo latest used label week number is $last_lbl_week_number and latest label version is $last_lbl_version
  echo
  echo current week number is $current_week_number and proposed label version is $increment_version
  echo proposed full label $proposed_label

  read -p "Do you accept proposed label: Y/N " VAR_INPUT
  
  shopt -s nocasematch
  if [[ ${VAR_INPUT,,} == "y" ]] ;then
         echo
         echo "The proposed label will be used"
  else
         read -p "Please enter new label: " proposed_label
  fi
  shopt -u nocasematch
  
  assign_label_variable $proposed_label

}

function get_label() {

  read -p "Do you want reuse existing label: Y/N " VAR_INPUT

  shopt -s nocasematch
  if [[ ${VAR_INPUT,,} == "y" ]] ;then
       echo
       echo "The provided label will be used"
       read -p "Please enter the label: " proposed_label

       assign_label_variable $proposed_label
  else
      get_latest_label
  fi

  shopt -u nocasematch
}

# Assigns global variable to label name
function assign_label_variable() {
  proposed_label=$1

  echo Final label which will be applied $proposed_label
  LABEL_NAME=$proposed_label
}

function apply_label() {
  infa_folder=$1
  wf_name=$2

  OBJ_TYPE="workflow"

  echo "Informatica folder:" $infa_folder
  echo "Workflow name:" $wf_name

  pmrep applylabel -a $LABEL_NAME -n $wf_name -o $OBJ_TYPE -f $infa_folder -p children -m
}

function create_label() {
  LABEL_NAME=$1
  LABEL_COMMENT=$2

  pmrep createlabel -a "$LABEL_NAME" -c "$LABEL_COMMENT"
}

function delete_label() {
  LABEL_NAME=$1

  pmrep deletelabel -a "$LABEL_NAME" -f
}

function connect() {

  echo
  echo "==============connect=================================================="
  pmrep connect -r  $INFA_REP -d $INFA_DOMAIN -n $INFA_USER -s $INFA_USD -x $INFA_PASS
}

function disconnect() {
  echo
  echo "==============disconnect==============================================="
  pmrep cleanup
}

#label lab_SE_EDW_P6_2018_W01.1
#label lab_SE_EDW_P6_2018_W02.1
#label lab_SE_EDW_P6_2018_W31.1
#label lab_SE_EDW_P6_2018_W31.2
#label lab_SE_EDW_P6_2018_W31.3
#label lab_SE_EDW_P6_2018_W31.99999
function get_label_list() {
    echo Getting list of labels...

    my_array=( $(pmrep listobjects -o Label | grep -oP $LABEL_REGEX | sort) )

    echo number of labels: ${#my_array[@]}
    for item in ${my_array[*]}
    do
        printf "%s\n" $item
    done

}

function get_all_labels_from_query(){
  pmrep  executequery -q "Custody_Information_Labels" -t shared
}

function read_workflows_apply_label() {

  echo
  echo "==============read_workflows_apply_label==============================="
  echo Applying label $LABEL_NAME


  while IFS=$' \t\n\r' read -r line
  do
    arrIN=(${line//./ })
    infa_folder=${arrIN[0]}
    wf_name=${arrIN[1]}
    echo Workflow found: ${infa_folder}.${wf_name}

    apply_label $infa_folder $wf_name
  done < $FILE
}

#Apply label for each workflow from text file
#Each line of text file is split into array of two items.
#Remove non-printing characters
function validate_wf_list() {

  echo
  echo "==============validate_wf_list========================================="

  row_counter=0

  while IFS=$' \t\n\r' read -r line
  do
    row_counter=$((row_counter + 1))

    arrIN=(${line//./ })
    count_line_items=${#arrIN[*]}
    echo text file row: $line
    echo length of array per text file row: $count_line_items

    if [[ $count_line_items -ne 2 ]]; then
      echo there was error finding folder name and workflow name in the text file line
      echo quiting..
      exit 1
    fi
  done < $FILE

  echo
  echo Total $row_counter rows found
}

##########################
# Global variables below
##########################

#environment variables
export PATH="$PATH;C:\Informatica\10.1.0\clients\PowerCenterClient\CommandLineUtilities\PC\server\bin"
export INFA_DOMAINS_FILE="C:\Informatica\10.1.0\clients\PowerCenterClient\domains.infa"
export INFA_HOME="C:\Informatica\10.1.0\clients\PowerCenterClient\CommandLineUtilities\PC\server\bin"

#user global variables
export INFA_USER=$(xmllint --xpath '/config/infa_user/text()' --nocdata config.xml)
export INFA_PASS=$(xmllint --xpath '/config/infa_pass/text()' --nocdata config.xml)
export INFA_USD=$(xmllint --xpath '/config/infa_usd/text()' --nocdata config.xml)
export INFA_DOMAIN=$(xmllint --xpath '/config/infa_domain/text()' --nocdata config.xml)
export INFA_REP=$(xmllint --xpath '/config/infa_rep/text()' --nocdata config.xml)

echo $INFA_USER
#echo $INFA_PASS
echo $INFA_USD
echo $INFA_DOMAIN
echo $INFA_REP

#deployment global variables
FILE=$(xmllint --xpath '/config/workflow_list_file/text()' --nocdata config.xml)
LABEL_REGEX=$(xmllint --xpath '/config/label_regex/text()' --nocdata config.xml)
LABEL_NAME=
LABEL_COMMENT=$(xmllint --xpath '/config/label_comment/text()' --nocdata config.xml)

echo $FILE
echo $LABEL_REGEX
echo $LABEL_COMMENT

##########################
# Main code below
##########################

validate_wf_list

#delete_label $LABEL_NAME
connect
#get_label_list
get_label
create_label $LABEL_NAME $LABEL_COMMENT
read_workflows_apply_label
##get_all_labels_from_query
disconnect
echo end of script
