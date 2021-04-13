#!/bin/bash

# ==== Must Cusomize the below for your environment====
project_directory="/Users/rorypreddy/dev"
subscription='296f38ef-7319-4a2b-ab48-2f38cb21966e'
resource_group='springcloudrpza'
region='westeurope'
spring_cloud_service='springcloudrpza'
mysql_server_name='springcloudrpza'
mysql_server_admin_name='adminrpza'
mysql_server_admin_password='@zureIsTheDevil01'

#Add Required extensions
az extension add --name spring-cloud

#set variables
DEVBOX_IP_ADDRESS=$(curl ifconfig.me)

#Create directory for github code
cd ${project_directory}
mkdir source-code
cd source-code

#Clone GitHub Repo
git clone https://github.com/azure-samples/spring-petclinic-microservices
cd spring-petclinic-microservices
mvn clean package -DskipTests -Denv=cloud

# ==== Service and App Instances ====
api_gateway='api-gateway'
admin_server='admin-server'
customers_service='customers-service'
vets_service='vets-service'
visits_service='visits-service'

# ==== JARS ====
api_gateway_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-api-gateway/target/spring-petclinic-api-gateway-2.3.6.jar"
admin_server_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-admin-server/target/spring-petclinic-admin-server-2.3.6.jar"
customers_service_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-customers-service/target/spring-petclinic-customers-service-2.3.6.jar"
vets_service_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-vets-service/target/spring-petclinic-vets-service-2.3.6.jar"
visits_service_jar="${project_directory}/source-code/spring-petclinic-microservices/spring-petclinic-visits-service/target/spring-petclinic-visits-service-2.3.6.jar"

# ==== MYSQL INFO ====
mysql_server_full_name="${mysql_server_name}.mysql.database.azure.com"
mysql_server_admin_login_name="${mysql_server_admin_name}@${mysql_server_full_name}"
mysql_database_name='petclinic'

cd "${project_directory}/source-code/spring-petclinic-microservices"

az login
az account set --subscription ${subscription}

az group create --name ${resource_group} --location ${region}
az mysql server create \
    --resource-group ${resource_group} \
    --name ${mysql_server_name} \
    --location ${region} \
    --sku-name B_Gen5_1 \
    --storage-size 5120 \
    --admin-user ${mysql_server_admin_name} \
    --admin-password ${mysql_server_admin_password}
az mysql server firewall-rule create \
    --resource-group ${resource_group} \
    --name ${mysql_server_name}-database-allow-local-ip \
    --server ${mysql_server_name} \
    --start-ip-address ${DEVBOX_IP_ADDRESS} \
    --end-ip-address ${DEVBOX_IP_ADDRESS}
az mysql server firewall-rule create \
    --resource-group ${resource_group} \
    --name allAzureIPs \
    --server ${mysql_server_name} \
    --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az spring-cloud create \
    -g ${resource_group} \
    -n ${spring_cloud_service} \
    --sku standard \
    --enable-java-agent
az configure --defaults group=${resource_group} location=${region} spring-cloud=${spring_cloud_service}
az spring-cloud config-server set --config-file application.yml --name ${spring_cloud_service}

az spring-cloud app create --name ${api_gateway} --instance-count 1 --assign-endpoint true \
    --memory 2 --jvm-options='-Xms2048m -Xmx2048m'
az spring-cloud app create --name ${admin_server} --instance-count 1 --assign-endpoint true \
    --memory 2 --jvm-options='-Xms2048m -Xmx2048m'
az spring-cloud app create --name ${customers_service} \
    --instance-count 1 --memory 2 --jvm-options='-Xms2048m -Xmx2048m'
az spring-cloud app create --name ${vets_service} \
    --instance-count 1 --memory 2 --jvm-options='-Xms2048m -Xmx2048m'
az spring-cloud app create --name ${visits_service} \
    --instance-count 1 --memory 2 --jvm-options='-Xms2048m -Xmx2048m'

# increase connection timeout
az mysql server configuration set --name wait_timeout \
 --resource-group ${resource_group} \
 --server ${mysql_server_name} --value 2147483

#mysql Configuration 
mysql -h"${mysql_server_full_name}" -u"${mysql_server_admin_login_name}" \
     -p"${mysql_server_admin_password}" \
     -e  "CREATE DATABASE petclinic;CREATE USER 'root' IDENTIFIED BY 'petclinic';GRANT ALL PRIVILEGES ON petclinic.* TO 'root';"

mysql -h"${mysql_server_full_name}" -u"${mysql_server_admin_login_name}" \
     -p"${mysql_server_admin_password}" \
     -e  "CALL mysql.az_load_timezone();"

az mysql server configuration set --name time_zone \
  --resource-group ${resource_group} \
  --server ${mysql_server_name} --value "US/Eastern"

az spring-cloud app deploy --name ${api_gateway} \
    --jar-path ${api_gateway_jar} \
    --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql'

az spring-cloud app deploy --name ${admin_server} \
    --jar-path ${admin_server_jar} \
    --jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql'

az spring-cloud app deploy --name ${customers_service} \
--jar-path ${customers_service_jar} \
--jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' \
--env mysql_server_full_name=${mysql_server_full_name} \
      mysql_database_name=${mysql_database_name} \
      mysql_server_admin_login_name=${mysql_server_admin_login_name} \
      mysql_server_admin_password=${mysql_server_admin_password}

az spring-cloud app deploy --name ${vets_service} \
--jar-path ${vets_service_jar} \
--jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' \
--env mysql_server_full_name=${mysql_server_full_name} \
      mysql_database_name=${mysql_database_name} \
      mysql_server_admin_login_name=${mysql_server_admin_login_name} \
      mysql_server_admin_password=${mysql_server_admin_password}

az spring-cloud app deploy --name ${visits_service} \
--jar-path ${visits_service_jar} \
--jvm-options='-Xms2048m -Xmx2048m -Dspring.profiles.active=mysql' \
--env mysql_server_full_name=${mysql_server_full_name} \
      mysql_database_name=${mysql_database_name} \
      mysql_server_admin_login_name=${mysql_server_admin_login_name} \
      mysql_server_admin_password=${mysql_server_admin_password}

az spring-cloud app show --name ${api_gateway}
