#!/bin/bash
set -e

for dir in */; do
  name=$(basename "$dir")
  echo "🚀 Deploying microservice: $name"
  helm upgrade --install "$name" "./$dir" \
    --create-namespace \
    --namespace "$name"
done
