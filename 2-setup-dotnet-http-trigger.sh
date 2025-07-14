#!/bin/bash
func init EventGridFunctionProj --worker-runtime dotnet --target-framework net8.0
cd EventGridFunctionProj
func new --name EventPublisherFunction --template "HTTP trigger"