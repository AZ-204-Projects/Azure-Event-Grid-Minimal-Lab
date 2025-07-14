#!/bin/bash
func init EventGridFunctionProj --worker-runtime dotnet
cd EventGridFunctionProj
func new --name EventPublisherFunction --template "HTTP trigger"