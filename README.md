Easy to use load tests for CouchDB. Essentially a combination of `GNU parallel` and `ApacheBench`, but allows a highly customisable load test suites, almost unlimited number of concurrent operations (up to `134217727` max limit) and is also much faster than `ab`, because it uses Erlang lightweight processes. To check process limit you can run `erlang:system_info(process_limit).` in the shell. If you want to increase this limit then specify it via `+P` arg when you start the shell: `erl +P 500000`.

Instructions:

1. Put valid CouchDB admin credentials (user:pass) in the `config.ini`.
2. `./bootstrap.sh`
3. Go to `lib/ebin` and type `erl` in order to start Erlang shell
4. `load_test:start(N, Type).`  where N is a number of concurrent processes and `Type` can be one of:


`dbs`
Will start N processes which will create a DB, insert a doc there, delete a doc and then delete a db.


`docs`
Will create one db and start `N` concurrent processes which will insert, read and delete docs there;


`{reads, Distribution}`
Will create one db, and then start `N` read and write concurrent processes to insert and read docs. `Distribution` param controls a ratio between read processes (`GET` for documents) and the one which insert (`POST`) those documents and has to be between 50% and 99%. For instance `load_test:start(100, {reads, 75}).` means there will be 75% of read processes and therefore this will create 100 prosesses where 25 processes will insert documents and 75 processes will read those documents, everything will happen concurrently.
