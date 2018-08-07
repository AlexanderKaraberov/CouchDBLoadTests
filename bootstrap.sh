#!/bin/sh

mkdir lib/ebin
erlc -o `pwd`/lib/ebin lib/load_test.erl lib/vendor/mochijson.erl
