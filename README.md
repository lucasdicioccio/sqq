# SQQ


A shell-command queue backed by SQLite.

## Purpose

I'm a hobbyist photographer and sometimes I need to trigger some processing on
some files.

I love tools like `xargs` and `parallel` for batching large amount of
operations. This tool is more for the case where you are wandering in a
directory and want to enqueue some job to be done and may take some times
(e.g., backuping some files) or you want to wait for some process to be done
(e.g, some git fskcing) before doing more changes.


## Build and install.

```
cabal install
```

## Some usage examples.


Initializes a queue (a SQLite DB file).

```
sqq init --queue toto.db
```

Drains and execute queues indefinitely (should have a single processor per queue).

```
sqq process --queue toto.db --action Exec
```

One command per line.

```
sqq enqueue --queue toto.db --jobs /dev/stdin
```


## For debugging.

```
sqq process --queue toto.db --action Print --commitMode DeleteFirst
```
