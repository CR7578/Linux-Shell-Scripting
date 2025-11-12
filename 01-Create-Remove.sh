#!/bin/bash

##############################################################################
# Author: CHETHAN N
# Date: 11/11/2025
#
# This bash script can create / remove the directory and files
#
# To create an new directory and create two files inside new directory
# bash 01-create-remove.sh 1
#
# To remove / delete the files and Directory which were already created
# bash 01-create-remove.sh 0
#
##############################################################################
# Directory Name
DIR_NAME="script_dir";



if [ $# -ne 1 ]; then
	echo "Invalid Usage of scrpit";
	echo "Usage Example :-";
	echo "";
	echo "bash 01-create-remove.sh 0";
	echo "		or		   ";     
	echo "";
	echo "bash 01-create-remove.sh 1";
	exit 1
fi

if [ $1 -eq 1 ]; then

	if [ -d $DIR_NAME ]; then
		echo "Directory already exist";
		echo "Use 0 to remove the existing Directory";
		echo "bash 01-create-remove.sh 0";
		exit 1;
	fi
	
	#Create a directory
	mkdir -v $DIR_NAME
	if [ -d $DIR_NAME ]; then
		echo "Creating Directory Successful";
		echo "";
		echo "#########################################################";
		echo "";

		#Create two files
		touch $DIR_NAME/first-file $DIR_NAME/second-file
		echo "Two files are created inside script_dir Directory."
	else
		echo "Creating Directory Failed"
	fi
	
elif [ $1 -eq 0 ]; then
	
	if [ ! -d $DIR_NAME ]; then
		echo "Directory not exist";
		echo "Use 1 to create the Directory";
		echo "bash 01-create-remove.sh 1";
		exit 1;
	fi
	
	#Delete/Remove the Already existing Directory
	rm -rfv $DIR_NAME
	echo "Directory removed successfully";
fi
