# ZIG Async Web Server

**Requirements**

- Linux
- Zig 0.9.1

**Test Command**

```fish
# sleep for 15 seconds
curl 127.0.0.1:8080/15

# sleep for 2 seconds
curl 127.0.0.1:8080/2

# without sleep
curl 127.0.0.1:8080
```

Test async. Open 2 terminals.

```fish
# 1. hit and sleep for 15 secs
curl 127.0.0.1:8080/15

# 2. loop 100x
for i in (seq 1 100); curl 127.0.0.1:8080; end;
```