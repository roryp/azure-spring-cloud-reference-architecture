#!/bin/bash
for cnt in $(seq 20000)
do
curl https://springcloudrpza-api-gateway.azuremicroservices.io/api/customer/owners
wait
done