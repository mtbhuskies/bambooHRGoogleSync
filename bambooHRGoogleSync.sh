#!/bin/bash
# ----------------------------------------------------------------------
# Script Name:    bambooHRGoogleSync.sh
# Description:    Updates Google Workspace users account information from BambooHR
# Author:         @mtbhuskies
# Created on:     10/08/2024
# Version:        1.0
# ----------------------------------------------------------------------
# Usage:          Invoke the script from a computer or cloud instance that has gamadv-xtd3
# Example:        ./bambooHRGoogleSync.sh
# ----------------------------------------------------------------------
# Environment:    Requires gamadv-xtd3, can be run locally or in Google Cloud Shell
# Dependencies:   gamadv-xtd3, BambooHR API Key
# ----------------------------------------------------------------------
# Revision History:
#   Date          Author          Description
#   10/08/2024    @mtbhuskies     Initial release
# ----------------------------------------------------------------------

# Variables
bamboohrAPIKey="apikey"
domain="domain"
gamPath="path to your gam binary, ie. /bin/gamadv-xtd3/gam"

# Fetch employee directory from BambooHR
curl -s -u "${bamboohrAPIKey}:x" "https://api.bamboohr.com/api/gateway.php/${domain}/v1/employees/directory" -o /home/kevin/employees.xml

# Extract and format data for all employees using semicolon as delimiter, including Employee ID
echo "employeeId;email;firstname;lastname;preferredname;jobtitle;workphone;mobilephone;location;department" > users.csv
xmlstarlet sel -t -m "//employee" \
  -v "concat(@id, ';', ./field[@id='workEmail'], ';', ./field[@id='firstName'], ';', ./field[@id='lastName'], ';', ./field[@id='preferredName'], ';', ./field[@id='jobTitle'], ';', ./field[@id='workPhone'], ';', ./field[@id='mobilePhone'], ';', ./field[@id='location'], ';', ./field[@id='department'])" -n employees.xml | xmlstarlet unesc >> users.csv

# Display the extracted data
echo "Extracted data for all employees:"
cat users.csv

# Read and parse the data, ensuring proper handling of each employee
while IFS=";" read -r employeeId email firstname lastname preferredname jobtitle workphone mobilephone location department
do
  if [ "$email" != "email" ]; then
    # Use preferredName if available, otherwise use firstName
    givenname="$firstname"
    if [ -n "$preferredname" ]; then
      givenname="$preferredname"
    fi

    # Split location into city (locality) and state (region)
    IFS=", " read -r locality region <<< "$location"

    echo "Parsed data for employee:"
    echo "Employee ID: $employeeId"
    echo "Email: $email"
    echo "First Name: $firstname"
    echo "Last Name: $lastname"
    echo "Preferred Name: $preferredname"
    echo "Given Name: $givenname"
    echo "Job Title: $jobtitle"
    echo "Work Phone: $workphone"
    echo "Mobile Phone: $mobilephone"
    echo "Location: $location"
    echo "Locality (City): $locality"
    echo "Region (State): $region"
    echo "Department: $department"

    # Construct JSON data
    cat <<EOF > user_data.json
{
  "primaryEmail": "$email",
  "name": {
    "givenName": "$givenname",
    "familyName": "$lastname"
  },
  "organizations": [
    {
      "customType": "work",
      "department": "$department",
      "title": "$jobtitle",
      "primary": true
    }
  ],
  "phones": [
    {
      "type": "work",
      "value": "$workphone"
    },
    {
      "type": "mobile",
      "value": "$mobilephone"
    }
  ],
  "addresses": [
    {
      "type": "work",
      "customType": "",
      "streetAddress": "",
      "locality": "$locality",
      "region": "$region",
      "postalCode": ""
    }
  ],
  "externalIds": [
    {
      "type": "organization",
      "value": "$employeeId"
    }
  ]
}
EOF

    # Update user with JSON data, including Employee ID
    echo "$gamPath update user \"$email\" json file user_data.json"
    $gamPath update user "$email" json file user_data.json
  fi
done < <(tail -n +2 users.csv)ß