Easy to use load tests for CouchDB. Essentially a combination of `GNU parallel` and `ApacheBench`, but allows a highly customisable load test suites, almost unlimited number of concurrent operations (up to `134217727` max limit) and is also much faster than `ab`, because it uses Erlang lightweight processes. To check process limit you can run `erlang:system_info(process_limit).` in the shell. If you want to increase this limit then specify it via `+P` arg when you start the shell: `erl +P 500000`.

Instructions:

1. Put valid CouchDB admin credentials (user:pass) in the `config.ini`.
2. `./bootstrap.sh`
3. Go to `lib/ebin` and type `erl` in order to start Erlang shell

After this you can choose amongst three test suites:

1. `load_test:dbs(N).`

Will start N concurrent processes. Each of them will create a DB, insert a doc there, delete a doc and then delete a DB.


2. `load_test:docs(N).` 

Will create a test DB and then start `N` concurrent processes. Each of them will insert, read and delete docs in this db.


3. `load_test:reads(N, Percentage, R).`

Will create one db, and then start `N` read and write concurrent processes to insert and read docs. 

`Percentage` param controls a ratio between read processes (`GET` for documents) and the one which insert (`POST`) those documents and has to be between 50% and 99%. For instance `load_test:start(100, 75).` means there will be 75% of read processes and therefore this will create 100 prosesses where 25 processes will insert documents and 75 processes will read those documents, everything will happen concurrently. 

`R` param controls the size of a read quorum. If not specified default value will be used. More on this in [CouchDB docs](http://docs.couchdb.org/en/2.2.0/cluster/sharding.html#quorum)
